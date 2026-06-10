extends Node2D

const PIP_COUNT := 7
const PIP_RADIUS := 9.0
const PIP_SPACING := 24.0

var _level: int = 0


func _ready() -> void:
	GameManager.terror_changed.connect(_on_terror_changed)


func _on_terror_changed(level: int) -> void:
	_level = level
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 13
	# Label sits to the left; pips start after it
	var label_width := 58.0
	var label_pos := Vector2(-label_width - PIP_RADIUS - 6.0, 5.0)
	draw_string(font, label_pos, "TERROR", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.9, 0.75, 0.2, 1.0))

	for i in range(PIP_COUNT):
		var center := Vector2(i * PIP_SPACING, 0.0)
		var filled := i < _level
		var fill_color := Color(0.85, 0.15, 0.1, 1.0) if filled else Color(0.15, 0.10, 0.08, 1.0)
		var border_color := Color(0.65, 0.50, 0.18, 1.0)
		draw_circle(center, PIP_RADIUS, fill_color)
		draw_arc(center, PIP_RADIUS, 0.0, TAU, 32, border_color, 1.5)
