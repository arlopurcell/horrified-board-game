class_name MonsterToken
extends Node2D

const RADIUS := 14.0
const FILL_COLOR := Color(0.15, 0.10, 0.10)
const BORDER_COLOR := Color(0.80, 0.10, 0.10)

func setup(_data: MonsterData) -> void:
	queue_redraw()

func move_to(world_pos: Vector2) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL_COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BORDER_COLOR, 2.0)
