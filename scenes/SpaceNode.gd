class_name SpaceNode
extends Area2D

signal clicked(space_id: int)

const SIZE := Vector2(120, 96)
const NORMAL_BG    := Color(0.831, 0.663, 0.416, 1)
const LEGAL_BG     := Color(0.976, 0.918, 0.706, 1)
const BORDER       := Color(0.353, 0.235, 0.1, 1)
const WATER_BG     := Color(0.22, 0.48, 0.78, 1)
const WATER_LEGAL  := Color(0.50, 0.75, 0.95, 1)
const WATER_BORDER := Color(0.10, 0.28, 0.58, 1)

const ITEM_COLORS := {
    "red":    Color(0.75, 0.22, 0.17),
    "blue":   Color(0.16, 0.50, 0.73),
    "yellow": Color(0.95, 0.77, 0.06),
}

var space_data: SpaceData = null
var _is_legal: bool = false
var _items: Array = []

@onready var name_label: Label = $NameLabel

func setup(data: SpaceData) -> void:
	space_data = data
	name_label.text = data.name
	queue_redraw()

func set_legal_move(legal: bool) -> void:
	if _is_legal == legal:
		return
	_is_legal = legal
	queue_redraw()

func set_items(items: Array) -> void:
	_items = items
	queue_redraw()

func get_space_center() -> Vector2:
	return global_position + SIZE / 2

func _ready() -> void:
	input_event.connect(_on_input_event)

func _draw() -> void:
	var water := space_data != null and space_data.is_water
	var bg := (WATER_LEGAL if _is_legal else WATER_BG) if water else (LEGAL_BG if _is_legal else NORMAL_BG)
	var border := WATER_BORDER if water else BORDER
	draw_rect(Rect2(Vector2.ZERO, SIZE), bg)
	draw_rect(Rect2(Vector2.ZERO, SIZE), border, false, 2.0)
	if _items.is_empty():
		return
	var font := ThemeDB.fallback_font
	const R := 11.0
	const FS := 10
	const GAP := 4.0
	var n := _items.size()
	var total_w := n * R * 2.0 + (n - 1) * GAP
	var cx := (SIZE.x - total_w) / 2.0 + R
	var cy := SIZE.y - R - 5.0
	var la := font.get_ascent(FS)
	var ld := font.get_descent(FS)
	for item in _items:
		var item_data := item as ItemData
		if item_data == null:
			cx += R * 2.0 + GAP
			continue
		var col: Color = ITEM_COLORS.get(item_data.color, Color(0.5, 0.5, 0.5))
		draw_circle(Vector2(cx, cy), R, col)
		draw_arc(Vector2(cx, cy), R, 0, TAU, 24, BORDER, 1.5)
		draw_string(font, Vector2(cx - R, cy + (la - ld) * 0.5),
				str(item_data.strength), HORIZONTAL_ALIGNMENT_CENTER, R * 2.0, FS, Color.WHITE)
		cx += R * 2.0 + GAP

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_legal and space_data != null:
			clicked.emit(space_data.id)
