extends Control

const AVAILABLE_MONSTERS: Dictionary = {
    "Dracula": "res://resources/data/dracula.tres",
    "Wolfman": "res://resources/data/wolfman.tres",
    "Mummy": "res://resources/data/mummy.tres",
    "Frankenstein": ["res://resources/data/frankenstein.tres", "res://resources/data/bride.tres"],
    "Creature": "res://resources/data/creature.tres",
}

var _selected_player_count := 0
var _selected_monsters: Dictionary = {}
var _start_button: Button
var _config_overlay: Control

func _ready() -> void:
    set_anchors_and_offsets_preset(PRESET_FULL_RECT)

    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    bg.color = Color(0.07, 0.05, 0.04)
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    add_child(center)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "HORRIFIED"
    title.add_theme_font_size_override("font_size", 72)
    title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.15))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 30)
    vbox.add_child(gap)

    var new_game_btn := _make_menu_button("NEW GAME")
    new_game_btn.pressed.connect(_show_config)
    vbox.add_child(new_game_btn)

    var exit_btn := _make_menu_button("EXIT")
    exit_btn.pressed.connect(func(): get_tree().quit())
    vbox.add_child(exit_btn)

    _config_overlay = _build_config_overlay()
    _config_overlay.visible = false
    add_child(_config_overlay)

func _make_menu_button(label: String) -> Button:
    var btn := Button.new()
    btn.text = label
    btn.custom_minimum_size = Vector2(220, 52)
    btn.add_theme_font_size_override("font_size", 20)
    return btn

func _build_config_overlay() -> Control:
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    dim.color = Color(0.0, 0.0, 0.0, 0.6)
    overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(380, 0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.10, 0.07, 0.05, 1.0)
    panel_style.set_border_width_all(2)
    panel_style.border_color = Color(0.50, 0.40, 0.15)
    panel.add_theme_stylebox_override("panel", panel_style)
    center.add_child(panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 24)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    margin.add_child(vbox)

    var title := Label.new()
    title.text = "New Game"
    title.add_theme_font_size_override("font_size", 24)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    vbox.add_child(HSeparator.new())

    var players_label := Label.new()
    players_label.text = "Number of Players"
    players_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(players_label)

    var players_hbox := HBoxContainer.new()
    players_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(players_hbox)

    var btn_group := ButtonGroup.new()
    for i in range(1, 6):
        var btn := Button.new()
        btn.text = str(i)
        btn.toggle_mode = true
        btn.button_group = btn_group
        btn.custom_minimum_size = Vector2(48, 44)
        btn.add_theme_font_size_override("font_size", 18)
        btn.pressed.connect(_on_player_count_selected.bind(i))
        players_hbox.add_child(btn)

    var monsters_label := Label.new()
    monsters_label.text = "Monsters"
    monsters_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(monsters_label)

    for monster_name in AVAILABLE_MONSTERS:
        _selected_monsters[monster_name] = false
        var cb := CheckBox.new()
        cb.text = monster_name
        cb.add_theme_font_size_override("font_size", 14)
        cb.toggled.connect(_on_monster_toggled.bind(monster_name))
        vbox.add_child(cb)

    vbox.add_child(HSeparator.new())

    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 12)
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(btn_row)

    var back_btn := Button.new()
    back_btn.text = "Back"
    back_btn.custom_minimum_size = Vector2(100, 40)
    back_btn.add_theme_font_size_override("font_size", 14)
    back_btn.pressed.connect(_hide_config)
    btn_row.add_child(back_btn)

    _start_button = Button.new()
    _start_button.text = "Start Game"
    _start_button.custom_minimum_size = Vector2(140, 40)
    _start_button.add_theme_font_size_override("font_size", 14)
    _start_button.disabled = true
    _start_button.pressed.connect(_start_game)
    btn_row.add_child(_start_button)

    return overlay

func _show_config() -> void:
    _config_overlay.visible = true

func _hide_config() -> void:
    _config_overlay.visible = false

func _on_player_count_selected(count: int) -> void:
    _selected_player_count = count
    _update_start_button()

func _on_monster_toggled(toggled: bool, monster_name: String) -> void:
    _selected_monsters[monster_name] = toggled
    _update_start_button()

func _update_start_button() -> void:
    var any_monster := false
    for name in _selected_monsters:
        if _selected_monsters[name]:
            any_monster = true
            break
    _start_button.disabled = _selected_player_count == 0 or not any_monster

func _start_game() -> void:
    GameManager.pending_player_count = _selected_player_count
    GameManager.pending_monster_paths.clear()
    for name in _selected_monsters:
        if _selected_monsters[name]:
            var entry = AVAILABLE_MONSTERS[name]
            if entry is Array:
                for path in entry:
                    GameManager.pending_monster_paths.append(path)
            else:
                GameManager.pending_monster_paths.append(entry)
    get_tree().change_scene_to_file("res://scenes/Main.tscn")
