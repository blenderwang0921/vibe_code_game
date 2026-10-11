"""Run with ./tools/blender.sh --background --python-exit-code 1 --python tests/blender_smoke.py."""
import pathlib
import struct

import bpy


output = pathlib.Path(__file__).resolve().parent.parent / "artifacts" / "blender-smoke"
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=False)
cube = bpy.data.objects["Cube"]
cube.name = "BlenderSmokeCube"
cube.rotation_euler.z = 0.3
material = bpy.data.materials.new("SmokeTeal")
material.diffuse_color = (0.05, 0.55, 0.4, 1.0)
cube.data.materials.clear()
cube.data.materials.append(material)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(output / "preview.png")
bpy.ops.wm.save_as_mainfile(filepath=str(output / "model.blend"))
bpy.ops.export_scene.gltf(filepath=str(output / "model.glb"), export_format="GLB")
bpy.ops.render.render(write_still=True)

glb = (output / "model.glb").read_bytes()
magic, version, length = struct.unpack("<4sII", glb[:12])
assert (magic, version, length) == (b"glTF", 2, len(glb)), "Invalid GLB output"
png = (output / "preview.png").read_bytes()
assert png[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG output"
assert struct.unpack(">II", png[16:24]) == (256, 256), "Incorrect render dimensions"
assert (output / "model.blend").stat().st_size > 0, "Missing Blender project"
print(f"BLENDER SMOKE PASS: saved .blend, exported GLB, rendered 256x256 PNG to {output}")
