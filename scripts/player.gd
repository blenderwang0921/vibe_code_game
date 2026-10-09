class_name WizardPlayer
extends CharacterBody3D

signal damaged
signal died
var world
var spells: SpellBook
var destination: Vector3
var has_destination: bool = false
@onready var health: ActorHealth = $Health
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: ActorVisual = $Visual

func _ready() -> void:
	health.reset(world.balance.player_health)
	health.died.connect(_die)
	spells = SpellBook.new(world.balance)
	destination = global_position

func move_to(point: Vector3) -> bool:
	if health.dead or not world.navigation_ready or not world.is_walkable(point):
		return false
	destination = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)
	destination.y = 0.0
	agent.target_position = destination
	has_destination = true
	return true

func _physics_process(delta: float) -> void:
	if health.dead:
		return
	spells.tick(delta)
	if world.is_safe(global_position):
		health.heal(world.balance.village_heal_per_second * delta)
	var direction := Vector3.ZERO
	if world.navigation_ready and has_destination:
		if agent.is_navigation_finished():
			has_destination = false
		else:
			direction = agent.get_next_path_position() - global_position
			direction.y = 0
			direction = direction.normalized()
	velocity.x = direction.x * world.balance.player_speed
	velocity.z = direction.z * world.balance.player_speed
	velocity.y = -2.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	visual.moving = direction.length_squared() > 0.1
	if visual.moving and visual.cast_left <= 0.0:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 12.0 * delta)

func face_cast(target: Vector3) -> void:
	var direction := target - global_position
	direction.y = 0
	if direction.length_squared() > 0.001:
		visual.rotation.y = atan2(-direction.x, -direction.z)
	visual.cast()

func take_damage(amount: float) -> void:
	if world.is_safe(global_position):
		return
	if health.damage(amount) > 0:
		visual.flash()
		damaged.emit()

func _die() -> void:
	velocity = Vector3.ZERO
	has_destination = false
	visual.moving = false
	died.emit()

