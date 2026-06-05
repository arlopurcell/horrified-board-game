class_name SpaceNode
extends Area2D

signal clicked(space_id: int)

const SIZE := Vector2(100, 80)
const NORMAL_BG := Color(0.831, 0.663, 0.416, 1)
const LEGAL_BG  := Color(0.976, 0.918, 0.706, 1)
const BORDER    := Color(0.353, 0.235, 0.1, 1)
const ITEM_COLOR := Color(0.18, 0.49, 0.2, 1)
const SLOT_COLOR := Color(0.353, 0.235, 0.1, 0.25)

var space_data: SpaceData = null
var _is_legal: bool = false

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

func get_space_center() -> Vector2:
	return global_position + SIZE / 2

func _ready() -> void:
	input_event.connect(_on_input_event)

func _draw() -> void:
	var bg := LEGAL_BG if _is_legal else NORMAL_BG
	draw_rect(Rect2(Vector2.ZERO, SIZE), bg)
	draw_rect(Rect2(Vector2.ZERO, SIZE), BORDER, false, 2.0)
	# Item slot at bottom
	if space_data != null:
		var slot := Rect2(10, 58, 80, 16)
		if space_data.has_item:
			draw_rect(slot, ITEM_COLOR)
		else:
			draw_rect(slot, SLOT_COLOR)
			draw_rect(slot, BORDER, false, 1.0)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_legal and space_data != null:
			clicked.emit(space_data.id)
