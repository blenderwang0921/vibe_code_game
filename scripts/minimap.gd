extends Control

var world

func _process(_delta: float) -> void:
	queue_redraw()

func _point(position_3d: Vector3) -> Vector2:
	return Vector2(10 + (position_3d.x + 26) / 52 * (size.x - 20), 10 + (position_3d.z + 40) / 64 * (size.y - 20))

func _draw() -> void:
	if world == null or not is_instance_valid(world.player):
		return
	var edge := _point(Vector3(0, 0, world.SAFE_Z)).y
	draw_rect(Rect2(6, 6, size.x - 12, edge - 6), Color("294b45"))
	draw_rect(Rect2(6, edge, size.x - 12, size.y - edge - 6), Color("53655a"))
	draw_line(Vector2(size.x * 0.5, 12), Vector2(size.x * 0.5, size.y - 12), Color("9aab81"), 2)
	draw_line(Vector2(6, edge), Vector2(size.x - 6, edge), Color("a8d5be"), 1)
	for point in world.builder.obstacle_points:
		draw_circle(_point(point), 2.2, Color("6f9278"))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		draw_circle(_point(enemy.global_position), 2.5, Color("e0a284"))
	draw_circle(_point(world.elder.global_position), 3.5, Color("f1d69d"))
	var player: Vector2 = _point(world.player.global_position)
	draw_circle(player, 5, Color("263f45"))
	draw_circle(player, 3.5, Color("e5fff1"))
	draw_string(LowPoly.font(), Vector2(10, 22), "北", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("bcd5c5"))

