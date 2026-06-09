class_name MonsterToken
extends Node2D

const HALF := 13.0
const MOVE_DURATION := 0.75
const FILL_COLOR := Color(0.15, 0.10, 0.10)
const BORDER_COLOR := Color(0.80, 0.10, 0.10)
const LABEL_COLOR := Color.WHITE
const FONT_SIZE := 13

var _label: String = ""

func setup(data: MonsterData) -> void:
	_label = data.monster_name.left(1)
	queue_redraw()

func move_to(world_pos: Vector2) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, MOVE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func _draw() -> void:
	var rect := Rect2(-HALF, -HALF, HALF * 2, HALF * 2)
	draw_rect(rect, FILL_COLOR)
	draw_rect(rect, BORDER_COLOR, false, 2.0)
	if _label.is_empty():
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var ascent := font.get_ascent(FONT_SIZE)
	var descent := font.get_descent(FONT_SIZE)
	draw_string(font, Vector2(-w * 0.5, (ascent - descent) * 0.5),
			_label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOR)
