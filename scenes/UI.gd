extends CanvasLayer

@onready var turn_banner: Label = $TurnBanner
@onready var player_roster: HBoxContainer = $PlayerRoster
@onready var end_turn_button: Button = $EndTurnButton
@onready var moves_indicator: Label = $MovesIndicator
@onready var monster_log: Label = $MonsterLog
@onready var inventory_list: RichTextLabel = $InventoryPanel/InventoryList
@onready var pickup_button: Button = $PickupButton
@onready var advance_button: Button = $AdvanceButton
@onready var defeat_button: Button = $DefeatButton
@onready var game_won_label: Label = $GameWonLabel

const ItemSelectionPanelScene := preload("res://scenes/ItemSelectionPanel.gd")

var _item_panel: ItemSelectionPanel
var _pending_action: String = ""

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pickup_button.pressed.connect(_on_pickup_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	defeat_button.pressed.connect(_on_defeat_pressed)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.items_changed.connect(_on_items_changed)
	GameManager.monster_defeated.connect(_on_monster_defeated)
	GameManager.game_won.connect(_on_game_won)
	MonsterManager.phase_completed.connect(_on_phase_completed)
	_item_panel = ItemSelectionPanelScene.new()
	add_child(_item_panel)
	_item_panel.confirmed.connect(_on_item_panel_confirmed)
	_item_panel.cancelled.connect(_on_item_panel_cancelled)

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
	end_turn_button.disabled = true
	pickup_button.disabled = true
	GameManager.end_turn()
	_refresh_action_buttons()

func _on_pickup_pressed() -> void:
	GameManager.try_pickup()

func _on_advance_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var red_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "red":
			red_items.append(item as ItemData)
	_pending_action = "advance"
	_item_panel.open(red_items)

func _on_defeat_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var yellow_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "yellow":
			yellow_items.append(item as ItemData)
	_pending_action = "defeat"
	_item_panel.open(yellow_items)

func _on_item_panel_confirmed(selected_items: Array[ItemData]) -> void:
	if _pending_action == "advance":
		GameManager.try_advance(selected_items)
	elif _pending_action == "defeat":
		GameManager.try_defeat(selected_items)
	_pending_action = ""
	_refresh_action_buttons()

func _on_item_panel_cancelled() -> void:
	_pending_action = ""

func _on_turn_changed(_player_index: int) -> void:
	end_turn_button.disabled = false
	_refresh_turn_display()

func _on_player_moved(_player_index: int, _space_id: int) -> void:
	_update_moves_indicator()
	_refresh_pickup_button()
	_refresh_action_buttons()

func _on_items_changed() -> void:
	_refresh_inventory()
	_refresh_pickup_button()
	_refresh_action_buttons()

func _on_phase_completed(summary: String) -> void:
	monster_log.text = summary

func _on_monster_defeated(_monster_name: String) -> void:
	_refresh_action_buttons()

func _on_game_won() -> void:
	game_won_label.visible = true

func _refresh_action_buttons() -> void:
	advance_button.visible = GameManager.can_advance()
	defeat_button.visible = GameManager.can_defeat()

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
	_refresh_action_buttons()

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
	inventory_list.clear()
	if active == null:
		return
	for item in active.inventory:
		var item_data := item as ItemData
		if item_data == null:
			continue
		var color: Color
		match item_data.color:
			"red":    color = Color(0.75, 0.22, 0.17)
			"blue":   color = Color(0.16, 0.50, 0.73)
			"yellow": color = Color(0.95, 0.77, 0.06)
			_:        color = Color.WHITE
		inventory_list.push_color(color)
		inventory_list.add_text("● %s  %d\n" % [item_data.item_name, item_data.strength])
		inventory_list.pop()

func _refresh_pickup_button() -> void:
	pickup_button.disabled = not GameManager.can_pickup()
