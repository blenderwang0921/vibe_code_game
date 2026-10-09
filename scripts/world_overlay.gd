extends Control

var world

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world == null or not is_instance_valid(world.player):
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health.dead or enemy.global_position.distance_to(world.player.global_position) > 19.0:
			continue
		var above: Vector3 = enemy.global_position + Vector3(0, 1.75, 0)
		if world.camera.is_position_behind(above):
			continue
		var point: Vector2 = world.camera.unproject_position(above)
		if not get_viewport_rect().grow(-12).has_point(point):
			continue
		var rect := Rect2(point - Vector2(27, 0), Vector2(54, 6))
		draw_rect(rect.grow(2), Color("183231"))
		draw_rect(rect, Color("344b49"))
		draw_rect(Rect2(rect.position, Vector2(54 * enemy.health.current / enemy.health.maximum, 6)), Color("e5aa85"))
		if enemy.slow_left > 0:
			draw_circle(point + Vector2(34, 3), 3.0, Color("a1e9eb"))

