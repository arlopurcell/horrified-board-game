extends CanvasLayer

@onready var turn_banner: Label = $TurnBanner
@onready var player_roster: HBoxContainer = $PlayerRoster
@onready var end_turn_button: Button = $EndTurnButton

func _ready() -> void:
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    GameManager.turn_changed.connect(_on_turn_changed)

func setup(player_list: Array[PlayerData]) -> void:
    for child in player_roster.get_children():
        child.queue_free()
    for i in range(player_list.size()):
        var lbl := Label.new()
        lbl.text = player_list[i].player_name
        lbl.add_theme_color_override("font_color", player_list[i].color)
        lbl.add_theme_font_size_override("font_size", 14)
        lbl.name = "Player" + str(i)
        player_roster.add_child(lbl)
    _refresh_turn_display()

func _on_end_turn_pressed() -> void:
    GameManager.end_turn()

func _on_turn_changed(_player_index: int) -> void:
    _refresh_turn_display()

func _refresh_turn_display() -> void:
    var active := GameManager.get_active_player()
    if active == null:
        return
    turn_banner.text = active.player_name + "'s Turn"
    turn_banner.add_theme_color_override("font_color", active.color)
    for i in range(player_roster.get_child_count()):
        var lbl := player_roster.get_child(i) as Label
        if lbl == null:
            continue
        var is_active := (i == GameManager.active_player_index)
        lbl.add_theme_font_size_override("font_size", 18 if is_active else 13)
