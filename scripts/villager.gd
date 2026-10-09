extends Node3D

var marker: Label3D
var clock: float = 0.0

func _ready() -> void:
	marker = LowPoly.label(self, Vector3(0, 2.7, 0), "◆", Color("f1d69d"), 38)
	LowPoly.label(self, Vector3(0, 2.22, 0), "護林人・榆木", Color("f1e5ce"), 23)
	LowPoly.ring(self, Vector3(0, 0.04, 0), 0.8, Color("d8bd88"))

func _process(delta: float) -> void:
	clock += delta
	marker.position.y = 2.8 + sin(clock * 2) * 0.12

func set_quest_state(state: int) -> void:
	marker.text = "✓" if state == RunState.Quest.REWARDED else ("!" if state == RunState.Quest.READY else "◆")

