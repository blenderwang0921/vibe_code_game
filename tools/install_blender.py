#!/usr/bin/env python3
"""Install pinned Blender locally; no system installation or third-party packages."""
import hashlib
import json
import pathlib
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

VERSION = "4.5.3"  # Pin an LTS release so asset generation is reproducible.
BASE_URL = "https://download.blender.org/release/Blender4.5"
TOOLS = pathlib.Path(__file__).resolve().parent.parent / ".tools"
MAX_DOWNLOAD = 600 * 1024**2
MAX_UNPACKED = 3 * 1024**3


def platform_asset():
    machine = platform.machine().lower()
    if sys.platform == "darwin" and machine in ("arm64", "aarch64", "x86_64", "amd64"):
        arch = "arm64" if machine in ("arm64", "aarch64") else "x64"
        return f"blender-{VERSION}-macos-{arch}.dmg", pathlib.Path("Blender.app/Contents/MacOS/Blender")
    if sys.platform == "linux" and machine in ("x86_64", "amd64"):
        return f"blender-{VERSION}-linux-x64.tar.xz", pathlib.Path("blender")
    raise SystemExit("自動安裝支援 macOS Apple Silicon／Intel 和 Linux x86_64；其他平台請設定 BLENDER_BIN。")


def fetch(url):
    # The official CDN rejects Python's default User-Agent (HTTP 403 / 1010).
    request = urllib.request.Request(url, headers={"User-Agent": "TwilightGrove-setup"})
    return urllib.request.urlopen(request, timeout=60)


def checksum_for(contents, name):
    for line in contents.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lstrip("*") == name and re.fullmatch(r"[0-9a-fA-F]{64}", parts[0]):
            return parts[0].lower()
    raise RuntimeError(f"官方 checksum 清單缺少有效的 {name} SHA256。")


def download(url, target, expected):
    digest = hashlib.sha256()
    total = 0
    with fetch(url) as response, target.open("wb") as output:
        size = int(response.headers.get("Content-Length", "0"))
        if size > MAX_DOWNLOAD:
            raise RuntimeError("下載超過 600 MiB 容量上限。")
        print(f"下載 {target.name}（上限 600 MiB）", flush=True)
        while chunk := response.read(1024**2):
            total += len(chunk)
            if total > MAX_DOWNLOAD:
                raise RuntimeError("下載超過 600 MiB 容量上限。")
            digest.update(chunk)
            output.write(chunk)
    if (size and size != total) or digest.hexdigest() != expected:
        raise RuntimeError("下載不完整或 SHA256 校驗失敗。")
    print(f"SHA256 正確，下載 {total / 1024**2:.1f} MiB。", flush=True)
    return total


def extract_linux(archive, destination):
    # The data filter rejects escaping paths, unsafe symlinks and special files.
    if not hasattr(tarfile, "data_filter"):
        raise RuntimeError("安全解壓需要支援 tarfile.data_filter 的 Python；請使用 Python 3.12+。")
    with tarfile.open(archive, "r:xz") as source:
        if sum(member.size for member in source.getmembers()) > MAX_UNPACKED:
            raise RuntimeError("Blender 解壓大小超過 3 GiB 上限。")
        source.extractall(destination, filter="data")
    return destination / f"blender-{VERSION}-linux-x64"


def extract_macos(archive, working):
    mount = working / "mount"
    mount.mkdir()
    subprocess.run(["hdiutil", "attach", str(archive), "-readonly", "-nobrowse", "-mountpoint", str(mount)], check=True)
    staged = working / "installed"
    try:
        app = mount / "Blender.app"
        size = sum(p.lstat().st_size for p in app.rglob("*") if p.is_file())
        if size > MAX_UNPACKED:
            raise RuntimeError("Blender 解壓大小超過 3 GiB 上限。")
        staged.mkdir()
        subprocess.run(["ditto", str(app), str(staged / "Blender.app")], check=True)
    finally:
        subprocess.run(["hdiutil", "detach", str(mount)], check=True)
    return staged


def main():
    name, relative_executable = platform_asset()
    installed = TOOLS / "blender"
    executable = installed / relative_executable
    if executable.exists():
        subprocess.run([str(executable), "--background", "--version"], check=True)
        print("現有 Blender：", executable)
        return
    if installed.exists():
        raise SystemExit(".tools/blender 已存在但缺少執行檔；請先檢查或移開該目錄再重試。")
    if sys.platform == "linux" and not hasattr(tarfile, "data_filter"):
        raise SystemExit("安全解壓需要支援 tarfile.data_filter 的 Python；請使用 Python 3.12+。")
    TOOLS.mkdir(exist_ok=True)
    (TOOLS / ".gdignore").touch()
    if shutil.disk_usage(TOOLS).free < MAX_DOWNLOAD + MAX_UNPACKED:
        raise SystemExit("請至少保留 3.6 GiB 可用空間供 Blender 下載與安裝。")
    with fetch(f"{BASE_URL}/blender-{VERSION}.sha256") as response:
        checksum = checksum_for(response.read().decode("utf-8"), name)
    # Staging on the same filesystem avoids exposing a partial installation.
    with tempfile.TemporaryDirectory(prefix="blender-install-", dir=TOOLS) as directory:
        working = pathlib.Path(directory)
        archive = working / name
        total = download(f"{BASE_URL}/{name}", archive, checksum)
        staged = extract_macos(archive, working) if sys.platform == "darwin" else extract_linux(archive, working / "unpacked")
        subprocess.run([str(staged / relative_executable), "--background", "--version"], check=True)
        (staged / "release.json").write_text(json.dumps({"version": VERSION, "asset": name, "bytes": total, "sha256": checksum}, indent=2))
        staged.rename(installed)
    print("完成。執行 ./tools/blender.sh --background --version 驗證安裝。")


if __name__ == "__main__":
    main()
