class_name RunState
extends RefCounted

signal changed
enum Quest { AVAILABLE, ACTIVE, READY, REWARDED }
var quest: Quest = Quest.AVAILABLE
var kills: int = 0
var target: int = 5
var reward: StringName = &""

func accept() -> bool:
	if quest != Quest.AVAILABLE:
		return false
	quest = Quest.ACTIVE
	changed.emit()
	return true

func record_kill() -> void:
	if quest != Quest.ACTIVE:
		return
	kills = mini(kills + 1, target)
	if kills == target:
		quest = Quest.READY
	changed.emit()

func claim(choice: StringName) -> bool:
	if quest != Quest.READY or choice not in [&"fire", &"frost"]:
		return false
	reward = choice
	quest = Quest.REWARDED
	changed.emit()
	return true

