class_name InputBindings
extends RefCounted

static func install() -> void:
	var keys := {"fire": KEY_Q, "frost": KEY_W, "interact": KEY_E,
		"retry": KEY_R, "pause": KEY_ESCAPE, "reward_fire": KEY_1, "reward_frost": KEY_2}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("move"):
		InputMap.add_action("move")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("move", event)

