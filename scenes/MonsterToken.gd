class_name MonsterToken
extends Node2D

const RADIUS := 14.0
const FILL_COLOR := Color(0.15, 0.10, 0.10)
const BORDER_COLOR := Color(0.80, 0.10, 0.10)

func setup(_data: MonsterData) -> void:
	queue_redraw()

func move_to(world_pos: Vector2) -> void:
	position = world_pos

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL_COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BORDER_COLOR, 2.0)
