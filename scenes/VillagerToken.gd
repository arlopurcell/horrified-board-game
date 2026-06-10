class_name VillagerToken
extends Node2D

const HALF := 12.0
const MOVE_DURATION := 0.5
const FILL_COLOR := Color(0.15, 0.60, 0.55, 1.0)
const BORDER_COLOR := Color(0.90, 0.80, 0.25, 1.0)
const LABEL_COLOR := Color.WHITE
const TARGET_COLOR := Color.BLACK
const FONT_SIZE := 10
const TARGET_FONT_SIZE := 9

var _initial: String = ""
var _target_name: String = ""

func setup(data: VillagerData) -> void:
	_initial = data.villager_name.left(1)
	var space := GameManager.board_data.get_space(data.target_space_id) if GameManager.board_data != null else null
	_target_name = space.name if space != null else ""
	queue_redraw()

func move_to(world_pos: Vector2) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, MOVE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func _draw() -> void:
	var top := Vector2(0.0, -HALF)
	var bot_l := Vector2(-HALF, HALF)
	var bot_r := Vector2(HALF, HALF)
	draw_polygon(PackedVector2Array([top, bot_l, bot_r]), PackedColorArray([FILL_COLOR]))
	draw_line(top, bot_l, BORDER_COLOR, 2.0, true)
	draw_line(bot_l, bot_r, BORDER_COLOR, 2.0, true)
	draw_line(bot_r, top, BORDER_COLOR, 2.0, true)

	if not _initial.is_empty():
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var ascent := font.get_ascent(FONT_SIZE)
		var descent := font.get_descent(FONT_SIZE)
		var cy := HALF / 3.0
		draw_string(font, Vector2(-w * 0.5, cy + (ascent - descent) * 0.5),
				_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOR)

	if not _target_name.is_empty():
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(_target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, TARGET_FONT_SIZE).x
		draw_string(font, Vector2(-tw * 0.5, HALF + 12.0),
				_target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, TARGET_FONT_SIZE, TARGET_COLOR)
