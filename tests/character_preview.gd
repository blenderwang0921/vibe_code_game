extends SceneTree

# Real-window asset review, including a mixed equipment / shared skeleton check.
# ./tools/godot.sh --script res://tests/character_preview.gd
const IDS := ["a_astral", "b_grove", "c_lantern"]
const MODEL_ROOT := "res://assets/models/characters/"
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func wait_frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/characters/" + filename + ".png")
	check(error == OK, "Save screenshot " + filename)
	print("CAPTURE ", filename)

func skeleton_in(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := skeleton_in(child)
		if found:
			return found
	return null

func meshes_in(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(meshes_in(child))
	return result

func load_model(id: String, part: String = "character") -> Node3D:
	return load(MODEL_ROOT + id + "/" + part + ".glb").instantiate()

func validate_model(model: Node3D) -> void:
	var skeleton := skeleton_in(model)
	check(skeleton != null, "Imported skeleton exists")
	if not skeleton:
		return
	check(skeleton.get_bone_count() == 18, "All 18 animation bones imported")
	for bone in ["root", "pelvis", "chest", "head", "hand.L", "hand.R", "socket_hat", "socket_wand", "fx_tip", "hem.07"]:
		check(skeleton.find_bone(bone) >= 0, "Required bone " + bone)
	check(meshes_in(model).size() == 6, "Six independent body and equipment meshes")
	for mesh_instance in meshes_in(model):
		check(mesh_instance.skin != null, "Skinned mesh " + mesh_instance.name)
		check(mesh_instance.get_node_or_null(mesh_instance.skeleton) == skeleton, "Mesh resolves shared skeleton")

func attach_equipment(model: Node3D, id: String, slot: String) -> void:
	var target := skeleton_in(model)
	var source := load_model(id, slot)
	var source_skeleton := skeleton_in(source)
	for original in meshes_in(source):
		var part := original.duplicate() as MeshInstance3D
		part.skin = original.skin.duplicate()
		# Remap binds by bone name; never depend on glTF joint array order.
		for bind_index in part.skin.get_bind_count():
			var bone_name := part.skin.get_bind_name(bind_index)
			if bone_name.is_empty():
				bone_name = source_skeleton.get_bone_name(part.skin.get_bind_bone(bind_index))
			var target_index := target.find_bone(bone_name)
			check(target_index >= 0, "Equipment bone resolves: " + bone_name)
			part.skin.set_bind_name(bind_index, bone_name)
			part.skin.set_bind_bone(bind_index, target_index)
		target.add_child(part)
		part.skeleton = part.get_path_to(target)
	source.free()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202a39")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c5d4ec")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.25
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	stage.add_child(camera)
	camera.position = Vector3(0, 3.5, -9)
	camera.look_at(Vector3(0, 1.35, 0))
	camera.make_current()
	var models: Array[Node3D] = []
	for i in IDS.size():
		var model := load_model(IDS[i])
		stage.add_child(model)
		model.position.x = (1 - i) * 2.6
		# Blender -Y exports facing Godot +Z. Actors face -Z.
		model.rotation.y = PI
		validate_model(model)
		models.append(model)
	await wait_frames(12)
	await capture("godot_lineup")
	for model in models:
		model.visible = false
	var mixed := load_model(IDS[0], "body")
	stage.add_child(mixed)
	mixed.rotation.y = PI
	attach_equipment(mixed, IDS[1], "robe")
	attach_equipment(mixed, IDS[2], "hat")
	attach_equipment(mixed, IDS[0], "wand")
	validate_model(mixed)
	camera.size = 3.5
	camera.position = Vector3(-2.8, 2.7, -7)
	camera.look_at(Vector3(0, 1.35, 0))
	await wait_frames()
	await capture("godot_mixed_equipment")
	# Pose smoke test only: no animation clips are authored or saved.
	var skeleton := skeleton_in(mixed)
	for pose in [["hand.R", Vector3.FORWARD, 0.3], ["head", Vector3.UP, 0.25], ["hem.00", Vector3.RIGHT, 0.15]]:
		var bone_index := skeleton.find_bone(pose[0])
		var rest_rotation := skeleton.get_bone_pose_rotation(bone_index)
		skeleton.set_bone_pose_rotation(bone_index, rest_rotation * Quaternion(pose[1], pose[2]))
	await wait_frames()
	await capture("godot_rig_pose_check")
	root.remove_child(stage)
	stage.free()

	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	while not world.navigation_ready:
		await process_frame
	world.player.get_node("Visual").hide()
	world.player.get_node("Visual").set_process(false)
	world.player.rotation.y = 0
	world.player.position = Vector3(3, 0.05, 14)
	for id in IDS:
		var model := load_model(id)
		world.player.add_child(model)
		model.rotation.y = PI
		world.camera_focus = world.player.global_position
		world._update_camera(1.0)
		await wait_frames(8)
		await capture("gameplay_" + id)
		# The same scene's lighting at close range, facing the character.
		world.set_process(false)
		world.hud.hide()
		world.camera.size = 3.8
		world.camera.position = world.player.global_position + Vector3(-3, 2.5, -7)
		world.camera.look_at(world.player.global_position + Vector3(0, 1.35, 0))
		await wait_frames()
		await capture("game_closeup_" + id)
		world.hud.show()
		world.camera.size = 26.0
		world.set_process(true)
		model.free()
	print("CHARACTER PREVIEW: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
