class_name ForestEnemy
extends CharacterBody3D

enum Mode { IDLE, CHASE, RETURN }
var world
var home: Vector3
var mode: Mode = Mode.IDLE
var slow_left: float = 0.0
var slow_multiplier: float = 1.0
var attack_left: float = 0.0
var windup_left: float = 0.0
var repath_left: float = 0.0
var warning_ring: MeshInstance3D
@onready var health: ActorHealth = $Health
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: ActorVisual = $Visual

func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	health.reset(world.balance.enemy_health)
	health.died.connect(_die)
	warning_ring = LowPoly.ring(self, Vector3(0, 0.04, 0), 0.85, Color("f8ac79"), 0.05)
	warning_ring.hide()

func apply_slow(multiplier: float, duration: float) -> void:
	if health.dead:
		return
	slow_multiplier = minf(slow_multiplier, multiplier)
	slow_left = maxf(slow_left, duration)

func take_damage(amount: float) -> void:
	if health.damage(amount) > 0.0:
		visual.flash()
		if mode == Mode.IDLE and not world.is_safe(world.player.global_position):
			mode = Mode.CHASE

func _die() -> void:
	remove_from_group("enemies")
	collision_layer = 0
	world.enemy_defeated(self)
	queue_free()

func _physics_process(delta: float) -> void:
	if health.dead or not world.navigation_ready or world.player.health.dead:
		return
	var settings: GameBalance = world.balance
	var player_position: Vector3 = world.player.global_position
	var distance := global_position.distance_to(player_position)
	var safe: bool = world.is_safe(player_position)
	slow_left = maxf(0.0, slow_left - delta)
	if slow_left <= 0.0:
		slow_multiplier = 1.0
	attack_left = maxf(0.0, attack_left - delta)
	repath_left -= delta
	if mode == Mode.IDLE and not safe and distance < settings.enemy_detection_range:
		mode = Mode.CHASE
	if mode == Mode.CHASE and (safe or global_position.distance_to(home) > settings.enemy_leash_range):
		mode = Mode.RETURN
		windup_left = 0.0
		repath_left = 0.0
	if mode == Mode.RETURN and global_position.distance_to(home) < 0.6:
		mode = Mode.IDLE
		health.heal(settings.enemy_health)
	var direction := Vector3.ZERO
	if mode == Mode.CHASE:
		if windup_left > 0.0:
			windup_left = maxf(0.0, windup_left - delta)
			if windup_left == 0.0 and distance <= settings.enemy_attack_range + 0.2 and not safe:
				world.player.take_damage(settings.enemy_damage)
		elif distance <= settings.enemy_attack_range:
			if attack_left <= 0.0:
				windup_left = 0.35
				attack_left = settings.enemy_attack_interval
				visual.cast()
		else:
			direction = _path_direction(player_position)
	elif mode == Mode.RETURN:
		direction = _path_direction(home)
	warning_ring.visible = windup_left > 0.0
	# Separation keeps a small pack from occupying exactly the same position.
	if direction.length_squared() > 0.0:
		var separation := Vector3.ZERO
		for other in get_tree().get_nodes_in_group("enemies"):
			if other == self:
				continue
			var away: Vector3 = global_position - other.global_position
			away.y = 0
			if away.length_squared() > 0.001 and away.length_squared() < 1.3:
				separation += away.normalized() * (1.15 - away.length())
		direction = (direction + separation * 1.6).normalized()
	velocity.x = direction.x * settings.enemy_speed * slow_multiplier
	velocity.z = direction.z * settings.enemy_speed * slow_multiplier
	# The village line is an absolute boundary, including paths around obstacles.
	if global_position.z + velocity.z * delta >= world.SAFE_Z - 0.55:
		velocity.z = minf(velocity.z, 0.0)
	velocity.y = -2.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	visual.moving = Vector2(velocity.x, velocity.z).length_squared() > 0.05
	if visual.moving:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
	elif mode == Mode.CHASE:
		var facing := player_position - global_position
		visual.rotation.y = atan2(-facing.x, -facing.z)

func _path_direction(target: Vector3) -> Vector3:
	if repath_left <= 0.0:
		agent.target_position = target
		repath_left = 0.25
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var direction := agent.get_next_path_position() - global_position
	direction.y = 0.0
	return direction.normalized()

