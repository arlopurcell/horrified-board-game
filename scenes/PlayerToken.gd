class_name PlayerToken
extends Node2D

const RADIUS := 14.0
const BORDER_COLOR := Color(0.353, 0.235, 0.1, 1)

var _color: Color = Color.WHITE

func setup(data: PlayerData) -> void:
	_color = data.color
	queue_redraw()

func move_to(world_pos: Vector2) -> void:
	position = world_pos

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, _color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BORDER_COLOR, 2.0)
