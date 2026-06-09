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
@onready var special_button: Button = $SpecialButton
@onready var game_won_label: Label = $GameWonLabel

const ItemSelectionPanelScene := preload("res://scenes/ItemSelectionPanel.gd")
const SpecialActionPanelScene := preload("res://scenes/SpecialActionPanel.gd")

var _item_panel: ItemSelectionPanel
var _special_panel: SpecialActionPanel
var _pending_action: String = ""
var _special_targets: Array = []
var _professor_target_player: int = -1

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pickup_button.pressed.connect(_on_pickup_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	defeat_button.pressed.connect(_on_defeat_pressed)
	special_button.pressed.connect(_on_special_pressed)
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
	_special_panel = SpecialActionPanelScene.new()
	add_child(_special_panel)
	_special_panel.selected.connect(_on_special_selected)
	_special_panel.cancelled.connect(_on_special_cancelled)

func setup(player_list: Array[PlayerData]) -> void:
	for child in player_roster.get_children():
		child.queue_free()
	for i in range(player_list.size()):
		var lbl := Label.new()
		lbl.text = player_list[i].display_name
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
	_refresh_action_buttons()

func _on_advance_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var red_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "red":
			red_items.append(item as ItemData)
	_pending_action = "advance"
	_item_panel.open(red_items, GameManager.get_item_strength_boost())

func _on_defeat_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var yellow_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "yellow":
			yellow_items.append(item as ItemData)
	_pending_action = "defeat"
	_item_panel.open(yellow_items, GameManager.get_item_strength_boost())

func _on_special_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null or active.character == null:
		return
	match active.character.special_id:
		"archaeologist":
			_special_targets = GameManager.get_archaeologist_targets()
			_special_panel.open("Pick Up From:", _space_ids_to_labels(_special_targets))
			_pending_action = "archaeologist"
		"professor":
			_special_targets = GameManager.get_other_player_indices()
			_special_panel.open("Move Which Player?", _player_indices_to_labels(_special_targets))
			_pending_action = "professor_step1"

func _on_special_selected(choice_idx: int) -> void:
	match _pending_action:
		"archaeologist":
			GameManager.try_archaeologist(_special_targets[choice_idx] as int)
		"professor_step1":
			_professor_target_player = _special_targets[choice_idx] as int
			_special_targets = GameManager.get_professor_targets_for_player(_professor_target_player)
			_special_panel.open("Move to Where?", _space_ids_to_labels(_special_targets))
			_pending_action = "professor_step2"
			return
		"professor_step2":
			GameManager.try_professor(_professor_target_player, _special_targets[choice_idx] as int)
	_pending_action = ""
	_special_targets = []
	_refresh_action_buttons()

func _on_special_cancelled() -> void:
	_pending_action = ""
	_special_targets = []

func _space_ids_to_labels(space_ids: Array) -> Array:
	var result: Array = []
	for sid in space_ids:
		var space := GameManager.board_data.get_space(sid as int)
		result.append(space.name if space != null else str(sid))
	return result

func _player_indices_to_labels(indices: Array) -> Array:
	var result: Array = []
	for i in indices:
		result.append(GameManager.players[i as int].display_name)
	return result

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
	_update_moves_indicator()
	advance_button.visible = GameManager.can_advance()
	defeat_button.visible = GameManager.can_defeat()
	var active := GameManager.get_active_player()
	if active != null and active.character != null:
		match active.character.special_id:
			"archaeologist": special_button.text = "PICKUP NEARBY"
			"professor":     special_button.text = "MOVE PLAYER"
			_:               special_button.text = "SPECIAL ACTION"
	special_button.visible = GameManager.can_use_special()

func _refresh_turn_display() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	turn_banner.text = active.display_name + "'s Turn"
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
	var total := active.character.actions_per_turn if active.character != null else GameManager.MOVES_PER_TURN
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
