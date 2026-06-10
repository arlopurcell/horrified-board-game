class_name MonsterCardDisplay
extends Control

var _card_content: Control = null

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	MonsterManager.card_drawn.connect(_on_card_drawn)
	MonsterManager.phase_completed.connect(_on_phase_completed)

func _on_card_drawn(card: MonsterCardData, item_info: Array) -> void:
	if _card_content != null:
		_card_content.free()
		_card_content = null
	_card_content = _build_card_node(card)
	add_child(_card_content)
	visible = true
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	if not item_info.is_empty():
		await _animate_items(item_info)
	MonsterManager.card_display_done.emit()

func _animate_items(item_info: Array) -> void:
	var vp_size := get_viewport_rect().size
	# Fly from the badge circle at the top of the card (right column, upper area)
	var origin := Vector2(vp_size.x - 170.0, vp_size.y * 0.28)

	var squares: Array[ColorRect] = []
	var last_tween: Tween = null

	for i in range(item_info.size()):
		var info: Dictionary = item_info[i]
		var target_screen := get_viewport().canvas_transform * (info["world_pos"] as Vector2)

		var sq := ColorRect.new()
		sq.size = Vector2(14.0, 14.0)
		sq.position = origin - Vector2(7.0, 7.0)
		match (info["color"] as String):
			"red":    sq.color = Color(0.75, 0.22, 0.17)
			"blue":   sq.color = Color(0.16, 0.50, 0.73)
			"yellow": sq.color = Color(0.95, 0.77, 0.06)
			_:        sq.color = Color(0.7, 0.6, 0.4)
		add_child(sq)
		squares.append(sq)

		var tween := create_tween()
		tween.tween_interval(i * 0.08)
		tween.tween_property(sq, "position", target_screen - Vector2(7.0, 7.0), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		last_tween = tween

	if last_tween != null:
		await last_tween.finished

	for sq in squares:
		sq.queue_free()

func _on_phase_completed(_summary: String) -> void:
	visible = false

func _build_card_node(card: MonsterCardData) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.mouse_filter = MOUSE_FILTER_PASS

	# Right-side column: 320px wide, 20px from the right edge, full height
	var right_col := Control.new()
	right_col.anchor_left = 1.0
	right_col.anchor_right = 1.0
	right_col.anchor_top = 0.0
	right_col.anchor_bottom = 1.0
	right_col.offset_left = -340.0
	right_col.offset_right = -20.0
	right_col.mouse_filter = MOUSE_FILTER_PASS
	root.add_child(right_col)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_PASS
	right_col.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.07, 0.05, 1.0)
	panel_style.border_color = Color(0.65, 0.50, 0.18, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# --- Top: items to draw circle ---
	var top_center := CenterContainer.new()
	vbox.add_child(top_center)

	var badge_vbox := VBoxContainer.new()
	badge_vbox.add_theme_constant_override("separation", 5)
	top_center.add_child(badge_vbox)

	var badge_center := CenterContainer.new()
	badge_vbox.add_child(badge_center)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(70.0, 70.0)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.70, 0.55, 0.15, 1.0)
	badge_style.set_border_width_all(0)
	badge_style.corner_radius_top_left = 35
	badge_style.corner_radius_top_right = 35
	badge_style.corner_radius_bottom_left = 35
	badge_style.corner_radius_bottom_right = 35
	badge.add_theme_stylebox_override("panel", badge_style)
	badge_center.add_child(badge)

	var badge_num_center := CenterContainer.new()
	badge.add_child(badge_num_center)

	var num_lbl := Label.new()
	num_lbl.text = str(card.items_to_draw)
	num_lbl.add_theme_font_size_override("font_size", 30)
	num_lbl.add_theme_color_override("font_color", Color(0.10, 0.07, 0.04, 1.0))
	badge_num_center.add_child(num_lbl)

	var items_lbl := Label.new()
	items_lbl.text = "items to draw"
	items_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_lbl.add_theme_font_size_override("font_size", 11)
	items_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.40, 1.0))
	badge_vbox.add_child(items_lbl)

	vbox.add_child(HSeparator.new())

	# --- Middle: title and description ---
	var title_lbl := Label.new()
	title_lbl.text = card.card_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.15, 1.0))
	vbox.add_child(title_lbl)

	if card.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = card.description
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.72, 0.58, 1.0))
		vbox.add_child(desc_lbl)

	vbox.add_child(HSeparator.new())

	# --- Bottom: monster activations ---
	for monster_name: String in card.monster_names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = monster_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75, 1.0))
		row.add_child(name_lbl)

		var step_word := "step" if card.move_steps == 1 else "steps"
		var move_lbl := Label.new()
		move_lbl.text = "%d %s" % [card.move_steps, step_word]
		move_lbl.add_theme_font_size_override("font_size", 13)
		move_lbl.add_theme_color_override("font_color", Color(0.55, 0.78, 0.55, 1.0))
		row.add_child(move_lbl)

		var die_word := "die" if card.attack_dice == 1 else "dice"
		var dice_lbl := Label.new()
		dice_lbl.text = "%d %s" % [card.attack_dice, die_word]
		dice_lbl.add_theme_font_size_override("font_size", 13)
		dice_lbl.add_theme_color_override("font_color", Color(0.90, 0.55, 0.35, 1.0))
		row.add_child(dice_lbl)

	return root
