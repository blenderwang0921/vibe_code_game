extends SceneTree

# Runs a real Compatibility-rendered window. No headless or fixed-FPS flag.
# -- --benchmark samples wall-clock frame times; -- --low disables shadows.
var world
var samples: Array[float] = []
var benchmark: bool = false

func _initialize() -> void:
	_run.call_deferred()

func wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var error := picture.save_png("res://artifacts/" + filename)
	print("CAPTURE ", filename, " ", picture.get_size(), " status=", error)

func _run() -> void:
	benchmark = "--benchmark" in OS.get_cmdline_user_args()
	world = load("res://scenes/world.tscn").instantiate()
	if benchmark:
		world.balance = world.balance.duplicate()
		world.balance.player_health = 100000.0
		world.balance.enemy_health = 100000.0
	root.add_child(world)
	current_scene = world
	while not world.navigation_ready:
		await process_frame
	world.set_low_effects("--low" in OS.get_cmdline_user_args())
	print("DEVICE ", RenderingServer.get_video_adapter_name())
	print("WINDOW ", root.size, " RENDERER ", RenderingServer.get_current_rendering_method())
	if benchmark:
		await _benchmark()
	else:
		await wait_frames(90)
		await capture("village.png")
		world.interact()
		world.player.global_position = Vector3(0, 0.05, -10)
		world.player.has_destination = false
		world.camera_focus = world.player.global_position
		world._update_camera(1.0)
		await wait_frames(45)
		world.cast_frost(Vector3(1, 0, -16))
		world.cast_fire(Vector3(1, 0, -16))
		await wait_frames(12)
		await capture("forest.png")
		world.hud.show_modal("pause")
		await wait_frames(2)
		await capture("pause.png")
		world.hud.close_modal()
	quit()

func _benchmark() -> void:
	world.player.global_position = Vector3(0, 0.05, -15)
	world.camera_focus = world.player.global_position
	world._update_camera(1.0)
	var i: int = 0
	for enemy in get_nodes_in_group("enemies"):
		var angle := TAU * i / 10.0
		var point := Vector3(cos(angle) * 6, 0, -15 + sin(angle) * 6)
		var nav := NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map, point)
		enemy.global_position = Vector3(nav.x, 0.05, nav.z)
		enemy.home = enemy.global_position
		i += 1
	# Allow shaders, fonts, and navigation to warm up before taking measurements.
	await create_timer(4.0).timeout
	var started := Time.get_ticks_usec()
	var previous := started
	var minimum_enemies: int = 100
	var casts: int = 0
	var frames: int = 0
	while Time.get_ticks_usec() - started < 30000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		frames += 1
		minimum_enemies = mini(minimum_enemies, get_nodes_in_group("enemies").size())
		if frames % 90 == 0:
			world.player.move_to(Vector3(sin(frames * 0.01) * 4.0, 0, -15 + cos(frames * 0.01) * 3.0))
		var enemies := get_nodes_in_group("enemies")
		if not enemies.is_empty():
			if world.cast_fire(enemies[0].global_position):
				casts += 1
			world.cast_frost(world.player.global_position)
	var duration := float(Time.get_ticks_usec() - started) / 1000000.0
	samples.sort()
	var average_ms: float = 0
	for sample in samples:
		average_ms += sample
	average_ms /= samples.size()
	var report := {
		"engine": Engine.get_version_info().string,
		"device": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": [root.size.x, root.size.y],
		"duration_seconds": duration,
		"frames": frames,
		"average_fps": frames / duration,
		"average_frame_ms": average_ms,
		"p95_frame_ms": samples[int(samples.size() * 0.95)],
		"p99_frame_ms": samples[int(samples.size() * 0.99)],
		"minimum_enemies": minimum_enemies,
		"fire_casts": casts,
		"shadows": world.sunlight.shadow_enabled,
		"note": "Real rendered window; 4s warmup + 30s measurement; elevated HP prevents deaths. No fixed FPS or time scaling."
	}
	var filename := "res://artifacts/benchmark-low.json" if world.low_effects else "res://artifacts/benchmark.json"
	var output := FileAccess.open(filename, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("BENCHMARK ", JSON.stringify(report))
