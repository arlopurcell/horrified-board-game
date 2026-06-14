extends CanvasLayer

@onready var turn_banner: Label = $TurnBanner
@onready var player_roster: HBoxContainer = $PlayerRoster
@onready var end_turn_button: Button = $EndTurnButton
@onready var moves_indicator: Label = $MovesIndicator
@onready var monster_log: Label = $MonsterLog
@onready var inventory_list: RichTextLabel = $InventoryPanel/InventoryList
@onready var pickup_button: Button = $PickupButton
@onready var advance_button: Button = $ActionButtons/AdvanceButton
@onready var defeat_button: Button = $ActionButtons/DefeatButton
@onready var special_button: Button = $SpecialButton
@onready var game_won_label: Label = $GameWonLabel
@onready var game_lost_label: Label = $GameLostLabel
@onready var main_menu_button: Button = $MainMenuButton
@onready var move_villager_button: Button = $ActionButtons/MoveVillagerButton
@onready var cure_button: Button = $ActionButtons/CureButton
@onready var defeat_wolfman_button: Button = $ActionButtons/DefeatWolfmanButton
@onready var advance_mummy_button: Button = $ActionButtons/AdvanceMummyButton
@onready var defeat_mummy_button: Button = $ActionButtons/DefeatMummyButton
@onready var advance_frankenstein_button: Button = $ActionButtons/AdvanceFrankensteinButton
@onready var advance_bride_button: Button = $ActionButtons/AdvanceBrideButton
@onready var advance_creature_button: Button = $ActionButtons/AdvanceCreatureButton
@onready var defeat_creature_button: Button = $ActionButtons/DefeatCreatureButton
@onready var trade_button: Button = $ActionButtons/TradeButton
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
var _hit_space_id: int = -1
var _hit_remaining: int = 0
var _hit_target_player: int = -1
var _hit_target_villager: VillagerData = null
var _bring_along_queue: Array = []
var _bring_along_destination: int = -1
var _mv_villager: VillagerData = null
var _trade_partner_index: int = -1
var _trade_give_items: Array[ItemData] = []

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pickup_button.pressed.connect(_on_pickup_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	defeat_button.pressed.connect(_on_defeat_pressed)
	special_button.pressed.connect(_on_special_pressed)
	move_villager_button.pressed.connect(_on_move_villager_pressed)
	cure_button.pressed.connect(_on_cure_pressed)
	defeat_wolfman_button.pressed.connect(_on_defeat_wolfman_pressed)
	advance_mummy_button.pressed.connect(_on_advance_mummy_pressed)
	defeat_mummy_button.pressed.connect(_on_defeat_mummy_pressed)
	advance_frankenstein_button.pressed.connect(_on_advance_frankenstein_pressed)
	advance_bride_button.pressed.connect(_on_advance_bride_pressed)
	advance_creature_button.pressed.connect(_on_advance_creature_pressed)
	defeat_creature_button.pressed.connect(_on_defeat_creature_pressed)
	trade_button.pressed.connect(_on_trade_pressed)
	GameManager.frankenstein_changed.connect(_on_frankenstein_changed)
	GameManager.creature_changed.connect(_on_creature_changed)
	GameManager.wolfman_cure_complete.connect(_on_wolfman_cure_complete)
	GameManager.wolfman_hunted_changed.connect(func(_i: int): _refresh_inventory())
	GameManager.mummy_changed.connect(_on_mummy_changed)
	GameManager.mummy_soul_changed.connect(func(_i: int): _refresh_inventory())
	VillagerManager.villager_rescued.connect(_on_villager_rescued)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.items_changed.connect(_on_items_changed)
	GameManager.monster_defeated.connect(_on_monster_defeated)
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	MonsterManager.space_attacked.connect(_on_space_attacked)
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
	if _pending_action == "bring_along":
		if choice_idx == 0:
			VillagerManager.move_villager(_bring_along_queue[0] as VillagerData, _bring_along_destination)
		_bring_along_queue.pop_front()
		_pending_action = ""
		_process_bring_along_queue()
		return
	if _pending_action == "trade_partner":
		_trade_partner_index = _special_targets[choice_idx] as int
		_special_targets = []
		_pending_action = ""
		_start_trade_give()
		return
	if _pending_action == "mv_who":
		_mv_villager = _special_targets[choice_idx] as VillagerData
		_special_targets = []
		_pending_action = ""
		var active_space := GameManager.players[GameManager.active_player_index].current_space_id
		if _mv_villager.current_space_id == active_space:
			var space := GameManager.board_data.get_space(active_space)
			var adj: Array = []
			var labels: Array[String] = []
			if space != null:
				for n: int in space.neighbors:
					adj.append(n)
					labels.append(_space_name_label(n))
			_special_targets = adj
			_pending_action = "mv_where"
			_special_panel.open("Push " + _mv_villager.villager_name + " to:", labels)
		else:
			GameManager.try_move_villager(_mv_villager, active_space)
			_mv_villager = null
			_refresh_action_buttons()
		return
	if _pending_action == "mv_where":
		GameManager.try_move_villager(_mv_villager, _special_targets[choice_idx] as int)
		_mv_villager = null
		_special_targets = []
		_pending_action = ""
		_refresh_action_buttons()
		return
	if _pending_action == "hit_who":
		var target = _special_targets[choice_idx]
		_special_targets = []
		_pending_action = ""
		if target is int:
			_hit_target_player = target as int
			_hit_target_villager = null
			_show_hit_block_choice()
		else:
			_hit_target_villager = target as VillagerData
			_hit_target_player = -1
			_apply_villager_hit()
		return
	if _pending_action == "hit_choice":
		if choice_idx == 0:
			var player := GameManager.players[_hit_target_player]
			var items: Array[ItemData] = []
			for item in player.inventory:
				if (item as ItemData).item_name != "The Cure":
					items.append(item as ItemData)
			_pending_action = "hit_item"
			_item_panel.open(items, 0, 0)
		else:
			_apply_hit_death()
		return
	if _pending_action == "move_frankenstein":
		var dest: int = _special_targets[choice_idx] as int
		_special_targets = []
		_pending_action = ""
		GameManager.move_frankenstein(dest)
		_refresh_action_buttons()
		return
	if _pending_action == "move_bride":
		var dest: int = _special_targets[choice_idx] as int
		_special_targets = []
		_pending_action = ""
		GameManager.move_bride(dest)
		_refresh_action_buttons()
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
	if _pending_action == "bring_along":
		_bring_along_queue.pop_front()
		_pending_action = ""
		_process_bring_along_queue()
		return
	if _pending_action == "trade_partner":
		_trade_partner_index = -1
		_special_targets = []
		_pending_action = ""
		return
	if _pending_action == "mv_who" or _pending_action == "mv_where":
		_mv_villager = null
		_special_targets = []
		_pending_action = ""
		return
	if _pending_action == "hit_who":
		var target = _special_targets[0]
		_special_targets = []
		_pending_action = ""
		if target is int:
			_hit_target_player = target as int
			_hit_target_villager = null
			_show_hit_block_choice()
		else:
			_hit_target_villager = target as VillagerData
			_hit_target_player = -1
			_apply_villager_hit()
		return
	if _pending_action == "hit_choice":
		_apply_hit_death()
		return
	if _pending_action == "move_frankenstein":
		_special_targets = []
		_pending_action = ""
		GameManager.move_frankenstein(-1)
		_refresh_action_buttons()
		return
	if _pending_action == "move_bride":
		_special_targets = []
		_pending_action = ""
		GameManager.move_bride(-1)
		_refresh_action_buttons()
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
	if _pending_action == "hit_item":
		var player := GameManager.players[_hit_target_player]
		for item in selected_items:
			player.inventory.erase(item)
		GameManager.items_changed.emit()
		_hit_remaining -= 1
		_hit_target_player = -1
		_pending_action = ""
		_process_next_space_hit()
		return
	if _pending_action == "contribute_cure":
		GameManager.try_contribute_cure(selected_items)
	elif _pending_action == "defeat_wolfman":
		GameManager.try_defeat_wolfman(selected_items)
	elif _pending_action == "advance_mummy":
		if not selected_items.is_empty():
			GameManager.try_advance_mummy(selected_items[0])
	elif _pending_action == "defeat_mummy":
		GameManager.try_defeat_mummy(selected_items)
	elif _pending_action == "advance_frankenstein":
		if not selected_items.is_empty() and GameManager.try_advance_frankenstein(selected_items[0]):
			var destinations := GameManager.get_frankenstein_destinations()
			var labels: Array[String] = ["Stay (don't move)"]
			for sid in destinations.slice(1):
				labels.append(_space_name_label(sid as int))
			_special_targets = destinations
			_pending_action = "move_frankenstein"
			_special_panel.open("Move Frankenstein (up to %d spaces):" % GameManager.frank_pending_strength, labels)
			return
	elif _pending_action == "advance_bride":
		if not selected_items.is_empty() and GameManager.try_advance_bride(selected_items[0]):
			var destinations := GameManager.get_bride_destinations()
			var labels: Array[String] = ["Stay (don't move)"]
			for sid in destinations.slice(1):
				labels.append(_space_name_label(sid as int))
			_special_targets = destinations
			_pending_action = "move_bride"
			_special_panel.open("Move the Bride (up to %d spaces):" % GameManager.bride_pending_strength, labels)
			return
	elif _pending_action == "advance_creature":
		if not selected_items.is_empty():
			GameManager.try_advance_creature(selected_items[0])
	elif _pending_action == "defeat_creature":
		GameManager.try_defeat_creature(selected_items)
	elif _pending_action == "trade_give":
		_trade_give_items = selected_items.duplicate()
		_start_trade_take()
		return
	elif _pending_action == "trade_take":
		GameManager.try_trade_items(_trade_partner_index, _trade_give_items, selected_items)
		_trade_partner_index = -1
		_trade_give_items.clear()
	elif _pending_action == "advance":
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
	if _pending_action == "hit_item":
		_apply_hit_death()
		return
	if _pending_action == "trade_give" or _pending_action == "trade_take":
		_trade_partner_index = -1
		_trade_give_items.clear()
		_pending_action = ""
		return
	if _pending_action == "perk_delivery":
		_pending_perk_card = null
		_perk_step = ""
		_perk_data = {}
	_pending_action = ""

func _on_turn_changed(_player_index: int) -> void:
	end_turn_button.disabled = false
	_refresh_turn_display()

func _on_player_moved(player_index: int, space_id: int) -> void:
	_update_moves_indicator()
	_refresh_pickup_button()
	_refresh_action_buttons()
	if player_index == GameManager.active_player_index and GameManager.last_move_from_space >= 0:
		var from := GameManager.last_move_from_space
		GameManager.last_move_from_space = -1
		var from_space := GameManager.board_data.get_space(from) if GameManager.board_data != null else null
		var is_adjacent := from_space != null and from_space.neighbors.has(space_id)
		if is_adjacent:
			var here := VillagerManager.get_villagers_at(from)
			if not here.is_empty():
				_start_bring_along(here, space_id)

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
	main_menu_button.visible = true

func _on_game_lost() -> void:
	game_lost_label.visible = true
	main_menu_button.visible = true

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_space_attacked(space_id: int, num_hits: int) -> void:
	_hit_space_id = space_id
	_hit_remaining = num_hits
	_process_next_space_hit()

func _process_next_space_hit() -> void:
	if _hit_remaining <= 0:
		_hit_space_id = -1
		call_deferred("_emit_hit_resolved")
		return
	var players_here: Array[int] = []
	for i in range(GameManager.players.size()):
		var p := GameManager.players[i]
		if p.current_space_id == _hit_space_id and not GameManager.dead_players.has(i):
			players_here.append(i)
	var villagers_here: Array = VillagerManager.get_villagers_at(_hit_space_id)
	if players_here.is_empty() and villagers_here.is_empty():
		_hit_space_id = -1
		call_deferred("_emit_hit_resolved")
		return
	if players_here.size() + villagers_here.size() == 1:
		if not players_here.is_empty():
			_hit_target_player = players_here[0]
			_hit_target_villager = null
			_show_hit_block_choice()
		else:
			_hit_target_villager = villagers_here[0] as VillagerData
			_hit_target_player = -1
			_apply_villager_hit()
	else:
		var all_targets: Array = []
		var labels: Array[String] = []
		for pi in players_here:
			all_targets.append(pi)
			labels.append(GameManager.players[pi].display_name + " (hero)")
		for v in villagers_here:
			all_targets.append(v)
			labels.append((v as VillagerData).villager_name + " (villager)")
		_special_targets = all_targets
		_pending_action = "hit_who"
		_special_panel.open("Who takes the hit?", labels)

func _show_hit_block_choice() -> void:
	var player := GameManager.players[_hit_target_player]
	var has_blockable := false
	for item in player.inventory:
		if (item as ItemData).item_name != "The Cure":
			has_blockable = true
			break
	if not has_blockable:
		_apply_hit_death()
		return
	_pending_action = "hit_choice"
	_special_panel.open(player.display_name + " was hit!", ["Block with an item", "Take the hit (die)"])

func _apply_hit_death() -> void:
	var player_index := _hit_target_player
	_hit_target_player = -1
	_hit_remaining -= 1
	_pending_action = ""
	GameManager.apply_player_death(player_index)
	_process_next_space_hit()

func _apply_villager_hit() -> void:
	var v := _hit_target_villager
	_hit_target_villager = null
	_hit_remaining -= 1
	VillagerManager.kill_villager(v)
	_process_next_space_hit()

func _emit_hit_resolved() -> void:
	MonsterManager.hit_resolved.emit()

func _on_villager_rescued(villager_name: String) -> void:
	monster_log.text = villager_name + " escaped to safety! Drew a perk card."

func _on_move_villager_pressed() -> void:
	_start_move_villager()

func _on_cure_pressed() -> void:
	var items := GameManager.get_contribute_cure_items()
	if items.is_empty():
		return
	_pending_action = "contribute_cure"
	_item_panel.open(items, 0, 0, "Select blue items to contribute to the cure")

func _on_defeat_wolfman_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var red_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "red":
			red_items.append(item as ItemData)
	_pending_action = "defeat_wolfman"
	_item_panel.open(red_items, GameManager.get_item_strength_boost())

func _on_wolfman_cure_complete(player_index: int) -> void:
	monster_log.text = GameManager.players[player_index].display_name + " completed the cure and received The Cure!"


func _on_advance_mummy_pressed() -> void:
	var items := GameManager.get_advance_mummy_items()
	if items.is_empty():
		return
	_pending_action = "advance_mummy"
	_item_panel.open(items, 0, 0, "Select a yellow item to use on the scarab puzzle")


func _on_defeat_mummy_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var red_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "red":
			red_items.append(item as ItemData)
	_pending_action = "defeat_mummy"
	_item_panel.open(red_items, GameManager.get_item_strength_boost(), 9)


func _on_mummy_changed() -> void:
	_refresh_inventory()
	_refresh_action_buttons()


func _on_advance_frankenstein_pressed() -> void:
	var items := GameManager.get_advance_frankenstein_items()
	if items.is_empty():
		return
	_pending_action = "advance_frankenstein"
	_item_panel.open(items, 0, 0, "Select a yellow item to advance Frankenstein's dial")


func _on_advance_bride_pressed() -> void:
	var items := GameManager.get_advance_bride_items()
	if items.is_empty():
		return
	_pending_action = "advance_bride"
	_item_panel.open(items, 0, 0, "Select a blue item to advance the Bride's dial")


func _on_frankenstein_changed() -> void:
	_refresh_action_buttons()


func _on_advance_creature_pressed() -> void:
	var items := GameManager.get_advance_creature_items()
	if items.is_empty():
		return
	_pending_action = "advance_creature"
	_item_panel.open(items, 0, 0, "Select any item to advance the Creature indicator")


func _on_defeat_creature_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var items: Array[ItemData] = []
	for item in active.inventory:
		items.append(item as ItemData)
	_pending_action = "defeat_creature"
	_item_panel.open(items, 0, 0, "Select 1 red, 1 yellow, and 1 blue item", ["red", "yellow", "blue"])


func _on_creature_changed() -> void:
	_refresh_action_buttons()


func _on_trade_pressed() -> void:
	var partners := GameManager.get_trade_partners()
	if partners.is_empty():
		return
	if partners.size() == 1:
		_trade_partner_index = partners[0]
		_start_trade_give()
	else:
		_special_targets = partners
		_pending_action = "trade_partner"
		_special_panel.open("Trade with which player?", _player_indices_to_labels(partners))


func _start_trade_give() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var items: Array[ItemData] = []
	for item in active.inventory:
		items.append(item as ItemData)
	_pending_action = "trade_give"
	var partner_name := GameManager.players[_trade_partner_index].display_name
	_item_panel.open(items, 0, 0, "Give items to " + partner_name + " (select any, or none)", [], true, "Select Items")


func _start_trade_take() -> void:
	var partner := GameManager.players[_trade_partner_index]
	var items: Array[ItemData] = []
	for item in partner.inventory:
		items.append(item as ItemData)
	_pending_action = "trade_take"
	_item_panel.open(items, 0, 0, "Take items from " + partner.display_name + " (select any, or none)", [], true, "Select Items")


func _start_move_villager() -> void:
	var active_space := GameManager.players[GameManager.active_player_index].current_space_id
	var all_villagers: Array = []
	var labels: Array[String] = []
	for v in VillagerManager.get_villagers_at(active_space):
		all_villagers.append(v)
		labels.append((v as VillagerData).villager_name + " (push)")
	var space := GameManager.board_data.get_space(active_space)
	if space != null:
		for n: int in space.neighbors:
			for v in VillagerManager.get_villagers_at(n):
				all_villagers.append(v)
				labels.append((v as VillagerData).villager_name + " (pull here)")
	if all_villagers.is_empty():
		return
	_special_targets = all_villagers
	_pending_action = "mv_who"
	_special_panel.open("Move which villager?", labels)

func _start_bring_along(villagers: Array, to_space: int) -> void:
	_bring_along_queue = villagers.duplicate()
	_bring_along_destination = to_space
	_process_bring_along_queue()

func _process_bring_along_queue() -> void:
	if _bring_along_queue.is_empty():
		_bring_along_destination = -1
		_refresh_action_buttons()
		return
	var v := _bring_along_queue[0] as VillagerData
	_pending_action = "bring_along"
	_special_panel.open("Bring " + v.villager_name + " along?", ["Yes", "No"])

func _refresh_action_buttons() -> void:
	_update_moves_indicator()
	advance_button.visible = GameManager.can_advance()
	defeat_button.visible = GameManager.can_defeat()
	move_villager_button.visible = GameManager.can_move_villager()
	cure_button.visible = GameManager.can_contribute_cure()
	defeat_wolfman_button.visible = GameManager.can_defeat_wolfman()
	advance_mummy_button.visible = GameManager.can_advance_mummy()
	defeat_mummy_button.visible = GameManager.can_defeat_mummy()
	advance_frankenstein_button.visible = GameManager.can_advance_frankenstein()
	advance_bride_button.visible = GameManager.can_advance_bride()
	advance_creature_button.visible = GameManager.can_advance_creature()
	defeat_creature_button.visible = GameManager.can_defeat_creature()
	trade_button.visible = GameManager.can_trade_items()
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
	if GameManager.wolfman_hunted_player == GameManager.active_player_index:
		inventory_list.push_color(Color(0.85, 0.30, 0.05))
		inventory_list.add_text("⚠ HUNTED by the Wolfman\n")
		inventory_list.pop()
	if GameManager.mummy_soul_player == GameManager.active_player_index:
		inventory_list.push_color(Color(0.60, 0.35, 0.80))
		inventory_list.add_text("☽ SOUL TOKEN — drawn to the Mummy\n")
		inventory_list.pop()
	if GameManager.mummy_moves_remaining > 0:
		inventory_list.push_color(Color(0.85, 0.65, 0.10))
		inventory_list.add_text("Mummy puzzle: " + str(GameManager.mummy_moves_remaining) + " move(s) — click a token\n")
		inventory_list.pop()
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
