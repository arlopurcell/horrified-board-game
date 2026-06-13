class_name SpaceNode
extends Area2D

signal clicked(space_id: int)

const SIZE := Vector2(100, 80)
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
	var counts := {"red": 0, "blue": 0, "yellow": 0}
	for item in _items:
		var item_data := item as ItemData
		if item_data != null and counts.has(item_data.color):
			counts[item_data.color] += 1
	var present: Array = []
	for c in ["red", "blue", "yellow"]:
		if counts[c] > 0:
			present.append(c)
	if present.is_empty():
		return
	var bar_w := 20.0
	var bar_h := 8.0
	var gap := 3.0
	var total_w := present.size() * bar_w + (present.size() - 1) * gap
	var x := (SIZE.x - total_w) / 2.0
	var bar_y := SIZE.y - bar_h - 4.0
	var font := ThemeDB.fallback_font
	for c in present:
		var col: Color = ITEM_COLORS[c]
		draw_rect(Rect2(x, bar_y, bar_w, bar_h), col)
		draw_rect(Rect2(x, bar_y, bar_w, bar_h), BORDER, false, 1.0)
		draw_string(font, Vector2(x + bar_w / 2.0, bar_y - 1.0), str(counts[c]),
				HORIZONTAL_ALIGNMENT_CENTER, bar_w, 9, BORDER)
		x += bar_w + gap

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_legal and space_data != null:
			clicked.emit(space_data.id)
