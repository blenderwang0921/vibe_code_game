extends SceneTree

var passed: int = 0
var failed: int = 0
var world
var settings := GameBalance.new()

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event)

func teleport_player(point: Vector3) -> void:
	world.player.global_position = point + Vector3.UP * 0.05
	world.player.velocity = Vector3.ZERO
	world.player.has_destination = false

func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	world.respawns.clear()
	await frames(2)

func _run() -> void:
	_test_state()
	_test_health()
	_test_spells()
	world = load("res://scenes/world.tscn").instantiate()
	world.balance = settings.duplicate()
	world.balance.enemy_count = 0
	root.add_child(world)
	current_scene = world
	for i in 600:
		if world.navigation_ready:
			break
		await frames(1)
	check(world.navigation_ready, "navigation map synchronizes")
	if not world.navigation_ready:
		quit(1)
		return
	await frames(5)
	_test_player_model()
	await _test_movement()
	await _test_cursor_aim()
	await _test_fire_collision()
	await _test_frost()
	await _test_ai_and_safety()
	await _test_quest_flow()
	await _test_pause_and_retry()
	await _test_frost_reward_world()
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_state() -> void:
	var run := RunState.new()
	run.record_kill()
	check(run.kills == 0, "kills before acceptance are ignored")
	check(not run.claim(&"fire"), "reward cannot be claimed early")
	check(run.accept() and not run.accept(), "quest acceptance is one-time")
	for i in 7:
		run.record_kill()
	check(run.kills == 5 and run.quest == RunState.Quest.READY, "quest completes at exactly five kills")
	check(not run.claim(&"invalid"), "invalid reward is rejected")
	check(run.claim(&"frost"), "completed quest accepts a valid reward")
	check(not run.claim(&"fire") and run.reward == &"frost", "reward cannot be claimed or replaced twice")

func _test_health() -> void:
	var health := ActorHealth.new()
	root.add_child(health)
	health.reset(100)
	check(health.damage(24) == 24 and health.current == 76, "damage subtracts the configured amount")
	health.heal(999)
	check(health.current == 100, "healing clamps to maximum health")
	var death_count := [0]
	health.died.connect(func(): death_count[0] += 1)
	health.damage(200)
	health.damage(200)
	health.heal(200)
	check(health.dead and health.current == 0 and death_count[0] == 1, "death fires once and cannot be healed away")
	health.queue_free()

func _test_spells() -> void:
	var book := SpellBook.new(settings)
	check(book.try_fire() and not book.try_fire(), "fire cooldown prevents double casts")
	book.tick(settings.fire_cooldown * 0.5)
	check(not book.try_fire(), "fire stays locked through partial cooldown")
	book.tick(settings.fire_cooldown)
	check(book.try_fire(), "fire becomes ready after cooldown")
	check(not book.try_frost(settings.frost_range + 1, true) and book.frost_left == 0, "out-of-range frost does not consume cooldown")
	check(not book.try_frost(1, false) and book.frost_left == 0, "invalid-ground frost does not consume cooldown")
	check(book.try_frost(settings.frost_range, true), "frost accepts its exact range boundary")
	check(not book.try_frost(1, true), "frost cooldown prevents double casts")
	book.tick(settings.frost_cooldown + 1)
	check(book.frost_left == 0, "cooldowns clamp to zero")
	book.apply_reward(&"fire")
	book.apply_reward(&"fire")
	check(is_equal_approx(book.fire_damage(), settings.fire_damage * settings.fire_upgrade_multiplier), "fire upgrade applies once without stacking")
	book.apply_reward(&"frost")
	check(is_equal_approx(book.frost_radius(), settings.frost_radius * settings.frost_upgrade_multiplier), "frost upgrade changes actual area radius")

func _test_player_model() -> void:
	var visual: ActorVisual = world.player.visual
	var model := visual.rig.get_node_or_null("Model") as Node3D
	check(model != null, "player uses the imported character scene")
	if not model:
		return
	check(model.scene_file_path == "res://assets/models/characters/b_grove/character.glb", "selected B Grove character is the gameplay model")
	check((model.basis * Vector3.BACK).is_equal_approx(Vector3.FORWARD), "imported model faces the gameplay forward direction")
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 18, "player retains one shared 18-bone skeleton")
	check(visual.parts.size() == 6, "body and three equipment slots remain separate meshes")
	var rest_transform := visual.rig.transform
	visual.moving = true
	visual.cast()
	visual.flash()
	visual._process(0.05)
	check(visual.parts.all(func(part: MeshInstance3D) -> bool: return part.material_overlay == visual.flash_material), "damage flash reaches every imported mesh")
	check(visual.rig.transform.is_equal_approx(rest_transform), "imported model keeps its authored pose without procedural animation")
	visual._process(0.3)
	check(visual.cast_left == 0.0 and visual.parts.all(func(part: MeshInstance3D) -> bool: return part.material_overlay == null), "cast timing and damage flash recover on imported model")
	visual.moving = false

func _test_movement() -> void:
	teleport_player(Vector3(-3, 0, -3))
	await frames(3)
	check(world.player.move_to(Vector3(-3, 0, -12)), "valid ground target is accepted")
	var destination: Vector3 = world.player.destination
	check(not world.player.move_to(Vector3(200, 0, 200)) and world.player.destination == destination, "outside-map click preserves destination")
	check(not world.player.move_to(Vector3(-3, 0, -7)) and world.player.destination == destination, "tree footprint is not walkable")
	var sidestep: float = 0
	for i in 240:
		await frames(1)
		sidestep = maxf(sidestep, absf(world.player.global_position.x + 3))
	check(world.player.global_position.distance_to(Vector3(-3, 0, -12)) < 0.7, "player reaches target behind tree")
	check(sidestep > 0.9, "navigation routes around the tree collider")
	teleport_player(Vector3(0, 0, 14))
	world.camera_focus = world.player.global_position
	world._update_camera(1.0)
	await frames(2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = world.camera.unproject_position(Vector3(2, 0, 10))
	root.push_input(click, true)
	check(world.player.has_destination, "right-click input reaches navigation through HUD")
	check(world.cast_fire(Vector3(2, 0, 0)), "fire can be cast while moving")
	check(world.player.has_destination, "casting does not cancel movement")
	await frames(80)

func _test_cursor_aim() -> void:
	teleport_player(Vector3(0, 0, -3))
	world.camera_focus = world.player.global_position
	world._update_camera(1.0)
	var target := Vector3(-4, 0, -10)
	var motion := InputEventMouseMotion.new()
	motion.position = world.camera.unproject_position(target)
	root.push_input(motion, true)
	check(world.mouse_ground().distance_to(target) < 0.01, "cursor projects back to the intended world ground position")
	world.player.spells.fire_left = 0
	key(KEY_Q)
	var shots := get_nodes_in_group("projectiles")
	check(shots.size() == 1, "Q keyboard input creates a fireball")
	if not shots.is_empty():
		var expected: Vector3 = target - world.player.global_position
		expected.y = 0
		check(shots[0].direction.dot(expected.normalized()) > 0.999, "fireball direction follows cursor coordinates")
	await frames(70)

func _test_fire_collision() -> void:
	await clear_enemies()
	teleport_player(Vector3(0, 0, -3))
	var first: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -7))
	var behind: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -10))
	first.set_physics_process(false)
	behind.set_physics_process(false)
	await frames(3)
	world.player.spells.fire_left = 0
	world.cast_fire(Vector3(0, 0, -15))
	await frames(40)
	check(first.health.current == settings.enemy_health - settings.fire_damage, "fireball damages first enemy")
	check(behind.health.current == settings.enemy_health, "fireball cannot pierce through first enemy")
	check(get_nodes_in_group("projectiles").is_empty(), "fireball disappears after impact")
	await clear_enemies()
	teleport_player(Vector3(-3, 0, -3))
	var shielded: ForestEnemy = world.spawn_enemy(Vector3(-3, 0, -11))
	shielded.set_physics_process(false)
	await frames(3)
	world.player.spells.fire_left = 0
	world.cast_fire(Vector3(-3, 0, -15))
	await frames(50)
	check(shielded.health.current == settings.enemy_health, "tree blocks fireball before enemy")
	check(get_nodes_in_group("projectiles").is_empty(), "obstacle consumes fireball")

func _test_frost() -> void:
	await clear_enemies()
	teleport_player(Vector3(0, 0, -3))
	var inside: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -8))
	var outside: ForestEnemy = world.spawn_enemy(Vector3(5, 0, -8))
	inside.set_physics_process(false)
	outside.set_physics_process(false)
	world.player.spells.frost_left = 0
	check(not world.cast_frost(Vector3(0, 0, -30)) and world.player.spells.frost_left == 0, "world rejects out-of-range frost without cooldown")
	check(world.cast_frost(Vector3(0, 0, -8)), "in-range frost casts successfully")
	check(inside.health.current == settings.enemy_health - settings.frost_damage, "frost damages enemies inside its radius")
	check(outside.health.current == settings.enemy_health, "frost excludes enemies outside its radius")
	check(inside.slow_left == settings.frost_slow_duration and inside.slow_multiplier < 1, "frost applies timed slow")
	inside.set_physics_process(true)
	teleport_player(Vector3(0, 0, 14))
	await frames(200)
	check(inside.slow_left == 0 and inside.slow_multiplier == 1, "slow expires and restores movement speed")

func _test_ai_and_safety() -> void:
	await clear_enemies()
	teleport_player(Vector3(0, 0, -1))
	var enemy: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -6))
	var initial := enemy.global_position.distance_to(world.player.global_position)
	await frames(50)
	check(enemy.mode == ForestEnemy.Mode.CHASE and enemy.global_position.distance_to(world.player.global_position) < initial - 1, "enemy detects and pursues player")
	await frames(180)
	check(world.player.health.current < settings.player_health, "melee attacks damage player at an interval")
	teleport_player(Vector3(0, 0, 5))
	var health_before: float = world.player.health.current
	world.player.take_damage(50)
	check(world.player.health.current == health_before, "village blocks player damage")
	await frames(10)
	check(enemy.mode == ForestEnemy.Mode.RETURN, "entering village cancels enemy pursuit")
	var crossed: bool = false
	for i in 180:
		await frames(1)
		crossed = crossed or enemy.global_position.z >= world.SAFE_Z
	check(not crossed, "enemy never crosses village boundary")
	check(enemy.global_position.distance_to(enemy.home) < 0.8, "enemy returns to forest home")
	check(world.player.health.current > health_before, "village restores health over time")

func _test_quest_flow() -> void:
	await clear_enemies()
	teleport_player(Vector3(-1, 0, 13))
	key(KEY_E)
	check(world.state.quest == RunState.Quest.ACTIVE, "E near elder accepts quest")
	teleport_player(Vector3(0, 0, -3))
	for i in settings.quest_target:
		var enemy: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -7))
		enemy.set_physics_process(false)
		await frames(2)
		for shot in ceili(settings.enemy_health / settings.fire_damage):
			world.player.spells.fire_left = 0
			world.cast_fire(enemy.global_position)
			await frames(24)
		await frames(2)
	check(world.state.quest == RunState.Quest.READY and world.state.kills == 5, "five real projectile kills complete quest")
	check(world.respawns.size() == 5, "deaths queue delayed replacements")
	teleport_player(Vector3(-1, 0, 13))
	key(KEY_E)
	check(paused and world.hud.modal_kind == "reward", "E on return opens reward choice")
	key(KEY_1)
	check(not paused and world.state.reward == &"fire", "reward key resumes play and grants upgrade")
	check(not world.claim_reward(&"frost"), "world rejects second reward")
	teleport_player(Vector3(0, 0, -3))
	var target: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -7))
	target.set_physics_process(false)
	await frames(3)
	world.player.spells.fire_left = 0
	world.cast_fire(target.global_position)
	await frames(30)
	check(is_equal_approx(target.health.current, settings.enemy_health - settings.fire_damage * settings.fire_upgrade_multiplier), "reward changes real projectile damage in continued combat")
	await clear_enemies()
	var respawned: ForestEnemy = world.spawn_enemy(Vector3(0, 0, -7))
	respawned.take_damage(999)
	await frames(2)
	teleport_player(Vector3(0, 0, 14))
	check(get_nodes_in_group("enemies").is_empty(), "replacement is not immediate")
	await frames(ceili(settings.enemy_respawn_delay * 60) + 10)
	check(get_nodes_in_group("enemies").size() == 1, "replacement appears after configured delay")

func _test_pause_and_retry() -> void:
	world.player.spells.fire_left = 0.9
	key(KEY_ESCAPE)
	var before: float = world.player.spells.fire_left
	var clock_before: float = world.elapsed
	await frames(60)
	check(paused and world.player.spells.fire_left == before and world.elapsed == clock_before, "pause freezes cooldowns and world time")
	key(KEY_ESCAPE)
	await frames(10)
	check(not paused and world.player.spells.fire_left < before, "Esc resumes simulation")
	teleport_player(Vector3(0, 0, -3))
	world.player.take_damage(999)
	check(paused and world.hud.modal_kind == "dead", "death freezes world and shows retry screen")
	key(KEY_R)
	await frames(10)
	world = current_scene
	for i in 600:
		if world.navigation_ready:
			break
		await frames(1)
	check(not paused and not world.player.health.dead and world.player.health.current == world.balance.player_health, "R reload restores player health")
	check(world.state.quest == RunState.Quest.AVAILABLE and world.state.reward == &"" and world.state.kills == 0, "R resets quest and upgrade")
	check(get_nodes_in_group("enemies").size() == world.balance.enemy_count and world.respawns.is_empty(), "R restores initial enemy population and clears respawn queue")

func _test_frost_reward_world() -> void:
	await clear_enemies()
	teleport_player(Vector3(-1, 0, 13))
	world.interact()
	for i in world.balance.quest_target:
		world.state.record_kill()
	check(world.claim_reward(&"frost"), "frost reward branch grants its upgrade")
	teleport_player(Vector3(0, 0, -3))
	var enemy: ForestEnemy = world.spawn_enemy(Vector3(3.5, 0, -7))
	enemy.set_physics_process(false)
	world.cast_frost(Vector3(0, 0, -7))
	check(enemy.health.current < enemy.health.maximum and enemy.slow_left > 0, "upgraded frost hits and slows beyond the original radius")
