extends Control

const DIE_SIZE := 80.0
const DIE_GAP := 16.0
const PANEL_PAD_X := 32.0
const PANEL_PAD_Y := 24.0

const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.50)
const PANEL_BG := Color(0.10, 0.07, 0.06, 0.97)
const PANEL_BORDER := Color(0.50, 0.40, 0.15)
const DIE_BG := Color(0.17, 0.13, 0.10)
const BORDER_ROLLING := Color(0.95, 0.82, 0.15)
const BORDER_HIT := Color(0.95, 0.55, 0.10)
const BORDER_POWER := Color(0.90, 0.15, 0.15)
const BORDER_MISS := Color(0.38, 0.38, 0.38)
const HIT_COLOR := Color(1.0, 0.62, 0.12)
const POWER_COLOR := Color(0.95, 0.20, 0.20)

var _symbols: Array[String] = []
var _shakes: Array[Vector2] = []
var _rolling := false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	MonsterManager.dice_rolled.connect(_on_dice_rolled)

func _on_dice_rolled(results: Array) -> void:
	_run_animation(results)

func _run_animation(results: Array) -> void:
	_symbols.clear()
	_shakes.clear()
	for _i in range(results.size()):
		_symbols.append("miss")
		_shakes.append(Vector2.ZERO)
	_rolling = true
	visible = true
	queue_redraw()

	for _c in range(20):
		for i in range(_symbols.size()):
			_symbols[i] = (["hit", "power", "miss"] as Array)[randi() % 3]
			_shakes[i] = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		queue_redraw()
		await get_tree().create_timer(0.065).timeout

	_rolling = false
	for i in range(results.size()):
		_symbols[i] = results[i] as String
		_shakes[i] = Vector2.ZERO
	queue_redraw()

	await get_tree().create_timer(3.0).timeout
	visible = false
	MonsterManager.dice_animation_done.emit()

func _draw() -> void:
	if _symbols.is_empty():
		return
	var n := _symbols.size()
	var total_w := n * DIE_SIZE + (n - 1) * DIE_GAP + PANEL_PAD_X * 2
	var total_h := DIE_SIZE + PANEL_PAD_Y * 2
	var px := (size.x - total_w) * 0.5
	var py := (size.y - total_h) * 0.5

	draw_rect(Rect2(0, 0, size.x, size.y), OVERLAY_COLOR)
	draw_rect(Rect2(px, py, total_w, total_h), PANEL_BG)
	draw_rect(Rect2(px, py, total_w, total_h), PANEL_BORDER, false, 2.0)

	var font := ThemeDB.fallback_font
	for i in range(n):
		var dx := px + PANEL_PAD_X + i * (DIE_SIZE + DIE_GAP) + _shakes[i].x
		var dy := py + PANEL_PAD_Y + _shakes[i].y
		_draw_die(dx, dy, _symbols[i], font)

func _draw_die(x: float, y: float, symbol: String, font: Font) -> void:
	var cx := x + DIE_SIZE * 0.5
	var cy := y + DIE_SIZE * 0.5
	draw_rect(Rect2(x, y, DIE_SIZE, DIE_SIZE), DIE_BG)
	var border: Color
	if _rolling:
		border = BORDER_ROLLING
	else:
		match symbol:
			"hit":   border = BORDER_HIT
			"power": border = BORDER_POWER
			_:       border = BORDER_MISS
	draw_rect(Rect2(x, y, DIE_SIZE, DIE_SIZE), border, false, 3.0)
	match symbol:
		"hit":   _draw_explosion(cx, cy)
		"power": _draw_exclamation(cx, cy, font)

func _draw_explosion(cx: float, cy: float) -> void:
	var outer_r := DIE_SIZE * 0.33
	var inner_r := DIE_SIZE * 0.13
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU / 16.0 * i - PI * 0.5
		var r := outer_r if i % 2 == 0 else inner_r
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	draw_polygon(pts, PackedColorArray([HIT_COLOR]))

func _draw_exclamation(cx: float, cy: float, font: Font) -> void:
	var fs := 46
	var ta := font.get_ascent(fs)
	var td := font.get_descent(fs)
	var w := font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(cx - w * 0.5, cy + (ta - td) * 0.5),
			"!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, POWER_COLOR)
