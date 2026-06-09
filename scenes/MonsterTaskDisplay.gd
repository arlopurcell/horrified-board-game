extends Node2D

const PANEL_X := 35.0
const PANEL_Y := 2.0
const PANEL_W := 175.0
const PANEL_GAP := 10.0
const TITLE_H := 18.0
const ROW_H := 16.0
const H_PAD := 4.0
const CB_SIZE := 12.0
const FS_TITLE := 13
const FS_ROW := 12

const PANEL_BG := Color(0.10, 0.07, 0.05, 0.92)
const TITLE_BG := Color(0.65, 0.08, 0.08)
const BORDER_COL := Color(0.80, 0.12, 0.12)
const TEXT_COL := Color(1.0, 1.0, 1.0)
const CHECK_COL := Color(0.22, 0.80, 0.35)
const BOX_BG := Color(0.18, 0.14, 0.12)
const BOX_BORDER := Color(0.60, 0.60, 0.60)

func _ready() -> void:
	GameManager.items_changed.connect(queue_redraw)
	GameManager.monster_defeated.connect(func(_n: String): queue_redraw())

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var px := PANEL_X
	for monster_ref in MonsterManager.monsters:
		var m := monster_ref as MonsterData
		if m.monster_name == "Dracula":
			_draw_dracula(font, px)
			px += PANEL_W + PANEL_GAP

func _draw_dracula(font: Font, px: float) -> void:
	var coffins := GameManager.dracula_coffins
	var panel_h := TITLE_H + coffins.size() * ROW_H + H_PAD
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), PANEL_BG)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), BORDER_COL, false, 2.0)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, TITLE_H), TITLE_BG)
	var ta := font.get_ascent(FS_TITLE)
	var td := font.get_descent(FS_TITLE)
	draw_string(font, Vector2(px, PANEL_Y + TITLE_H * 0.5 + (ta - td) * 0.5),
			"DRACULA", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, FS_TITLE, TEXT_COL)
	var ry := PANEL_Y + TITLE_H + H_PAD * 0.5
	for space_id in coffins:
		var smashed: bool = coffins[space_id]
		var space_name: String = GameManager.board_data.get_space(space_id).name
		var cb_x := px + 8.0
		var cb_y := ry + (ROW_H - CB_SIZE) * 0.5
		draw_rect(Rect2(cb_x, cb_y, CB_SIZE, CB_SIZE), BOX_BG)
		draw_rect(Rect2(cb_x, cb_y, CB_SIZE, CB_SIZE), BOX_BORDER, false, 1.5)
		if smashed:
			draw_line(Vector2(cb_x + 2.0, cb_y + CB_SIZE * 0.5),
					Vector2(cb_x + CB_SIZE * 0.38, cb_y + CB_SIZE - 2.5), CHECK_COL, 2.0, true)
			draw_line(Vector2(cb_x + CB_SIZE * 0.38, cb_y + CB_SIZE - 2.5),
					Vector2(cb_x + CB_SIZE - 1.5, cb_y + 2.5), CHECK_COL, 2.0, true)
		var la := font.get_ascent(FS_ROW)
		var ld := font.get_descent(FS_ROW)
		draw_string(font, Vector2(cb_x + CB_SIZE + 6.0, ry + ROW_H * 0.5 + (la - ld) * 0.5),
				space_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, TEXT_COL)
		ry += ROW_H
