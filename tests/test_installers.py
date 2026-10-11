"""Offline installer regression checks: python3 -m unittest discover -s tests -p 'test_installers.py'."""
import hashlib
import io
import json
import pathlib
import sys
import tarfile
import tempfile
import unittest
import zipfile
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tools"))
import install_blender as blender
import install_godot as godot


class Response(io.BytesIO):
    def __init__(self, data):
        super().__init__(data)
        self.headers = {"Content-Length": str(len(data))}


class InstallerTests(unittest.TestCase):
    def test_linux_godot_install_and_cleanup(self):
        name = f"Godot_v{godot.VERSION}_linux.x86_64.zip"
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr(name[:-4], b"fake engine")
        data = buffer.getvalue()
        release = {"assets": [{"name": name, "size": len(data), "digest": "sha256:" + hashlib.sha256(data).hexdigest(), "browser_download_url": "https://example.invalid/godot.zip"}]}
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            with patch.object(godot, "TOOLS", root), patch.object(godot.sys, "platform", "linux"), patch.object(godot.platform, "machine", return_value="x86_64"), patch.object(godot, "fetch", side_effect=[Response(json.dumps(release).encode()), Response(data)]), patch.object(godot.subprocess, "run") as run:
                godot.main()
            self.assertEqual((root / "godot").read_bytes(), b"fake engine")
            self.assertTrue((root / "godot").stat().st_mode & 0o111)
            self.assertFalse((root / "Godot.download.zip").exists())
            self.assertFalse((root / "godot.installing").exists())
            self.assertEqual(json.loads((root / "release.json").read_text())["asset"], name)
            self.assertIn("--headless", run.call_args_list[0].args[0])

    def test_platform_selection(self):
        for system, machine, suffix in [("darwin", "arm64", "macos-arm64.dmg"), ("darwin", "x86_64", "macos-x64.dmg"), ("linux", "x86_64", "linux-x64.tar.xz")]:
            with self.subTest(system=system, machine=machine), patch.object(blender.sys, "platform", system), patch.object(blender.platform, "machine", return_value=machine):
                self.assertTrue(blender.platform_asset()[0].endswith(suffix))
        with patch.object(blender.sys, "platform", "linux"), patch.object(blender.platform, "machine", return_value="aarch64"):
            with self.assertRaises(SystemExit):
                blender.platform_asset()
            with self.assertRaises(SystemExit):
                godot.platform_asset()

    def test_checksum_and_corrupt_download(self):
        data = b"archive"
        digest = hashlib.sha256(data).hexdigest()
        self.assertEqual(blender.checksum_for(f"{digest} *file.tar.xz\n", "file.tar.xz"), digest)
        with self.assertRaises(RuntimeError):
            blender.checksum_for(f"{digest} other.tar.xz", "file.tar.xz")
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / "download"
            with patch.object(blender, "fetch", return_value=Response(data)):
                self.assertEqual(blender.download("unused", target, digest), len(data))
            with patch.object(blender, "fetch", return_value=Response(b"corrupt")):
                with self.assertRaises(RuntimeError):
                    blender.download("unused", target, digest)
            with patch.object(blender, "fetch", return_value=Response(data)), patch.object(blender, "MAX_DOWNLOAD", 2):
                with self.assertRaises(RuntimeError):
                    blender.download("unused", target, digest)

    def test_tar_extraction_and_path_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            archive = root / "test.tar.xz"
            with tarfile.open(archive, "w:xz") as target:
                member = tarfile.TarInfo(f"blender-{blender.VERSION}-linux-x64/blender")
                member.size = 3
                member.mode = 0o755
                target.addfile(member, io.BytesIO(b"bin"))
            installed = blender.extract_linux(archive, root / "valid")
            self.assertEqual((installed / "blender").read_bytes(), b"bin")
            self.assertTrue((installed / "blender").stat().st_mode & 0o111)
            with tarfile.open(archive, "w:xz") as target:
                member = tarfile.TarInfo("../../escaped")
                target.addfile(member)
            with self.assertRaises(tarfile.FilterError):
                blender.extract_linux(archive, root / "unsafe")
            self.assertFalse((root.parent / "escaped").exists())


if __name__ == "__main__":
    unittest.main()
