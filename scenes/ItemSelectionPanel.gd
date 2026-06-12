class_name ItemSelectionPanel
extends PanelContainer

signal confirmed(selected_items: Array[ItemData])
signal cancelled

const REQUIRED_STRENGTH := 6

var _items: Array[ItemData] = []
var _checkboxes: Array[CheckBox] = []
var _strength_boost: int = 0
var _required_strength: int = REQUIRED_STRENGTH
var _custom_message: String = ""
var _total_label: Label
var _confirm_btn: Button
var _item_list: VBoxContainer

func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -210.0
	offset_top = -220.0
	offset_right = 210.0
	offset_bottom = 220.0

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Select Items to Discard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 250)
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	scroll.add_child(_item_list)

	_total_label = Label.new()
	_total_label.text = "Total strength: 0 / 6 required"
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_total_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.pressed.connect(_on_cancelled)
	btn_row.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.custom_minimum_size = Vector2(120, 36)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirmed)
	btn_row.add_child(_confirm_btn)

func open(items: Array[ItemData], strength_boost: int = 0, required_strength: int = REQUIRED_STRENGTH, custom_message: String = "") -> void:
	_items = items
	_strength_boost = strength_boost
	_required_strength = required_strength
	_custom_message = custom_message
	_checkboxes.clear()
	for child in _item_list.get_children():
		child.queue_free()
	for item in items:
		var row := HBoxContainer.new()
		_item_list.add_child(row)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = _item_swatch_color(item)
		row.add_child(swatch)
		var cb := CheckBox.new()
		var effective := item.strength + _strength_boost
		cb.text = "%s  (str %d)" % [item.item_name, effective]
		cb.toggled.connect(_on_toggled)
		row.add_child(cb)
		_checkboxes.append(cb)
	_update_total()
	visible = true

func _item_swatch_color(item: ItemData) -> Color:
	match item.color:
		"red":    return Color(0.75, 0.22, 0.17)
		"blue":   return Color(0.16, 0.50, 0.73)
		"yellow": return Color(0.95, 0.77, 0.06)
		_:        return Color(0.5, 0.5, 0.5, 0.0)


func _on_toggled(_pressed: bool) -> void:
	_update_total()

func _update_total() -> void:
	var total := 0
	var count := 0
	for i in range(_checkboxes.size()):
		if _checkboxes[i].button_pressed:
			total += _items[i].strength + _strength_boost
			count += 1
	if _required_strength <= 0:
		_total_label.text = _custom_message if _custom_message != "" else "Select any item to block the hit"
		_confirm_btn.disabled = count == 0
	else:
		_total_label.text = "Total strength: %d / %d required" % [total, _required_strength]
		_confirm_btn.disabled = total < _required_strength

func _on_confirmed() -> void:
	var selected: Array[ItemData] = []
	for i in range(_checkboxes.size()):
		if _checkboxes[i].button_pressed:
			selected.append(_items[i])
	visible = false
	confirmed.emit(selected)

func _on_cancelled() -> void:
	visible = false
	cancelled.emit()
