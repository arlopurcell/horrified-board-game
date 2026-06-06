extends CanvasLayer

@onready var turn_banner: Label = $TurnBanner
@onready var player_roster: HBoxContainer = $PlayerRoster
@onready var end_turn_button: Button = $EndTurnButton
@onready var moves_indicator: Label = $MovesIndicator
@onready var inventory_list: RichTextLabel = $InventoryPanel/InventoryScroll/InventoryList
@onready var pickup_button: Button = $PickupButton

const COLOR_HEX := {"red": "#c0392b", "blue": "#2980b9", "yellow": "#d4ac0d"}

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pickup_button.pressed.connect(_on_pickup_pressed)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.items_changed.connect(_on_items_changed)

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

func _on_pickup_pressed() -> void:
	GameManager.try_pickup()

func _on_turn_changed(_player_index: int) -> void:
	_refresh_turn_display()

func _on_player_moved(_player_index: int, _space_id: int) -> void:
	_update_moves_indicator()
	_refresh_pickup_button()

func _on_items_changed() -> void:
	_refresh_inventory()
	_refresh_pickup_button()

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
	_update_moves_indicator()
	_refresh_inventory()
	_refresh_pickup_button()

func _update_moves_indicator() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var remaining := GameManager.moves_remaining
	var total := GameManager.MOVES_PER_TURN
	var parts: Array[String] = []
	for i in range(total):
		parts.append("●" if i < remaining else "○")
	moves_indicator.text = " ".join(parts)
	moves_indicator.add_theme_color_override("font_color", active.color)

func _refresh_inventory() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		inventory_list.text = ""
		return
	var bbcode := ""
	for item in active.inventory:
		var item_data := item as ItemData
		if item_data == null:
			continue
		var hex: String = COLOR_HEX.get(item_data.color, "#ffffff")
		if bbcode != "":
			bbcode += "\n"
		bbcode += "[color=%s]● %s  %d[/color]" % [hex, item_data.item_name, item_data.strength]
	inventory_list.text = bbcode

func _refresh_pickup_button() -> void:
	pickup_button.disabled = not GameManager.can_pickup()
