"""Rebuild the three rigged wizard proposals using Blender 4.5+.

./tools/blender.sh --background --python-exit-code 1 --python tools/build_character_concepts.py
No external textures, addons, or generated animation clips are required.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/characters"
EXPORT = ROOT / "assets/models/characters"
PROPOSALS = [
    dict(id="a_astral", title="A / ASTRAL SCHOLAR", subtitle="Indigo cloth / brass orbits / suspended star",
         cloth="393958", light="535779", dark="252a43", trim="c5a36a", gem="8adfdc", skin="f0ddba"),
    dict(id="b_grove", title="B / GROVE WANDERER", subtitle="Jade cloth / warm timber / living seed",
         cloth="275b50", light="42766a", dark="193e39", trim="c6ad77", gem="c8ec8c", skin="eee0c4"),
    dict(id="c_lantern", title="C / TWILIGHT KEEPER", subtitle="Ivory cloth / dark plum / cut-crystal lantern",
         cloth="ded5bd", light="f1e6cd", dark="514358", trim="ad8355", gem="d7a1e8", skin="efe2cb"),
]


def material(name, color, metallic=0.0, emission=0.0):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    rgb = [v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*rgb, 1)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = .36 if metallic else .78
    node.inputs["Emission Color"].default_value = (*rgb, 1)
    node.inputs["Emission Strength"].default_value = emission
    return mat


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def rings(name, rows, mat, segments=12, cap=True, phase=0):
    # Rows are (center_x, center_y, z, radius_x, radius_y).
    verts = [(x + rx * math.cos(phase + j * math.tau / segments),
              y + ry * math.sin(phase + j * math.tau / segments), z)
             for x, y, z, rx, ry in rows for j in range(segments)]
    faces = []
    for i in range(len(rows) - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    if cap:
        faces += [tuple(reversed(range(segments))), tuple((len(rows) - 1) * segments + j for j in range(segments))]
    return mesh(name, verts, faces, mat)


def orb(name, pos, radius, mat, subdivisions=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def tube(name, points, radii, mat, sides=6):
    verts, faces = [], []
    for i, point in enumerate(points):
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(0, i - 1)])
        tangent.normalize()
        axis = Vector((0, 1, 0))
        if abs(tangent.dot(axis)) > .95:
            axis = Vector((1, 0, 0))
        u = tangent.cross(axis).normalized()
        v = tangent.cross(u).normalized()
        for j in range(sides):
            angle = math.tau * j / sides
            verts.append(Vector(point) + radii[i] * (u * math.cos(angle) + v * math.sin(angle)))
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces += [tuple(reversed(range(sides))), tuple((len(points) - 1) * sides + j for j in range(sides))]
    return mesh(name, verts, faces, mat)


def crystal(name, center, radius, height, mat):
    x, y, z = center
    return rings(name, [(x, y, z - height / 2, .005, .005),
                        (x, y, z - height * .13, radius, radius),
                        (x, y, z + height * .18, radius * .85, radius * .85),
                        (x, y, z + height / 2, .002, .002)], mat, 6)


def make_rig(collection):
    data = bpy.data.armatures.new("WizardSkeleton_v1")
    rig = bpy.data.objects.new("WizardRig", data)
    collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    definitions = [
        ("root", (0, 0, 0), (0, 0, .2), None),
        ("pelvis", (0, 0, .65), (0, 0, .9), "root"),
        ("spine", (0, 0, .9), (0, 0, 1.13), "pelvis"),
        ("chest", (0, 0, 1.13), (0, 0, 1.36), "spine"),
        ("head", (0, 0, 1.4), (0, 0, 1.75), "chest"),
        ("hand.L", (-.59, -.08, 1.04), (-.59, -.08, 1.19), "chest"),
        ("hand.R", (.69, -.13, 1.04), (.69, -.13, 1.19), "chest"),
        ("socket_hat", (0, 0, 1.79), (0, 0, 1.94), "head"),
        ("socket_wand", (.76, -.10, 1.04), (.76, -.10, 1.24), "hand.R"),
        ("fx_tip", (.76, -.10, 2.22), (.76, -.10, 2.35), "socket_wand"),
    ]
    for i in range(8):
        a = math.tau * i / 8
        definitions.append((f"hem.{i:02d}", (.24 * math.cos(a), .20 * math.sin(a), .66),
                            (.49 * math.cos(a), .40 * math.sin(a), .13), "pelvis"))
    for name, head, tail, parent in definitions:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    data.display_type = "OCTAHEDRAL"
    rig["schema"] = "wizard_rig_v1"
    rig["forward"] = "Blender -Y; apply rotation Y=180 degrees in Godot"
    return rig


def bind(obj, rig, bone=None, cloth=False):
    obj.parent = rig
    modifier = obj.modifiers.new("Wizard deformation", "ARMATURE")
    modifier.object = rig
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for vertex in obj.data.vertices:
        if cloth:
            z = vertex.co.z
            if z < .68:
                influence = max(0, min(1, (.68 - z) / .55))
                angle = (math.atan2(vertex.co.y / .40, vertex.co.x / .49) % math.tau) * 8 / math.tau
                index = int(angle)
                blend = angle - index
                weights = {"pelvis": 1 - influence, f"hem.{index:02d}": influence * (1 - blend),
                           f"hem.{(index + 1) % 8:02d}": influence * blend}
            elif z < .96:
                blend = min(1, (z - .68) / .28)
                weights = {"pelvis": 1 - blend, "spine": blend}
            else:
                blend = min(1, (z - .96) / .26)
                weights = {"spine": 1 - blend, "chest": blend}
        else:
            weights = {bone: 1.0}
        for name, weight in weights.items():
            if weight > 0:
                groups[name].add([vertex.index], weight, "REPLACE")


def join_parts(parts, name, collection, rig, bone=None, cloth=False):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = parts[0]
    obj.name = name
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    bind(obj, rig, bone, cloth)
    obj["equipment_slot"] = name
    return obj


def build(p, index):
    collection = bpy.data.collections.new(p["id"])
    bpy.context.scene.collection.children.link(collection)
    m = {k: material(p["id"] + "/" + k, p[k], .65 if k == "trim" else 0, .25 if k == "gem" else 0)
         for k in ("cloth", "light", "dark", "trim", "gem", "skin")}
    wood = material(p["id"] + "/wand_shaft", ["333548", "694534", "392b40"][index])
    rig = make_rig(collection)
    body = [orb("FacelessHead", (0, -.035, 1.57), .275, m["skin"])]
    join_parts(body, "Body_Head", collection, rig, "head")
    for side, pos in [("L", (-.59, -.08, 1.04)), ("R", (.69, -.13, 1.04))]:
        join_parts([orb("FloatingHand", pos, .115, m["skin"])], "Body_Hand_" + side, collection, rig, "hand." + side)

    width = [.56, .63, .50][index]
    rows = [(0, 0, .10, width, width * .78), (0, 0, .16, width * 1.01, width * .79),
            (0, 0, .37, width * .82, width * .68), (0, 0, .66, .34, .29),
            (0, 0, .88, .265, .235), (0, 0, 1.10, .29, .25),
            (0, 0, 1.29, .335, .26), (0, 0, 1.37, .19, .18)]
    robe = rings("RobeShell", rows, m["cloth"], 16, False, math.pi / 16)
    robe.data.materials.append(m["light"])
    robe.data.materials.append(m["dark"])
    # Broad restrained panels, no noisy decoration or texture dependencies.
    for poly in robe.data.polygons:
        column = poly.index % 16
        poly.material_index = 1 if column in (10, 11) else (2 if column in (3, 4) else 0)
    lining = rings("HemFacing", [(0, 0, .10, width, width * .78), (0, 0, .135, width, width * .78),
                                 (0, 0, .135, width - .035, width * .78 - .035),
                                 (0, 0, .10, width - .035, width * .78 - .035)], m["dark"], 16, False, math.pi / 16)
    collar = rings("SimpleCollar", [(0, 0, 1.285, .338, .265), (0, 0, 1.32, .32, .25),
                                    (0, 0, 1.385, .195, .185)], m["dark"], 16, False, math.pi / 16)
    belt = rings("NarrowSash", [(0, 0, .87, .274, .244), (0, 0, .915, .275, .244)], m["trim"], 16, False, math.pi / 16)
    join_parts([robe, lining, collar, belt], "Equip_Robe", collection, rig, cloth=True)

    brim_width = [.73, .79, .64][index]
    brim = rings("WideBrim", [(0, 0, 1.80, .32, .31), (0, 0, 1.765, brim_width, brim_width * .75),
                              (0, 0, 1.81, brim_width, brim_width * .75), (0, 0, 1.845, .34, .32)], m["cloth"], 16)
    crown_rows = [
        [(0, 0, 1.82, .34, .31), (0, 0, 1.98, .29, .27), (.015, .02, 2.22, .21, .19),
         (.08, .02, 2.46, .12, .10), (.22, .01, 2.53, .065, .055), (.34, 0, 2.45, .008, .008)],
        [(0, 0, 1.82, .35, .31), (-.035, 0, 2.02, .27, .25), (-.14, .03, 2.25, .16, .14),
         (-.27, .03, 2.40, .085, .075), (-.42, .02, 2.37, .04, .04), (-.45, 0, 2.28, .005, .005)],
        [(0, 0, 1.82, .32, .30), (0, .01, 2.02, .25, .24), (-.01, .035, 2.27, .16, .15),
         (-.04, .055, 2.53, .06, .055), (-.10, .06, 2.68, .004, .004)],
    ][index]
    crown = rings("HatCrown", crown_rows, m["cloth"], 12)
    def crown_slice(z, offset):
        start, end = crown_rows[:2]
        t = (z - start[2]) / (end[2] - start[2])
        row = [a + (b - a) * t for a, b in zip(start, end)]
        row[3] += offset
        row[4] += offset
        return row
    band = rings("HatBand", [crown_slice(1.84, .006), crown_slice(1.94, .006)], m["dark"], 12, False)
    seam = rings("HatBandEdge", [crown_slice(1.935, .009), crown_slice(1.95, .009)], m["trim"], 12, False)
    join_parts([brim, crown, band, seam], "Equip_Hat", collection, rig, "socket_hat")

    x, y = .76, -.10
    wand = [tube("Shaft", [(x, y, .18), (x, y, 1.55), (x, y, 1.94)], [.023, .032, .045], wood, 8)]
    for z, radius, length in [(.21, .035, .13), (.99, .039, .10), (1.12, .039, .025), (1.88, .064, .10)]:
        wand.append(rings("Ferrule", [(x, y, z - length / 2, radius, radius), (x, y, z + length / 2, radius, radius)], m["trim"], 8))
    if index == 0:
        # Two open, offset orbital crescents leave the crystal silhouette legible.
        for radius, start, end, depth in [(.29, -65, 230, 0), (.215, 110, 395, .06)]:
            angles = [math.radians(start + (end - start) * i / 20) for i in range(21)]
            points = [(x + radius * math.cos(a), y + depth + .055 * math.cos(a), 2.20 + radius * math.sin(a)) for a in angles]
            wand.append(tube("OpenOrbit", points, [.013 + .010 * math.sin(math.pi * i / 20) for i in range(21)], m["trim"]))
        wand.append(crystal("SuspendedStar", (x, y, 2.20), .092, .34, m["gem"]))
        wand.append(crystal("OrbitFinial", (x + .15, y, 2.49), .033, .12, m["trim"]))
    elif index == 1:
        for sign in [-1, 1]:
            points = [(x, y, 1.88), (x + sign * .17, y, 2.04), (x + sign * .23, y, 2.22),
                      (x + sign * .17, y, 2.40), (x + sign * .055, y, 2.52)]
            wand.append(tube("CarvedBough", points, [.05, .045, .036, .025, .003], wood, 6))
            vein = [(px, py - .025, pz) for px, py, pz in points]
            wand.append(tube("BoughInlay", vein, [.008, .010, .009, .007, .002], m["trim"], 5))
        wand.append(crystal("LivingSeed", (x, y, 2.24), .115, .32, m["gem"]))
        wand.append(crystal("SeedCrown", (x, y, 2.50), .035, .10, m["trim"]))
    else:
        for sign in [-1, 1]:
            points = [(x, y, 1.91), (x + sign * .22, y, 2.14), (x + sign * .22, y, 2.35), (x, y, 2.57)]
            wand.append(tube("LanternFrame", points, [.025, .027, .024, .012], m["trim"], 4))
        wand.append(crystal("TwilightPrism", (x, y, 2.25), .105, .39, m["gem"]))
        wand.append(crystal("LanternCrown", (x, y, 2.60), .05, .16, m["trim"]))
        wand.append(tube("Pendant", [(x + .22, y, 2.14), (x + .23, y, 1.99)], [.012, .009], m["trim"], 5))
        wand.append(crystal("PendantGem", (x + .23, y, 1.95), .035, .12, m["gem"]))
    join_parts(wand, "Equip_Wand", collection, rig, "socket_wand")
    return collection, rig


def validate(rig):
    objects = [o for o in rig.children if o.type == "MESH"]
    assert len(objects) == 6
    assert len(rig.data.bones) == 18
    for obj in objects:
        for v in obj.data.vertices:
            assert 1 <= len(v.groups) <= 4, (obj.name, v.index)
            assert abs(sum(g.weight for g in v.groups) - 1) < 1e-5
        assert all(p.area > 1e-10 for p in obj.data.polygons), obj.name
    # Verify real evaluated deformation, then restore rest pose (no Actions created).
    hand = next(o for o in objects if o.name.startswith("Body_Hand_R"))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    before = hand.evaluated_get(depsgraph).to_mesh()
    before_pos = before.vertices[0].co.copy()
    hand.evaluated_get(depsgraph).to_mesh_clear()
    rig.pose.bones["hand.R"].location.x = .15
    bpy.context.view_layer.update()
    evaluated = hand.evaluated_get(depsgraph)
    after = evaluated.to_mesh()
    assert (after.vertices[0].co - before_pos).length > .14
    evaluated.to_mesh_clear()
    rig.pose.bones["hand.R"].location = (0, 0, 0)
    bpy.context.view_layer.update()
    return {"bones": len(rig.data.bones), "meshes": {o.name: {"vertices": len(o.data.vertices),
            "triangles": sum(len(p.vertices) - 2 for p in o.data.polygons)} for o in objects},
            "weights_normalized": True, "hand_deformation_verified": True, "animation_clips": 0}


def export(rig, path, meshes=None):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in rig.children:
        obj.select_set(meshes is None or obj.name in meshes)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                             export_animations=False, export_skins=True, export_all_influences=False,
                             export_extras=True, export_yup=True)


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.world = bpy.data.worlds.new("StudioWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.15, .18, .24, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .45
    scene.view_settings.view_transform = "AgX"
    floor = material("StudioFloor", "242d3b")
    bpy.ops.mesh.primitive_plane_add(size=200)
    bpy.context.object.name = "STUDIO_Floor"
    bpy.context.object.data.materials.append(floor)
    for name, pos, power, size, color in [
        ("Key", (-3, -4, 7), 800, 5, (1, .88, .74)),
        ("Fill", (4, -2, 5), 650, 4, (.7, .83, 1)),
        ("Rim", (1, 4, 6), 1000, 3, (.8, .88, 1)),
    ]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size, data.color = power, "DISK", size, color
        obj = bpy.data.objects.new("STUDIO_" + name, data)
        scene.collection.objects.link(obj)
        obj.location = pos
        point_at(obj, (0, 0, 1.3))
    data = bpy.data.cameras.new("PortraitCamera")
    camera = bpy.data.objects.new("STUDIO_Camera", data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.location = (3.0, -8, 3.3)
    camera.data.ortho_scale = 3.45
    point_at(camera, (.14, 0, 1.37))
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_percentage = 100
    return scene, camera


def label(camera, text, x, y, size, mat):
    data = bpy.data.curves.new("Label", "FONT")
    data.body, data.size, data.align_x = text, size, "CENTER"
    obj = bpy.data.objects.new("STUDIO_Label", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.rotation_euler = camera.rotation_euler
    obj.location = camera.matrix_world @ Vector((x, y, -9))
    data.materials.append(mat)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    EXPORT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene, camera = studio()
    report = {}
    # Keep each individual source clean, with only its own asset and studio.
    for index, proposal in enumerate(PROPOSALS):
        collection, rig = build(proposal, index)
        report[proposal["id"]] = validate(rig)
        directory = EXPORT / proposal["id"]
        directory.mkdir(exist_ok=True)
        export(rig, directory / "character.glb")
        for part in ("Robe", "Hat", "Wand"):
            export(rig, directory / (part.lower() + ".glb"), {"Equip_" + part})
        export(rig, directory / "body.glb", {"Body_Head", "Body_Hand_L", "Body_Hand_R"})
        scene.render.resolution_x, scene.render.resolution_y = 1000, 1100
        scene.render.filepath = str(OUT / (proposal["id"] + ".png"))
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (proposal["id"] + ".blend")))
        bpy.ops.render.render(write_still=True)
        for obj in list(collection.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(collection)
    # Separate presentation scene; export transforms always remain at identity.
    rigs = []
    for index, proposal in enumerate(PROPOSALS):
        _, rig = build(proposal, index)
        rig.location.x = (index - 1) * 2.65
        rig.rotation_euler.z = math.radians(-12)
        rigs.append(rig)
    camera.location = (.1, -12, 4.6)
    point_at(camera, (.1, 0, 1.35))
    camera.data.ortho_scale = 8.8
    bpy.context.view_layer.update()
    white = material("TypeIvory", "eee7da", emission=1)
    gray = material("TypeMuted", "adbcc9", emission=1)
    label(camera, "THE WAND-BEARERS", 0, 1.72, .23, white)
    label(camera, "THREE LOW-POLY CHARACTER DIRECTIONS  /  SHARED MODULAR RIG", 0, 1.44, .072, gray)
    for i, p in enumerate(PROPOSALS):
        label(camera, p["title"], (i - 1) * 2.65, -1.46, .12, white)
        label(camera, p["subtitle"], (i - 1) * 2.65, -1.64, .061, gray)
    scene.render.resolution_x, scene.render.resolution_y = 2200, 1100
    scene.render.filepath = str(OUT / "comparison.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "comparison.blend"))
    bpy.ops.render.render(write_still=True)
    (OUT / "validation.json").write_text(json.dumps(report, indent=2))
    print("CHARACTER BUILD PASS: three rigged sources, modular GLBs, portraits and comparison")


if __name__ == "__main__":
    main()
