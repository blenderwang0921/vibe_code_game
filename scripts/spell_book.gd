class_name SpellBook
extends RefCounted

var balance: GameBalance
var fire_left: float = 0.0
var frost_left: float = 0.0
var fire_multiplier: float = 1.0
var frost_multiplier: float = 1.0

func _init(settings: GameBalance) -> void:
	balance = settings

func tick(delta: float) -> void:
	fire_left = maxf(0.0, fire_left - delta)
	frost_left = maxf(0.0, frost_left - delta)

# Validation precedes mutation: invalid frost targets never consume cooldown.
func try_fire() -> bool:
	if fire_left > 0.0:
		return false
	fire_left = balance.fire_cooldown
	return true

func try_frost(distance: float, valid_ground: bool) -> bool:
	if not valid_ground or distance > balance.frost_range or frost_left > 0.0:
		return false
	frost_left = balance.frost_cooldown
	return true

func apply_reward(choice: StringName) -> void:
	# Assign absolute multipliers, so even an accidental repeated call cannot stack.
	if choice == &"fire":
		fire_multiplier = balance.fire_upgrade_multiplier
	elif choice == &"frost":
		frost_multiplier = balance.frost_upgrade_multiplier

func fire_damage() -> float:
	return balance.fire_damage * fire_multiplier

func frost_radius() -> float:
	return balance.frost_radius * frost_multiplier
