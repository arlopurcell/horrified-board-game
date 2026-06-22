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

const MUMMY_RING_R := 30.0
const MUMMY_TOKEN_R := 11.0
const MUMMY_PAD_TOP := 6.0
const MUMMY_EMPTY_COL := Color(0.12, 0.10, 0.08)
const MUMMY_HIDDEN_COL := Color(0.25, 0.18, 0.10)
const MUMMY_REVEALED_COL := Color(0.75, 0.58, 0.12)
const MUMMY_CORRECT_COL := Color(0.18, 0.65, 0.25)
const MUMMY_LINE_COL := Color(0.50, 0.50, 0.50, 0.45)
const MUMMY_HINT_COL := Color(0.95, 0.90, 0.20)

const DEFEAT_HEADER_COL := Color(0.85, 0.65, 0.10)
const DEFEAT_TEXT_COL := Color(0.80, 0.80, 0.80)
const FS_DEFEAT := 10
const DEFEAT_LH := 13.0

func _ready() -> void:
	GameManager.items_changed.connect(queue_redraw)
	GameManager.monster_defeated.connect(func(_n: String): queue_redraw())
	GameManager.wolfman_cure_complete.connect(func(_i: int): queue_redraw())
	GameManager.mummy_changed.connect(queue_redraw)
	GameManager.frankenstein_changed.connect(queue_redraw)
	GameManager.creature_changed.connect(queue_redraw)
	GameManager.invisible_man_changed.connect(queue_redraw)
	MonsterManager.frenzy_changed.connect(queue_redraw)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var px := PANEL_X
	for monster_ref in MonsterManager.monsters:
		var m := monster_ref as MonsterData
		var frenzied := (m.monster_name == MonsterManager.frenzied_monster_name)
		if m.monster_name == "Dracula":
			_draw_dracula(font, px)
			px += PANEL_W + PANEL_GAP
		elif m.monster_name == "Wolfman":
			_draw_wolfman(font, px)
			px += PANEL_W + PANEL_GAP
		elif m.monster_name == "Mummy":
			_draw_mummy(font, px)
			px += PANEL_W + PANEL_GAP
		elif m.monster_name == "Frankenstein":
			_draw_frankenstein_bride(font, px)
			px += PANEL_W + PANEL_GAP
		elif m.monster_name == "Bride":
			continue
		elif m.monster_name == "Creature":
			_draw_creature(font, px)
			px += PANEL_W + PANEL_GAP
		elif m.monster_name == "Invisible Man":
			_draw_invisible_man(font, px)
			px += PANEL_W + PANEL_GAP
		else:
			continue
		if frenzied:
			_draw_frenzy_icon(px - PANEL_W - PANEL_GAP)

func _draw_dracula(font: Font, px: float) -> void:
	var coffins := GameManager.dracula_coffins
	var task_end := TITLE_H + coffins.size() * ROW_H
	var panel_h := task_end + _defeat_section_h(2)
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
	_draw_defeat_section(font, px, PANEL_Y + task_end,
			["At Dracula's space:", "yellow items, str ≥6"])


func _draw_wolfman(font: Font, px: float) -> void:
	var rows: Array = [
		["Str 1", GameManager.wolfman_cure_s1 > 0],
		["Str 1", GameManager.wolfman_cure_s1 > 1],
		["Str 2", GameManager.wolfman_cure_s2 > 0],
		["Str 2", GameManager.wolfman_cure_s2 > 1],
		["Str 3", GameManager.wolfman_cure_s3 > 0],
		["Str 3", GameManager.wolfman_cure_s3 > 1],
	]
	var task_end := TITLE_H + rows.size() * ROW_H
	var panel_h := task_end + _defeat_section_h(2)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), PANEL_BG)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), BORDER_COL, false, 2.0)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, TITLE_H), TITLE_BG)
	var ta := font.get_ascent(FS_TITLE)
	var td := font.get_descent(FS_TITLE)
	draw_string(font, Vector2(px, PANEL_Y + TITLE_H * 0.5 + (ta - td) * 0.5),
			"WOLFMAN", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, FS_TITLE, TEXT_COL)
	var ry := PANEL_Y + TITLE_H + H_PAD * 0.5
	var la := font.get_ascent(FS_ROW)
	var ld := font.get_descent(FS_ROW)
	for row in rows:
		var label: String = row[0]
		var checked: bool = row[1]
		var cb_x := px + 8.0
		var cb_y := ry + (ROW_H - CB_SIZE) * 0.5
		draw_rect(Rect2(cb_x, cb_y, CB_SIZE, CB_SIZE), BOX_BG)
		draw_rect(Rect2(cb_x, cb_y, CB_SIZE, CB_SIZE), BOX_BORDER, false, 1.5)
		if checked:
			draw_line(Vector2(cb_x + 2.0, cb_y + CB_SIZE * 0.5),
					Vector2(cb_x + CB_SIZE * 0.38, cb_y + CB_SIZE - 2.5), CHECK_COL, 2.0, true)
			draw_line(Vector2(cb_x + CB_SIZE * 0.38, cb_y + CB_SIZE - 2.5),
					Vector2(cb_x + CB_SIZE - 1.5, cb_y + 2.5), CHECK_COL, 2.0, true)
		draw_string(font, Vector2(cb_x + CB_SIZE + 6.0, ry + ROW_H * 0.5 + (la - ld) * 0.5),
				"Blue item, " + label, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, TEXT_COL)
		ry += ROW_H
	_draw_defeat_section(font, px, PANEL_Y + task_end,
			["At Wolfman's space:", "Cure + red items, str ≥6"])


func _mummy_slot_positions(px: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var cx := px + PANEL_W * 0.5
	var cy := PANEL_Y + TITLE_H + H_PAD + MUMMY_PAD_TOP + MUMMY_RING_R + MUMMY_TOKEN_R
	for i in range(6):
		var angle := -PI * 0.5 + float(i) * PI / 3.0
		positions.append(Vector2(cx + MUMMY_RING_R * cos(angle), cy + MUMMY_RING_R * sin(angle)))
	positions.append(Vector2(cx, cy))
	return positions


func _mummy_panel_x() -> float:
	var px := PANEL_X
	for monster_ref in MonsterManager.monsters:
		var m := monster_ref as MonsterData
		if m.monster_name == "Mummy":
			return px
		if m.monster_name in ["Dracula", "Wolfman"]:
			px += PANEL_W + PANEL_GAP
	return -1.0


func _draw_mummy(font: Font, px: float) -> void:
	if GameManager.mummy_slot_contents.size() < 7:
		return
	var task_end := TITLE_H + H_PAD + MUMMY_PAD_TOP + (MUMMY_RING_R + MUMMY_TOKEN_R) * 2.0
	var panel_h := task_end + _defeat_section_h(2)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), PANEL_BG)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), BORDER_COL, false, 2.0)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, TITLE_H), TITLE_BG)
	var ta := font.get_ascent(FS_TITLE)
	var td := font.get_descent(FS_TITLE)
	draw_string(font, Vector2(px, PANEL_Y + TITLE_H * 0.5 + (ta - td) * 0.5),
			"MUMMY", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, FS_TITLE, TEXT_COL)
	var positions := _mummy_slot_positions(px)
	# Connection lines
	for i in range(6):
		draw_line(positions[i], positions[(i + 1) % 6], MUMMY_LINE_COL, 1.5)
		draw_line(positions[i], positions[6], MUMMY_LINE_COL, 1.5)
	# Slot circles
	var la := font.get_ascent(FS_ROW)
	var ld := font.get_descent(FS_ROW)
	var la_s := font.get_ascent(FS_ROW - 2)
	var ld_s := font.get_descent(FS_ROW - 2)
	for i in range(7):
		var pos := positions[i]
		var contents: int = GameManager.mummy_slot_contents[i]
		var revealed: bool = GameManager.mummy_slot_revealed[i]
		var can_flip := GameManager.can_flip_mummy_token(i)
		var can_slide := GameManager.can_slide_mummy_token(i)
		if contents == 0:
			draw_circle(pos, MUMMY_TOKEN_R, MUMMY_EMPTY_COL)
			draw_arc(pos, MUMMY_TOKEN_R, 0, TAU, 24, BOX_BORDER, 1.5)
		elif not revealed:
			draw_circle(pos, MUMMY_TOKEN_R, MUMMY_HIDDEN_COL)
			var bcol := MUMMY_HINT_COL if can_flip else BOX_BORDER
			draw_arc(pos, MUMMY_TOKEN_R, 0, TAU, 24, bcol, 2.5 if can_flip else 1.5)
			draw_string(font, Vector2(pos.x - MUMMY_TOKEN_R, pos.y + (la - ld) * 0.5),
					"?", HORIZONTAL_ALIGNMENT_CENTER, MUMMY_TOKEN_R * 2.0, FS_ROW, TEXT_COL)
		else:
			var correct := (i < 6 and contents == i + 1)
			var fcol := MUMMY_CORRECT_COL if correct else MUMMY_REVEALED_COL
			draw_circle(pos, MUMMY_TOKEN_R, fcol)
			var bcol := MUMMY_HINT_COL if can_slide else BOX_BORDER
			draw_arc(pos, MUMMY_TOKEN_R, 0, TAU, 24, bcol, 2.5 if can_slide else 1.5)
			draw_string(font, Vector2(pos.x - MUMMY_TOKEN_R, pos.y + (la - ld) * 0.5),
					str(contents), HORIZONTAL_ALIGNMENT_CENTER, MUMMY_TOKEN_R * 2.0, FS_ROW, TEXT_COL)
		# Slot label (small, outside circle) for circle slots only
		if i < 6:
			var angle := -PI * 0.5 + float(i) * PI / 3.0
			var label_dir := Vector2(cos(angle), sin(angle))
			var label_pos := pos + label_dir * (MUMMY_TOKEN_R + 7.0)
			draw_string(font, Vector2(label_pos.x - 6.0, label_pos.y + (la_s - ld_s) * 0.5),
					str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 12.0, FS_ROW - 2,
					Color(0.70, 0.70, 0.70, 0.75))
	_draw_defeat_section(font, px, PANEL_Y + task_end,
			["At Mummy's space:", "red items, str ≥9"])


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if GameManager.phase_running or GameManager.game_over:
		return
	if GameManager.mummy_moves_remaining <= 0:
		return
	var mummy_px := _mummy_panel_x()
	if mummy_px < 0:
		return
	var local_pos := get_local_mouse_position()
	var positions := _mummy_slot_positions(mummy_px)
	for i in range(positions.size()):
		if local_pos.distance_to(positions[i]) <= MUMMY_TOKEN_R:
			if GameManager.try_flip_mummy_token(i) or GameManager.try_slide_mummy_token(i):
				get_viewport().set_input_as_handled()
			return


func _draw_frankenstein_bride(font: Font, px: float) -> void:
	var frank: MonsterData = null
	var bride: MonsterData = null
	for m in MonsterManager.monsters:
		if m.monster_name == "Frankenstein": frank = m
		elif m.monster_name == "Bride": bride = m
	if frank == null:
		return
	var pip := 10.0
	var pip_gap := 2.0
	var label_w := 14.0
	var task_end := TITLE_H + H_PAD + ROW_H * 2
	var panel_h := task_end + _defeat_section_h(2)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), PANEL_BG)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), BORDER_COL, false, 2.0)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, TITLE_H), TITLE_BG)
	var ta := font.get_ascent(FS_TITLE)
	var td := font.get_descent(FS_TITLE)
	draw_string(font, Vector2(px, PANEL_Y + TITLE_H * 0.5 + (ta - td) * 0.5),
			"FRANKENSTEIN", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, FS_TITLE, TEXT_COL)
	var la := font.get_ascent(FS_ROW)
	var ld := font.get_descent(FS_ROW)
	var ry := PANEL_Y + TITLE_H + H_PAD
	# Frankenstein row (yellow, 0-11)
	draw_string(font, Vector2(px + H_PAD, ry + ROW_H * 0.5 + (la - ld) * 0.5),
			"F:", HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, Color(0.95, 0.77, 0.06))
	var fx := px + H_PAD + label_w
	for i in range(frank.dial_max):
		var pip_x := fx + i * (pip + pip_gap)
		var pip_y := ry + (ROW_H - pip) * 0.5
		var filled := (i < frank.dial_value)
		var pip_col := Color(0.95, 0.77, 0.06) if filled else Color(0.25, 0.20, 0.10)
		draw_rect(Rect2(pip_x, pip_y, pip, pip), pip_col)
		draw_rect(Rect2(pip_x, pip_y, pip, pip), BOX_BORDER, false, 1.0)
	ry += ROW_H
	# Bride row (blue, 0-8)
	draw_string(font, Vector2(px + H_PAD, ry + ROW_H * 0.5 + (la - ld) * 0.5),
			"B:", HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, Color(0.16, 0.50, 0.73))
	var bx := px + H_PAD + label_w
	var bride_max := bride.dial_max if bride != null else 8
	var bride_val := bride.dial_value if bride != null else 0
	for i in range(bride_max):
		var pip_x := bx + i * (pip + pip_gap)
		var pip_y := ry + (ROW_H - pip) * 0.5
		var filled := (i < bride_val)
		var pip_col := Color(0.16, 0.50, 0.73) if filled else Color(0.10, 0.14, 0.25)
		draw_rect(Rect2(pip_x, pip_y, pip, pip), pip_col)
		draw_rect(Rect2(pip_x, pip_y, pip, pip), BOX_BORDER, false, 1.0)
	_draw_defeat_section(font, px, PANEL_Y + task_end,
			["Fill dials at their spaces;", "auto-defeat when they meet"])


func _creature_dot_color(path_pos: int) -> Color:
	if path_pos == 0:
		return Color(0.15, 0.15, 0.15)  # black start
	if path_pos >= GameManager.CREATURE_PATH.size():
		return Color(0.16, 0.50, 0.73)  # Lair (blue)
	match GameManager.CREATURE_PATH[path_pos - 1]:
		"red": return Color(0.75, 0.22, 0.17)
		"yellow": return Color(0.95, 0.77, 0.06)
		"blue": return Color(0.16, 0.50, 0.73)
	return Color(0.5, 0.5, 0.5)


func _draw_creature(font: Font, px: float) -> void:
	const DOT_R := 7.0
	const H_STEP := 23.0
	const V_STEP := 24.0
	const DOTS := 20  # positions 0-19

	var path_w := H_STEP * 6.0
	var x0 := px + (PANEL_W - path_w) * 0.5
	var y0 := PANEL_Y + TITLE_H + H_PAD + DOT_R
	var task_end := TITLE_H + H_PAD + V_STEP * 2.0 + DOT_R * 2.0 + 14.0
	var panel_h := task_end + _defeat_section_h(2)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), PANEL_BG)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), BORDER_COL, false, 2.0)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, TITLE_H), TITLE_BG)
	var ta := font.get_ascent(FS_TITLE)
	var td := font.get_descent(FS_TITLE)
	draw_string(font, Vector2(px, PANEL_Y + TITLE_H * 0.5 + (ta - td) * 0.5),
			"CREATURE", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, FS_TITLE, TEXT_COL)

	var positions: Array[Vector2] = []
	for i in range(DOTS):
		var row: int
		var col: int
		if i <= 6:
			row = 0
			col = i
		elif i <= 13:
			row = 1
			col = 13 - i  # right to left
		else:
			row = 2
			col = i - 14
		positions.append(Vector2(x0 + col * H_STEP, y0 + row * V_STEP))

	for i in range(DOTS - 1):
		draw_line(positions[i], positions[i + 1], Color(0.4, 0.4, 0.4, 0.7), 1.5)

	var path_idx := GameManager.creature_path_index
	var la := font.get_ascent(FS_ROW - 2)
	var ld := font.get_descent(FS_ROW - 2)

	for i in range(DOTS):
		var pos := positions[i]
		var col := _creature_dot_color(i)
		draw_circle(pos, DOT_R, col)
		draw_arc(pos, DOT_R, 0, TAU, 24, Color(0.6, 0.6, 0.6, 0.8), 1.0)
		var xh := DOT_R * 0.5
		draw_line(pos + Vector2(-xh, -xh), pos + Vector2(xh, xh), Color(0.9, 0.9, 0.9), 1.5)
		draw_line(pos + Vector2(xh, -xh), pos + Vector2(-xh, xh), Color(0.9, 0.9, 0.9), 1.5)
		if i == 19:
			draw_string(font,
					Vector2(pos.x - 14.0, pos.y + DOT_R + 2.0 + (la + la - ld) * 0.5),
					"LAIR", HORIZONTAL_ALIGNMENT_CENTER, 28.0, FS_ROW - 2,
					Color(0.16, 0.50, 0.73))

	var ind_pos := positions[path_idx]
	draw_arc(ind_pos, DOT_R + 3.0, 0, TAU, 24, Color(1.0, 0.85, 0.0), 2.5)
	_draw_defeat_section(font, px, PANEL_Y + task_end,
			["At Creature's space:", "1 red + 1 yellow + 1 blue"])


func _draw_invisible_man(font: Font, px: float) -> void:
	const SLOT_LABELS := ["Inn", "Barn", "Mans", "Lab", "Inst"]
	const R := 11.0
	const GAP := 6.0
	const SLOTS := 5
	const FS_LABEL := 9
	var label_h := font.get_ascent(FS_LABEL) + font.get_descent(FS_LABEL) + 2.0
	var task_end := TITLE_H + H_PAD + R * 2.0 + 3.0 + label_h
	var panel_h := task_end + _defeat_section_h(2)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), PANEL_BG)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, panel_h), BORDER_COL, false, 2.0)
	draw_rect(Rect2(px, PANEL_Y, PANEL_W, TITLE_H), TITLE_BG)
	var ta := font.get_ascent(FS_TITLE)
	var td := font.get_descent(FS_TITLE)
	draw_string(font, Vector2(px, PANEL_Y + TITLE_H * 0.5 + (ta - td) * 0.5),
			"INVISIBLE MAN", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, FS_TITLE, TEXT_COL)
	var row_w := SLOTS * R * 2.0 + (SLOTS - 1) * GAP
	var cx0 := px + (PANEL_W - row_w) / 2.0 + R
	var cy := PANEL_Y + TITLE_H + H_PAD + R
	var la := font.get_ascent(FS_LABEL)
	var ld := font.get_descent(FS_LABEL)
	for i in range(SLOTS):
		var cx := cx0 + i * (R * 2.0 + GAP)
		var slot = GameManager.invisible_man_slots[i] if i < GameManager.invisible_man_slots.size() else null
		var fill_col := MUMMY_EMPTY_COL
		if slot != null:
			var it := slot as ItemData
			match it.color:
				"red":    fill_col = Color(0.75, 0.22, 0.17)
				"yellow": fill_col = Color(0.95, 0.77, 0.06)
				"blue":   fill_col = Color(0.16, 0.50, 0.73)
		draw_circle(Vector2(cx, cy), R, fill_col)
		draw_arc(Vector2(cx, cy), R, 0, TAU, 24, BOX_BORDER, 1.5)
		var label_y := cy + R + 3.0 + la
		draw_string(font, Vector2(cx - R, label_y),
				SLOT_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, R * 2.0, FS_LABEL,
				Color(0.75, 0.75, 0.75))
	_draw_defeat_section(font, px, PANEL_Y + task_end,
			["At Inv. Man's space:", "red items, str ≥9"])


func _defeat_section_h(n_lines: int) -> float:
	return 5.0 + DEFEAT_LH * (1 + n_lines) + H_PAD


func _draw_defeat_section(font: Font, px: float, y: float, lines: Array[String]) -> void:
	var la := font.get_ascent(FS_DEFEAT)
	var ld := font.get_descent(FS_DEFEAT)
	draw_line(Vector2(px + 4.0, y + 2.0), Vector2(px + PANEL_W - 4.0, y + 2.0),
			Color(0.5, 0.5, 0.5, 0.5), 1.0)
	var ry := y + 5.0
	draw_string(font, Vector2(px + H_PAD, ry + DEFEAT_LH * 0.5 + (la - ld) * 0.5),
			"DEFEAT:", HORIZONTAL_ALIGNMENT_LEFT, -1, FS_DEFEAT, DEFEAT_HEADER_COL)
	ry += DEFEAT_LH
	for line in lines:
		draw_string(font, Vector2(px + H_PAD + 4.0, ry + DEFEAT_LH * 0.5 + (la - ld) * 0.5),
				line, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - H_PAD - 8.0, FS_DEFEAT, DEFEAT_TEXT_COL)
		ry += DEFEAT_LH


func _draw_frenzy_icon(px: float) -> void:
	var sz := TITLE_H - 4.0
	var ix := px + PANEL_W - sz - 3.0
	var iy := PANEL_Y + 2.0
	draw_polygon(
		PackedVector2Array([
			Vector2(ix + sz * 0.5, iy),
			Vector2(ix, iy + sz),
			Vector2(ix + sz, iy + sz),
		]),
		PackedColorArray([Color(1.0, 0.55, 0.0, 1.0)])
	)
