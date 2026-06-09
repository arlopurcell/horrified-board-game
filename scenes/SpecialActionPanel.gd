class_name SpecialActionPanel
extends PanelContainer

signal selected(choice_idx: int)
signal cancelled

var _btn_container: VBoxContainer
var _title_label: Label

func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -160.0
	offset_top = -200.0
	offset_right = 160.0
	offset_bottom = 200.0

	var vbox := VBoxContainer.new()
	add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 240)
	vbox.add_child(scroll)

	_btn_container = VBoxContainer.new()
	_btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_btn_container)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_btn.pressed.connect(_on_cancelled)
	vbox.add_child(cancel_btn)

func open(title: String, choices: Array) -> void:
	_title_label.text = title
	for child in _btn_container.get_children():
		child.queue_free()
	for i in range(choices.size()):
		var btn := Button.new()
		btn.text = str(choices[i])
		btn.custom_minimum_size = Vector2(240, 36)
		btn.pressed.connect(_on_choice.bind(i))
		_btn_container.add_child(btn)
	visible = true

func _on_choice(idx: int) -> void:
	visible = false
	selected.emit(idx)

func _on_cancelled() -> void:
	visible = false
	cancelled.emit()
