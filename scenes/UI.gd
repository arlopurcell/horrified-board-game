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
@onready var _perk_panel: PerkCardsPanel = $PerkCardsPanel

const ItemSelectionPanelScene := preload("res://scenes/ItemSelectionPanel.gd")
const SpecialActionPanelScene := preload("res://scenes/SpecialActionPanel.gd")

var _item_panel: ItemSelectionPanel
var _special_panel: SpecialActionPanel
var _pending_action: String = ""
var _special_targets: Array = []
var _professor_target_player: int = -1
var _pending_perk_card: PerkCardData = null
var _perk_step: String = ""
var _perk_data: Dictionary = {}

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
	_perk_panel.card_clicked.connect(_on_perk_card_clicked)

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
	if _perk_step != "":
		_on_perk_step_selected(choice_idx)
		return
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
	if _perk_step != "":
		_pending_perk_card = null
		_perk_step = ""
		_perk_data = {}
		return
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
	elif _pending_action == "perk_delivery":
		_perk_data["items"] = selected_items
		var giver_idx: int = _perk_data["giver"]
		var receivers: Array[int] = []
		var labels: Array[String] = []
		for i in range(GameManager.players.size()):
			if i != giver_idx:
				receivers.append(i)
				labels.append(GameManager.players[i].display_name)
		_perk_data["targets"] = receivers
		_perk_step = "delivery_receiver"
		_special_panel.open("Give items to which Hero?", labels)
		_pending_action = ""
		return
	_pending_action = ""
	_refresh_action_buttons()

func _on_item_panel_cancelled() -> void:
	if _pending_action == "perk_delivery":
		_pending_perk_card = null
		_perk_step = ""
		_perk_data = {}
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


# ---- Perk card handling ----

func _on_perk_card_clicked(card: PerkCardData) -> void:
	if GameManager.phase_running:
		return
	_pending_perk_card = card
	match card.title:
		"Late into the Night":
			GameManager.moves_remaining += 2
			_perk_finish()
		"Overstock":
			GameManager.draw_items_to_board(GameManager.players.size())
			_perk_finish()
		"Break of Dawn":
			GameManager.draw_items_to_board(2)
			MonsterManager.skip_next_phase = true
			_perk_finish()
		"Show of Force":
			_perk_start_place_or_move("Creature")
		"Hunter Becomes Prey":
			_perk_start_place_or_move("Wolfman")
		"Brandish Crucifix":
			_perk_start_place_or_move("Dracula")
		"Power of the Ancients":
			_perk_start_place_or_move("Mummy")
		"Visit from the Detective":
			_perk_start_place_or_move("Invisible Man")
		"Mob Justice":
			_perk_start_mob_justice()
		"Taxi Ride":
			_perk_start_taxi()
		"Rush":
			_perk_start_rush()
		"Repel":
			_perk_start_repel()
		"Hurry":
			_perk_start_hurry()
		"Special Delivery":
			_perk_start_special_delivery()
		"Conduct an Investigation":
			_perk_start_conduct()
		_:
			_perk_finish()


func _perk_finish() -> void:
	GameManager.play_perk_card(_pending_perk_card)
	_pending_perk_card = null
	_perk_step = ""
	_perk_data = {}
	_refresh_action_buttons()


func _on_perk_step_selected(choice_idx: int) -> void:
	match _perk_step:
		"place_or_move", "mob_justice":
			var action: String = (_perk_data["actions"] as Array)[choice_idx]
			match action:
				"place":   _perk_start_place_monster(_perk_data["specific_monster"])
				"frank":   _perk_start_place_monster("Frankenstein")
				"bride":   _perk_start_place_monster("Bride")
				"move":    _perk_start_move_any_monster()

		"place_monster":
			var space_id: int = (_perk_data["targets"] as Array)[choice_idx]
			for m in MonsterManager.monsters:
				if m.monster_name == (_perk_data["specific_monster"] as String):
					m.current_space_id = space_id
					MonsterManager.monster_relocated.emit()
					break
			_perk_finish()

		"move_any_monster":
			var monster_idx: int = (_perk_data["targets"] as Array)[choice_idx]
			_perk_data["monster_idx"] = monster_idx
			var monster := MonsterManager.monsters[monster_idx]
			var reachable := GameManager.get_spaces_reachable(monster.current_space_id, 3)
			_perk_data["targets"] = reachable
			var labels: Array[String] = []
			for sid: int in reachable:
				labels.append(_space_name_label(sid))
			_perk_step = "move_any_monster_space"
			_special_panel.open("Move " + monster.monster_name + " to:", labels)

		"move_any_monster_space":
			var dest: int = (_perk_data["targets"] as Array)[choice_idx]
			MonsterManager.monsters[_perk_data["monster_idx"] as int].current_space_id = dest
			MonsterManager.monster_relocated.emit()
			_perk_finish()

		"taxi_player":
			_perk_data["player_idx"] = (_perk_data["targets"] as Array)[choice_idx]
			_perk_start_taxi_pick_space()

		"taxi_space":
			GameManager.teleport_player(_perk_data["player_idx"] as int,
					(_perk_data["targets"] as Array)[choice_idx])
			_perk_finish()

		"rush_player":
			_perk_data["player_idx"] = (_perk_data["targets"] as Array)[choice_idx]
			_perk_start_rush_pick_space()

		"rush_space":
			GameManager.teleport_player(_perk_data["player_idx"] as int,
					(_perk_data["targets"] as Array)[choice_idx])
			_perk_finish()

		"repel_queue":
			var dest: int = (_perk_data["targets"] as Array)[choice_idx]
			if dest != -1:
				var monster_idx: int = (_perk_data["queue"] as Array)[0]
				MonsterManager.monsters[monster_idx].current_space_id = dest
				MonsterManager.monster_relocated.emit()
			(_perk_data["queue"] as Array).pop_front()
			_perk_advance_repel_queue()

		"hurry_queue":
			var dest: int = (_perk_data["targets"] as Array)[choice_idx]
			if dest != -1:
				var player_idx: int = (_perk_data["queue"] as Array)[0]
				GameManager.teleport_player(player_idx, dest)
			(_perk_data["queue"] as Array).pop_front()
			_perk_advance_hurry_queue()

		"delivery_giver":
			var giver_idx: int = (_perk_data["targets"] as Array)[choice_idx]
			_perk_data["giver"] = giver_idx
			var items: Array[ItemData] = []
			for item in GameManager.players[giver_idx].inventory:
				items.append(item as ItemData)
			_pending_action = "perk_delivery"
			_item_panel.open(items, 0)

		"delivery_receiver":
			var receiver_idx: int = (_perk_data["targets"] as Array)[choice_idx]
			var giver := GameManager.players[_perk_data["giver"] as int]
			var receiver := GameManager.players[receiver_idx]
			for item in (_perk_data["items"] as Array):
				giver.inventory.erase(item)
				receiver.inventory.append(item)
			_perk_finish()

		"conduct_space":
			var target_space: int = (_perk_data["targets"] as Array)[choice_idx]
			_perk_data["target_space"] = target_space
			var queue: Array[int] = []
			for i in range(GameManager.players.size()):
				if GameManager.players[i].current_space_id != target_space:
					queue.append(i)
			_perk_data["queue"] = queue
			_perk_advance_conduct_queue()

		"conduct_queue":
			if choice_idx == 0:  # Yes
				var player_idx: int = (_perk_data["queue"] as Array)[0]
				GameManager.teleport_player(player_idx, _perk_data["target_space"] as int)
			(_perk_data["queue"] as Array).pop_front()
			_perk_advance_conduct_queue()


func _perk_start_place_or_move(monster_name: String) -> void:
	_perk_data["specific_monster"] = monster_name
	var choices: Array[String] = []
	var actions: Array[String] = []
	var in_game := false
	for m in MonsterManager.monsters:
		if m.monster_name == monster_name:
			in_game = true
			break
	if in_game:
		choices.append("Place " + monster_name + " in a space")
		actions.append("place")
	if not MonsterManager.monsters.is_empty():
		choices.append("Move any Monster 3 spaces")
		actions.append("move")
	_perk_data["actions"] = actions
	if actions.is_empty():
		_perk_finish()
		return
	if actions.size() == 1:
		_perk_step = "place_or_move"
		_on_perk_step_selected(0)
		return
	_perk_step = "place_or_move"
	_special_panel.open("Choose action:", choices)


func _perk_start_mob_justice() -> void:
	var choices: Array[String] = []
	var actions: Array[String] = []
	for m in MonsterManager.monsters:
		if m.monster_name == "Frankenstein" and not actions.has("frank"):
			choices.append("Place Frankenstein in a space")
			actions.append("frank")
		if m.monster_name == "Bride" and not actions.has("bride"):
			choices.append("Place Bride in a space")
			actions.append("bride")
	if not MonsterManager.monsters.is_empty():
		choices.append("Move any Monster 3 spaces")
		actions.append("move")
	_perk_data["actions"] = actions
	if actions.is_empty():
		_perk_finish()
		return
	if actions.size() == 1:
		_perk_step = "mob_justice"
		_on_perk_step_selected(0)
		return
	_perk_step = "mob_justice"
	_special_panel.open("Choose action:", choices)


func _perk_start_place_monster(monster_name: String) -> void:
	_perk_data["specific_monster"] = monster_name
	var targets: Array[int] = []
	var labels: Array[String] = []
	for space in GameManager.board_data.spaces:
		targets.append(space.id)
		labels.append(space.name)
	_perk_data["targets"] = targets
	_perk_step = "place_monster"
	_special_panel.open("Place " + monster_name + " in:", labels)


func _perk_start_move_any_monster() -> void:
	var targets: Array[int] = []
	var labels: Array[String] = []
	for i in range(MonsterManager.monsters.size()):
		targets.append(i)
		labels.append(MonsterManager.monsters[i].monster_name)
	_perk_data["targets"] = targets
	_perk_step = "move_any_monster"
	_special_panel.open("Move which Monster?", labels)


func _perk_start_taxi() -> void:
	if GameManager.players.size() == 1:
		_perk_data["player_idx"] = 0
		_perk_start_taxi_pick_space()
		return
	var targets: Array[int] = []
	var labels: Array[String] = []
	for i in range(GameManager.players.size()):
		targets.append(i)
		labels.append(GameManager.players[i].display_name)
	_perk_data["targets"] = targets
	_perk_step = "taxi_player"
	_special_panel.open("Move which Hero?", labels)


func _perk_start_taxi_pick_space() -> void:
	var targets: Array[int] = []
	var labels: Array[String] = []
	for space in GameManager.board_data.spaces:
		targets.append(space.id)
		labels.append(space.name)
	_perk_data["targets"] = targets
	_perk_step = "taxi_space"
	_special_panel.open("Place Hero in which space?", labels)


func _perk_start_rush() -> void:
	if GameManager.players.size() == 1:
		_perk_data["player_idx"] = 0
		_perk_start_rush_pick_space()
		return
	var targets: Array[int] = []
	var labels: Array[String] = []
	for i in range(GameManager.players.size()):
		targets.append(i)
		labels.append(GameManager.players[i].display_name)
	_perk_data["targets"] = targets
	_perk_step = "rush_player"
	_special_panel.open("Move which Hero?", labels)


func _perk_start_rush_pick_space() -> void:
	var player_idx: int = _perk_data["player_idx"]
	var from_id := GameManager.players[player_idx].current_space_id
	var reachable := GameManager.get_spaces_reachable(from_id, 4)
	_perk_data["targets"] = reachable
	var labels: Array[String] = []
	for sid: int in reachable:
		labels.append(_space_name_label(sid))
	_perk_step = "rush_space"
	_special_panel.open("Move " + GameManager.players[player_idx].display_name + " to:", labels)


func _perk_start_repel() -> void:
	var queue: Array[int] = []
	for i in range(MonsterManager.monsters.size()):
		queue.append(i)
	_perk_data["queue"] = queue
	_perk_advance_repel_queue()


func _perk_advance_repel_queue() -> void:
	var queue: Array = _perk_data["queue"]
	if queue.is_empty():
		_perk_finish()
		return
	var monster_idx: int = queue[0]
	var monster := MonsterManager.monsters[monster_idx]
	var reachable := GameManager.get_spaces_reachable(monster.current_space_id, 2)
	_perk_data["targets"] = ([-1] as Array[int]) + reachable
	var labels: Array[String] = ["Stay (don't move)"]
	for sid: int in reachable:
		labels.append(_space_name_label(sid))
	_perk_step = "repel_queue"
	_special_panel.open("Move " + monster.monster_name + " (up to 2 spaces):", labels)


func _perk_start_hurry() -> void:
	var queue: Array[int] = []
	for i in range(GameManager.players.size()):
		queue.append(i)
	_perk_data["queue"] = queue
	_perk_advance_hurry_queue()


func _perk_advance_hurry_queue() -> void:
	var queue: Array = _perk_data["queue"]
	if queue.is_empty():
		_perk_finish()
		return
	var player_idx: int = queue[0]
	var player := GameManager.players[player_idx]
	var reachable := GameManager.get_spaces_reachable(player.current_space_id, 2)
	_perk_data["targets"] = ([-1] as Array[int]) + reachable
	var labels: Array[String] = ["Stay (don't move)"]
	for sid: int in reachable:
		labels.append(_space_name_label(sid))
	_perk_step = "hurry_queue"
	_special_panel.open("Move " + player.display_name + " (up to 2 spaces):", labels)


func _perk_start_special_delivery() -> void:
	var targets: Array[int] = []
	var labels: Array[String] = []
	for i in range(GameManager.players.size()):
		if not GameManager.players[i].inventory.is_empty():
			targets.append(i)
			labels.append(GameManager.players[i].display_name)
	if targets.is_empty():
		_perk_finish()
		return
	_perk_data["targets"] = targets
	_perk_step = "delivery_giver"
	_special_panel.open("Who gives items?", labels)


func _perk_start_conduct() -> void:
	var space_set: Dictionary = {}
	for p in GameManager.players:
		space_set[p.current_space_id] = true
	var targets: Array[int] = []
	var labels: Array[String] = []
	for sid in space_set:
		targets.append(sid as int)
		labels.append(_space_name_label(sid as int))
	_perk_data["targets"] = targets
	_perk_step = "conduct_space"
	_special_panel.open("Gather Heroes at which space?", labels)


func _perk_advance_conduct_queue() -> void:
	var queue: Array = _perk_data["queue"]
	if queue.is_empty():
		_perk_finish()
		return
	var player_idx: int = queue[0]
	var target_name := _space_name_label(_perk_data["target_space"] as int)
	var player_name := GameManager.players[player_idx].display_name
	_perk_step = "conduct_queue"
	_special_panel.open("Move " + player_name + " to " + target_name + "?", ["Yes", "No"])


func _space_name_label(space_id: int) -> String:
	var space := GameManager.board_data.get_space(space_id)
	return space.name if space != null else str(space_id)
