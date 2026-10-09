class_name ActorHealth
extends Node

signal changed(current: float, maximum: float)
signal died
var maximum: float = 100.0
var current: float = 100.0
var dead: bool = false

func reset(value: float) -> void:
	maximum = maxf(value, 1.0)
	current = maximum
	dead = false
	changed.emit(current, maximum)

func damage(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current)
	current -= applied
	changed.emit(current, maximum)
	if current <= 0.0:
		dead = true
		died.emit()
	return applied

func heal(amount: float) -> void:
	if not dead and amount > 0.0:
		current = minf(current + amount, maximum)
		changed.emit(current, maximum)

