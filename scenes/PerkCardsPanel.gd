class_name PerkCardsPanel
extends Control

signal card_clicked(card: PerkCardData)

var _hbox: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	offset_top = -195.0
	offset_bottom = -70.0
	offset_left = 270.0
	offset_right = -20.0
	mouse_filter = MOUSE_FILTER_PASS

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_PASS
	add_child(center)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 10)
	_hbox.mouse_filter = MOUSE_FILTER_PASS
	center.add_child(_hbox)

	GameManager.perk_cards_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for child in _hbox.get_children():
		child.queue_free()
	for card in GameManager.perk_cards:
		_hbox.add_child(_make_card_button(card as PerkCardData))

func _make_card_button(card: PerkCardData) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150.0, 120.0)
	btn.focus_mode = Control.FOCUS_NONE

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.07, 0.05, 0.95)
	normal_style.border_color = Color(0.65, 0.50, 0.18, 1.0)
	normal_style.set_border_width_all(2)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.18, 0.13, 0.08, 0.95)
	hover_style.border_color = Color(0.85, 0.68, 0.28, 1.0)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.06, 0.04, 0.03, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = MOUSE_FILTER_PASS
	btn.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = card.title if card.title != "" else "Perk Card"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 1.0))
	title_lbl.mouse_filter = MOUSE_FILTER_PASS
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	var desc_lbl := Label.new()
	desc_lbl.text = card.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55, 1.0))
	desc_lbl.mouse_filter = MOUSE_FILTER_PASS
	vbox.add_child(desc_lbl)

	btn.pressed.connect(func() -> void: card_clicked.emit(card))
	return btn
