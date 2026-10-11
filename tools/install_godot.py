#!/usr/bin/env python3
"""Download pinned standard Godot for macOS or Linux x86_64."""
import hashlib
import json
import pathlib
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / ".tools"
EXECUTABLE = TOOLS / "Godot.app/Contents/MacOS/Godot"


def platform_asset():
    if sys.platform == "darwin":
        return f"Godot_v{VERSION}_macos.universal.zip", EXECUTABLE
    if sys.platform == "linux" and platform.machine().lower() in ("x86_64", "amd64"):
        return f"Godot_v{VERSION}_linux.x86_64.zip", TOOLS / "godot"
    raise SystemExit("自動安裝支援 macOS 和 Linux x86_64；其他平台請設定 GODOT_BIN。")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "TwilightGrove-setup"})
    return urllib.request.urlopen(request, timeout=60)


def main():
    name, executable = platform_asset()
    if executable.exists():
        subprocess.run([str(executable), "--version"], check=True)
        print("現有引擎：", executable)
        return
    with fetch(f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}") as response:
        release = json.load(response)
    asset = next(a for a in release["assets"] if a["name"] == name)
    size = asset["size"]
    if size > 220 * 1024 * 1024:
        raise SystemExit("壓縮包超過預期 220 MiB，停止下載。")
    print(f"官方 Godot {VERSION} 標準版，下載大小 {size:,} bytes ({size / 2**20:.1f} MiB)。", flush=True)
    TOOLS.mkdir(exist_ok=True)
    (TOOLS / ".gdignore").touch()
    archive = TOOLS / "Godot.download.zip"
    try:
        digest = hashlib.sha256()
        total = 0
        with fetch(asset["browser_download_url"]) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > size:
                    raise RuntimeError("下載大小超出官方 metadata。")
                digest.update(chunk)
                output.write(chunk)
        if total != size:
            raise RuntimeError("下載不完整。")
        expected = asset.get("digest", "")
        if not expected.startswith("sha256:") or expected[7:] != digest.hexdigest():
            raise RuntimeError("SHA256 校驗失敗或官方未提供 digest。")
        with zipfile.ZipFile(archive) as zipped:
            unpacked = sum(info.file_size for info in zipped.infolist())
            if unpacked + size > 900 * 1024 * 1024:
                raise RuntimeError("解壓所需空間超過初期容量預算。")
            for info in zipped.infolist():
                destination = (TOOLS / info.filename).resolve()
                if not destination.is_relative_to(TOOLS.resolve()):
                    raise RuntimeError("ZIP 包含不安全路徑。")
        print(f"SHA256 正確。引擎解壓大小約 {unpacked / 2**20:.1f} MiB。", flush=True)
        if shutil.disk_usage(TOOLS).free < unpacked + 64 * 1024 * 1024:
            raise RuntimeError("解壓空間不足。")
        if sys.platform == "darwin":
            subprocess.run(["ditto", "-x", "-k", str(archive), str(TOOLS)], check=True)
        else:
            # Only install the expected executable, rather than arbitrary ZIP entries.
            temporary = TOOLS / "godot.installing"
            try:
                with zipfile.ZipFile(archive) as zipped, zipped.open(name[:-4]) as source, temporary.open("wb") as target:
                    shutil.copyfileobj(source, target)
                temporary.chmod(0o755)
                subprocess.run([str(temporary), "--headless", "--version"], check=True)
                temporary.replace(executable)
            finally:
                temporary.unlink(missing_ok=True)
        (TOOLS / "release.json").write_text(json.dumps({"version": VERSION, "asset": name, "bytes": size, "sha256": digest.hexdigest()}, indent=2))
        subprocess.run([str(executable), "--version"], check=True)
    finally:
        archive.unlink(missing_ok=True)
    print("完成。執行 ./run.sh 開始遊戲。")


if __name__ == "__main__":
    main()

