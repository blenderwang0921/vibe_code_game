extends SceneTree

# A rendered input-driven playthrough using normal health, damage and cooldowns.
# It presses E/Q/W/2 and right-clicks ground, without teleporting or killing actors.
var world
var last_move: float = -100
var healing: bool = false
var shots: int = 0
var frost_casts: int = 0
var clicks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func press(code: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = code
	Input.parse_input_event(up)
	Input.flush_buffered_events()

func aim(point: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = world.camera.unproject_position(Vector3(point.x, 0, point.z))
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func move(point: Vector3) -> void:
	if world.elapsed - last_move < 0.6:
		return
	aim(point)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.position = world.camera.unproject_position(point)
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.position = down.position
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	last_move = world.elapsed
	clicks += 1

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename)

func _run() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	while not world.navigation_ready:
		await process_frame
	await create_timer(1.0).timeout
	press(KEY_E)
	if world.state.quest != RunState.Quest.ACTIVE:
		push_error("PLAYTHROUGH: E input did not accept quest")
		quit(1)
		return
	print("PLAYTHROUGH: quest accepted via E")
	var last_kills: int = 0
	var captured_combat: bool = false
	while world.elapsed < 240:
		await create_timer(0.15).timeout
		if world.player.health.dead:
			await capture("playthrough-death.png")
			push_error("PLAYTHROUGH: automated controller died at %d kills" % world.state.kills)
			quit(1)
			return
		if world.state.quest == RunState.Quest.READY:
			if world.player.global_position.distance_to(world.elder.global_position) <= 3.2:
				press(KEY_E)
				await capture("reward.png")
				press(KEY_2)
				if world.state.quest != RunState.Quest.REWARDED:
					push_error("PLAYTHROUGH: reward input failed")
					quit(1)
					return
				print("PLAYTHROUGH: returned to elder and chose frost upgrade at %.1fs" % world.elapsed)
				await _continue_after_reward()
				return
			_approach(world.elder.global_position)
			continue
		if world.state.kills != last_kills:
			last_kills = world.state.kills
			print("PLAYTHROUGH: kills=%d health=%.1f t=%.1f" % [last_kills, world.player.health.current, world.elapsed])
		if world.player.health.current < 38:
			healing = true
		if healing:
			if world.player.health.current >= 94:
				healing = false
			else:
				_approach(Vector3(0, 0, 7))
				continue
		var enemies := get_nodes_in_group("enemies")
		if enemies.is_empty():
			continue
		enemies.sort_custom(func(a, b): return a.global_position.distance_squared_to(world.player.global_position) < b.global_position.distance_squared_to(world.player.global_position))
		var enemy: ForestEnemy = enemies[0]
		var distance: float = world.player.global_position.distance_to(enemy.global_position)
		if world.is_safe(world.player.global_position) or distance > 8.0:
			_approach(enemy.global_position)
		else:
			_kite(enemies)
		if distance < world.balance.fire_range - 0.5 and world.player.spells.fire_left <= 0:
			aim(enemy.global_position)
			press(KEY_Q)
			if world.player.spells.fire_left > 0:
				shots += 1
		if distance < world.balance.frost_range - 0.5 and world.player.spells.frost_left <= 0:
			aim(enemy.global_position)
			press(KEY_W)
			if world.player.spells.frost_left > 0:
				frost_casts += 1
		if not captured_combat and shots >= 5:
			await capture("playthrough-combat.png")
			captured_combat = true
	push_error("PLAYTHROUGH: controller timed out at %d kills" % world.state.kills)
	quit(1)

func _approach(goal: Vector3) -> void:
	# Query the same mesh for a nearby visible waypoint, then issue a real click.
	var path := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map, world.player.global_position, goal, true)
	var next := goal
	for waypoint in path:
		if waypoint.distance_to(world.player.global_position) > 1.0:
			next = waypoint
			break
	var offset: Vector3 = next - world.player.global_position
	offset.y = 0
	if offset.length() > 6.0:
		next = world.player.global_position + offset.normalized() * 6.0
	next.y = 0
	move(next)

func _kite(enemies: Array[Node]) -> void:
	var best: Vector3 = world.player.global_position
	var best_score: float = -1000
	for i in 20:
		var angle := i * TAU / 20.0
		var point: Vector3 = world.player.global_position + Vector3(cos(angle), 0, sin(angle)) * 3.5
		point.y = 0
		if point.z > 1.7 or not world.is_walkable(point):
			continue
		var nearest: float = 100
		for enemy in enemies:
			nearest = minf(nearest, point.distance_to(enemy.global_position))
		var preferred: float = point.distance_to(enemies[0].global_position)
		var score := nearest - absf(preferred - 5.5) * 0.8
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP, enemies[0].global_position + Vector3.UP, 2)
		if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			score -= 5
		if score > best_score:
			best_score = score
			best = point
	move(best)

func _continue_after_reward() -> void:
	var until: float = world.elapsed + 12.0
	while world.elapsed < until and world.player.global_position.z > 2:
		_approach(Vector3(0, 0, -3))
		await create_timer(0.15).timeout
	aim(world.player.global_position + Vector3(0, 0, -4))
	press(KEY_W)
	var upgraded_cast: bool = world.player.spells.frost_left > 0
	await create_timer(0.25).timeout
	await capture("upgraded.png")
	var report := {
		"result": "passed", "quest_kills": world.state.kills,
		"reward": str(world.state.reward), "completion_seconds": world.completion_time,
		"right_clicks": clicks, "fire_inputs_cast": shots, "frost_inputs_cast": frost_casts,
		"upgraded_radius": world.player.spells.frost_radius(),
		"continued_in_forest": not world.is_safe(world.player.global_position),
		"upgraded_frost_cast": upgraded_cast,
		"note": "Rendered scripted-input playthrough with unchanged health, damage and cooldowns; no teleport or direct damage."
	}
	FileAccess.open("res://artifacts/playthrough.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("PLAYTHROUGH ", JSON.stringify(report))
	quit(0 if report.continued_in_forest and upgraded_cast else 1)
