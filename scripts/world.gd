extends Node3D

const SAFE_Z: float = 4.0
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const VILLAGER_SCENE = preload("res://scenes/villager.tscn")
const FIREBALL_SCENE = preload("res://scenes/fireball.tscn")
const EFFECT_SCENE = preload("res://scenes/effect.tscn")
const HUD_SCENE = preload("res://scenes/hud.tscn")
@export var balance: GameBalance = preload("res://resources/balance.tres")
var state := RunState.new()
var player: WizardPlayer
var elder: Node3D
var hud: CanvasLayer
var camera: Camera3D
var sunlight: DirectionalLight3D
var navigation: NavigationRegion3D
var navigation_ready: bool = false
var builder := WorldBuilder.new()
var aim_ring: MeshInstance3D
var move_ring: MeshInstance3D
var move_ring_left: float = 0.0
var camera_focus := Vector3(0, 0, 14)
var respawns: Array[Dictionary] = []
var spawn_index: int = 0
var elapsed: float = 0.0
var completion_time: float = 0.0
var low_effects: bool = false
var mouse_screen := Vector2.ZERO
var spawn_points: Array[Vector3] = [Vector3(-2, 0, -4), Vector3(5, 0, -10), Vector3(-10, 0, -14),
	Vector3(1, 0, -17), Vector3(14, 0, -15), Vector3(-7, 0, -25), Vector3(8, 0, -29),
	Vector3(-17, 0, -22), Vector3(17, 0, -28), Vector3(0, 0, -34)]

func _ready() -> void:
	InputBindings.install()
	mouse_screen = get_viewport().get_mouse_position()
	state.target = balance.quest_target
	_setup_environment()
	navigation = NavigationRegion3D.new()
	navigation.name = "Navigation"
	add_child(navigation)
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	builder.build(navigation, scenery)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 3
	nav_mesh.agent_radius = 0.75
	nav_mesh.agent_height = 1.5
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	navigation.navigation_mesh = nav_mesh
	navigation.bake_navigation_mesh(false)
	elder = VILLAGER_SCENE.instantiate()
	elder.position = Vector3(-2.5, 0, 12)
	add_child(elder)
	player = PLAYER_SCENE.instantiate()
	player.world = self
	player.position = Vector3(0, 0.05, 13.5)
	add_child(player)
	player.died.connect(_on_player_died)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.bind_world(self)
	state.changed.connect(_on_quest_changed)
	aim_ring = LowPoly.ring(self, Vector3.ZERO, 0.28, Color("dce7cb"), 0.023)
	move_ring = LowPoly.ring(self, Vector3.ZERO, 0.45, Color("e2d49f"), 0.03)
	move_ring.hide()
	# The first map iteration may still be empty. Wait for this region's surface,
	# not simply a nonzero iteration ID, before querying paths or spawning actors.
	while true:
		await get_tree().physics_frame
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		var probe := NavigationServer3D.map_get_closest_point(map, Vector3(0, 0, 14))
		if Vector2(probe.x, probe.z).distance_to(Vector2(0, 14)) < 0.1:
			break
	navigation_ready = true
	for i in balance.enemy_count:
		spawn_enemy(next_spawn())
	hud.notify("歡迎來到暮光林地。靠近護林人，按 E 接下委託。", 6.0)

func _setup_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("253d46")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b6ced2")
	settings.ambient_light_energy = 0.32
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-58, -28, 0)
	sunlight.light_color = Color("ffe4b9")
	sunlight.light_energy = 0.65
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 55
	add_child(sunlight)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 26.0
	camera.far = 150
	add_child(camera)
	_update_camera(1.0)
	camera.make_current()

func _process(delta: float) -> void:
	_update_camera(delta)
	if not is_instance_valid(player):
		return
	var target = mouse_ground()
	aim_ring.visible = target != null and inside_map(target)
	if aim_ring.visible:
		aim_ring.global_position = target + Vector3(0, 0.04, 0)
	move_ring_left = maxf(0, move_ring_left - delta)
	move_ring.visible = move_ring_left > 0.0

func _physics_process(delta: float) -> void:
	if not navigation_ready or player.health.dead:
		return
	elapsed += delta
	for i in range(respawns.size() - 1, -1, -1):
		respawns[i].left -= delta
		if respawns[i].left <= 0.0:
			spawn_enemy(respawns[i].position)
			respawns.remove_at(i)

func _update_camera(delta: float) -> void:
	if is_instance_valid(player):
		camera_focus = camera_focus.lerp(player.global_position, 1.0 - exp(-7.0 * delta))
	camera.position = camera_focus + Vector3(13, 20, 17)
	camera.look_at(camera_focus + Vector3(0, 0.6, 0))

func inside_map(point: Vector3) -> bool:
	return absf(point.x) < 25.4 and point.z > -39.4 and point.z < 23.4

func is_safe(point: Vector3) -> bool:
	return point.z >= SAFE_Z

func is_walkable(point: Vector3) -> bool:
	if not navigation_ready or not inside_map(point):
		return false
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)
	# Recast places the flat ground surface at y=0.5 with this voxel size.
	return Vector2(closest.x, closest.z).distance_to(Vector2(point.x, point.z)) < 0.25 and absf(closest.y - point.y) < 0.65

func mouse_ground():
	return Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(mouse_screen), camera.project_ray_normal(mouse_screen))

func _input(event: InputEvent) -> void:
	# Cache viewport-local input coordinates. This also makes synthetic inputs
	# behave exactly like real mouse movement, without moving the OS cursor.
	if event is InputEventMouse:
		mouse_screen = event.position

func move_from_screen(screen: Vector2) -> bool:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * 150.0, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider.collision_layer != 1:
		return false
	if player.move_to(hit.position):
		move_ring.global_position = hit.position + Vector3(0, 0.05, 0)
		move_ring_left = 0.9
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not navigation_ready or player.health.dead:
		return
	if event.is_action_pressed("move"):
		if not move_from_screen(event.position):
			hud.notify("這裡無法通行。請點選空曠的地面。", 1.8)
	elif event.is_action_pressed("fire") and not event.is_echo():
		var target = mouse_ground()
		if target != null:
			cast_fire(target)
	elif event.is_action_pressed("frost") and not event.is_echo():
		var target = mouse_ground()
		if target != null:
			cast_frost(target)
	elif event.is_action_pressed("interact") and not event.is_echo():
		interact()

func cast_fire(target: Vector3) -> bool:
	if player.health.dead or get_tree().paused:
		return false
	var direction := target - player.global_position
	direction.y = 0
	if direction.length_squared() < 0.01 or not player.spells.try_fire():
		return false
	var shot = FIREBALL_SCENE.instantiate()
	shot.world = self
	shot.direction = direction.normalized()
	shot.damage = player.spells.fire_damage()
	shot.speed = balance.fire_speed
	shot.max_distance = balance.fire_range
	shot.position = player.global_position + Vector3(0, 0.85, 0)
	add_child(shot)
	player.face_cast(target)
	return true

func cast_frost(target: Vector3) -> bool:
	if player.health.dead or get_tree().paused:
		return false
	var flat := Vector3(target.x, player.global_position.y, target.z)
	var distance := player.global_position.distance_to(flat)
	if distance > balance.frost_range or not inside_map(target):
		hud.notify("冰霜超出射程（%d 公尺），請再靠近一些。" % balance.frost_range, 2.0)
		return false
	if not player.spells.try_frost(distance, true):
		return false
	var radius := player.spells.frost_radius()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_flat := Vector3(enemy.global_position.x, 0, enemy.global_position.z)
		if enemy_flat.distance_to(Vector3(target.x, 0, target.z)) <= radius:
			enemy.apply_slow(balance.frost_slow_multiplier, balance.frost_slow_duration)
			enemy.take_damage(balance.frost_damage)
	effect(Vector3(target.x, 0, target.z), Color("a1e9eb"), radius)
	player.face_cast(target)
	return true

func interact() -> void:
	if player.global_position.distance_to(elder.global_position) > 3.2:
		hud.notify("請靠近村莊的護林人・榆木，再按 E。", 2.5)
		return
	match state.quest:
		RunState.Quest.AVAILABLE:
			state.accept()
			hud.notify("榆木：森林的苔背獸躁動不安。請驅散 %d 隻，回來教你新的魔法。" % state.target, 7.0)
		RunState.Quest.ACTIVE:
			hud.notify("榆木：已驅散 %d / %d 隻。沿小徑往北走，小心牠們的衝撞。" % [state.kills, state.target], 4.0)
		RunState.Quest.READY:
			hud.show_modal("reward")
		RunState.Quest.REWARDED:
			hud.notify("榆木：做得好，小巫師！你的新魔法已準備好了，去森林試試吧。", 4.0)

func claim_reward(choice: StringName) -> bool:
	if player.health.dead or player.global_position.distance_to(elder.global_position) > 3.2:
		return false
	if not state.claim(choice):
		return false
	player.spells.apply_reward(choice)
	completion_time = elapsed
	hud.close_modal()
	effect(player.global_position, Color("f4d89a"), 1.6)
	hud.notify("習得熾焰：火球傷害提升！可以繼續進入森林試打。" if choice == &"fire" else "習得凜冬：冰霜範圍擴大！可以繼續進入森林試打。", 6.0)
	return true

func _on_quest_changed() -> void:
	elder.set_quest_state(state.quest)
	if state.quest == RunState.Quest.READY:
		hud.notify("委託完成！回村找榆木，按 E 領取法術強化。", 6.0)

func next_spawn() -> Vector3:
	var point := spawn_points[spawn_index % spawn_points.size()]
	spawn_index += 1
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)
	return Vector3(closest.x, 0.05, closest.z)

func spawn_enemy(point: Vector3) -> ForestEnemy:
	var enemy: ForestEnemy = ENEMY_SCENE.instantiate()
	enemy.world = self
	enemy.position = point
	add_child(enemy)
	return enemy

func enemy_defeated(enemy: ForestEnemy) -> void:
	state.record_kill()
	effect(enemy.global_position, Color("cce0a0"), 0.9)
	respawns.append({"left": balance.enemy_respawn_delay, "position": enemy.home})

func effect(point: Vector3, color: Color, radius: float) -> void:
	var impact = EFFECT_SCENE.instantiate()
	impact.position = point
	impact.tint = color
	impact.radius = radius
	impact.lifetime = 0.4 if low_effects else 0.65
	add_child(impact)

func _on_player_died() -> void:
	hud.show_modal("dead")

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func set_low_effects(enabled: bool) -> void:
	low_effects = enabled
	sunlight.shadow_enabled = not enabled

