extends Node

signal turn_changed(player_index: int)
signal player_moved(player_index: int, space_id: int)
signal items_changed

const MOVES_PER_TURN := 4
const PLAYER_COLORS: Array[Color] = [
	Color(0.91, 0.30, 0.24),  # red
	Color(0.20, 0.60, 0.86),  # blue
	Color(0.18, 0.80, 0.44),  # green
	Color(0.95, 0.61, 0.07),  # orange
	Color(0.70, 0.25, 0.90),  # purple
]
const PLAYER_NAMES: Array[String] = ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5"]
const CHARACTER_PATHS: Array[String] = [
	"res://resources/data/characters/scientist.tres",
	"res://resources/data/characters/archaeologist.tres",
	"res://resources/data/characters/professor.tres",
	"res://resources/data/characters/inspector.tres",
	"res://resources/data/characters/courier.tres",
	"res://resources/data/characters/mayor.tres",
	"res://resources/data/characters/explorer.tres",
]

var pending_player_count: int = 2
var pending_monster_paths: Array[String] = ["res://resources/data/dracula.tres"]

var players: Array[PlayerData] = []
var active_player_index: int = 0
var moves_remaining: int = 0
var board_data: BoardData = null
var bag: Array[ItemData] = []
var board_items: Dictionary = {}    # space_id (int) -> Array[ItemData]
var phase_running: bool = false
var dracula_coffins: Dictionary = {}   # space_id (int) -> smashed (bool)
var game_over: bool = false
var perk_cards: Array[PerkCardData] = []
var _perk_deck_remaining: Array[PerkCardData] = []
var terror_level: int = 0
var dead_players: Dictionary = {}   # player_index (int) -> true
var last_move_from_space: int = -1
var wolfman_cure_s1: int = 0
var wolfman_cure_s2: int = 0
var wolfman_cure_s3: int = 0
var wolfman_hunted_player: int = -1
var mummy_slot_contents: Array[int] = []
var mummy_slot_revealed: Array[bool] = []
var mummy_moves_remaining: int = 0
var mummy_soul_player: int = -1
var frank_pending_strength: int = 0
var bride_pending_strength: int = 0

const TERROR_MAX := 7

const MUMMY_ADJACENCY: Array = [
	[1, 5, 6],
	[0, 2, 6],
	[1, 3, 6],
	[2, 4, 6],
	[3, 5, 6],
	[4, 0, 6],
	[0, 1, 2, 3, 4, 5],
]

signal monster_defeated(monster_name: String)
signal game_won
signal game_lost
signal perk_cards_changed
signal terror_changed(level: int)
signal wolfman_cure_complete(player_index: int)
signal wolfman_hunted_changed(player_index: int)
signal mummy_changed
signal mummy_soul_changed(player_index: int)
signal frankenstein_changed

func start_game(player_count: int) -> void:
	player_count = clampi(player_count, 1, 5)
	board_data = load("res://resources/data/board.tres") as BoardData
	if board_data == null:
		push_error("GameManager: failed to load board.tres")
		return
	var all_characters := _load_all_characters()
	all_characters.shuffle()
	players.clear()
	for i in range(player_count):
		var p := PlayerData.new()
		p.player_name = PLAYER_NAMES[i]
		p.color = PLAYER_COLORS[i]
		var char_data: CharacterData = all_characters[i] if i < all_characters.size() else null
		p.character = char_data
		p.current_space_id = _find_space_by_name(char_data.starting_space_name) if char_data != null else 0
		players.append(p)
	active_player_index = 0
	moves_remaining = players[0].character.actions_per_turn if players[0].character != null else MOVES_PER_TURN
	board_items.clear()
	game_over = false
	terror_level = 0
	dead_players.clear()
	wolfman_cure_s1 = 0
	wolfman_cure_s2 = 0
	wolfman_cure_s3 = 0
	wolfman_hunted_player = -1
	mummy_slot_contents.clear()
	mummy_slot_revealed.clear()
	mummy_moves_remaining = 0
	mummy_soul_player = -1
	frank_pending_strength = 0
	bride_pending_strength = 0
	dracula_coffins.clear()
	for space in board_data.spaces:
		if space.name in ["Cave", "Crypt", "Dungeon", "Graveyard"]:
			dracula_coffins[space.id] = false
	_place_initial_items()
	_deal_perk_cards(player_count)
	turn_changed.emit(0)

func _load_all_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for path in CHARACTER_PATHS:
		var c := load(path) as CharacterData
		if c != null:
			result.append(c)
	return result

func _find_space_by_name(space_name: String) -> int:
	if board_data == null:
		return 0
	for space in board_data.spaces:
		if space.name == space_name:
			return space.id
	return 0

func _place_initial_items() -> void:
	var item_bag_data := load("res://resources/data/items.tres") as ItemBagData
	if item_bag_data == null:
		push_error("GameManager: failed to load items.tres")
		return
	bag = item_bag_data.items.duplicate()
	bag.shuffle()
	var placed := 0
	for item in bag:
		if placed >= 12:
			break
		if not board_items.has(item.location):
			board_items[item.location] = []
		board_items[item.location].append(item)
		placed += 1
	bag = bag.slice(placed)
	items_changed.emit()

func _deal_perk_cards(player_count: int) -> void:
	var deck := load("res://resources/data/perk_deck.tres") as PerkDeckData
	if deck == null:
		return
	var shuffled := deck.cards.duplicate()
	shuffled.shuffle()
	perk_cards.clear()
	_perk_deck_remaining.clear()
	for i in range(shuffled.size()):
		if i < player_count:
			perk_cards.append(shuffled[i] as PerkCardData)
		else:
			_perk_deck_remaining.append(shuffled[i] as PerkCardData)
	perk_cards_changed.emit()

func add_perk_card_to_pool() -> void:
	if _perk_deck_remaining.is_empty():
		return
	perk_cards.append(_perk_deck_remaining.pop_front() as PerkCardData)
	perk_cards_changed.emit()

func play_perk_card(card: PerkCardData) -> void:
	if phase_running:
		return
	var idx := perk_cards.find(card)
	if idx == -1:
		return
	perk_cards.remove_at(idx)
	perk_cards_changed.emit()

func teleport_player(player_index: int, space_id: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	players[player_index].current_space_id = space_id
	player_moved.emit(player_index, space_id)

func _is_water(space_id: int) -> bool:
	if board_data == null:
		return false
	var space := board_data.get_space(space_id)
	return space != null and space.is_water

func get_spaces_reachable(from_id: int, max_steps: int, allow_water: bool = false) -> Array[int]:
	if board_data == null:
		return []
	var visited: Dictionary = {from_id: true}
	var result: Array[int] = []
	var frontier: Array[int] = [from_id]
	for _step in range(max_steps):
		var next_frontier: Array[int] = []
		for sid in frontier:
			var space := board_data.get_space(sid as int)
			if space == null:
				continue
			for neighbor in space.neighbors:
				var n: int = neighbor as int
				if visited.has(n):
					continue
				if not allow_water and _is_water(n):
					continue
				visited[n] = true
				next_frontier.append(n)
				result.append(n)
		if next_frontier.is_empty():
			break
		frontier = next_frontier
	return result

func try_move(space_id: int) -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty() or board_data == null:
		return false
	var current_player := players[active_player_index]
	var legal := get_legal_moves()
	if not legal.has(space_id):
		return false
	last_move_from_space = current_player.current_space_id
	current_player.current_space_id = space_id
	moves_remaining -= 1
	player_moved.emit(active_player_index, space_id)
	return true

func can_move_villager() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty() or board_data == null:
		return false
	var space_id := players[active_player_index].current_space_id
	if not VillagerManager.get_villagers_at(space_id).is_empty():
		return true
	var space := board_data.get_space(space_id)
	if space == null:
		return false
	for n: int in space.neighbors:
		if not VillagerManager.get_villagers_at(n).is_empty():
			return true
	return false

func try_move_villager(villager: VillagerData, space_id: int) -> bool:
	if game_over or phase_running or moves_remaining <= 0:
		return false
	moves_remaining -= 1
	VillagerManager.move_villager(villager, space_id)
	return true

func end_turn() -> void:
	if players.is_empty() or phase_running or game_over:
		return
	phase_running = true
	await MonsterManager.run_phase()
	phase_running = false
	if game_over:
		return
	if mummy_moves_remaining > 0:
		mummy_moves_remaining = 0
		mummy_changed.emit()
	active_player_index = (active_player_index + 1) % players.size()
	var next_player := players[active_player_index]
	if dead_players.has(active_player_index):
		dead_players.erase(active_player_index)
		next_player.current_space_id = _find_space_by_name("Hospital")
	var next_char := next_player.character
	moves_remaining = next_char.actions_per_turn if next_char != null else MOVES_PER_TURN
	turn_changed.emit(active_player_index)

func apply_player_death(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	players[player_index].current_space_id = -1
	dead_players[player_index] = true
	terror_level += 1
	terror_changed.emit(terror_level)
	if terror_level >= TERROR_MAX:
		game_over = true
		game_lost.emit()

func can_pickup() -> bool:
	if moves_remaining <= 0 or players.is_empty():
		return false
	var space_id := players[active_player_index].current_space_id
	return board_items.has(space_id) and (board_items[space_id] as Array).size() > 0

func try_pickup() -> bool:
	if not can_pickup():
		return false
	var current_player := players[active_player_index]
	var space_id := current_player.current_space_id
	for item in board_items[space_id]:
		current_player.inventory.append(item as ItemData)
	board_items.erase(space_id)
	moves_remaining -= 1
	items_changed.emit()
	return true

func get_active_player() -> PlayerData:
	if players.is_empty():
		return null
	return players[active_player_index]

func get_board_items(space_id: int) -> Array:
	if board_items.has(space_id):
		return (board_items[space_id] as Array).duplicate()
	return []

func peek_draw_items(count: int) -> Array:
	var result: Array = []
	var i := 0
	while i < count and i < bag.size():
		var item := bag[i] as ItemData
		var space := board_data.get_space(item.location) if board_data != null else null
		if space != null:
			result.append({"world_pos": space.position + Vector2(50.0, 40.0), "color": item.color})
		i += 1
	return result

func draw_items_to_board(count: int) -> void:
	var drawn := 0
	while drawn < count and not bag.is_empty():
		var item := bag.pop_front() as ItemData
		if not board_items.has(item.location):
			board_items[item.location] = []
		board_items[item.location].append(item)
		drawn += 1
	if drawn > 0:
		items_changed.emit()

func get_legal_moves() -> Array[int]:
	if moves_remaining <= 0 or players.is_empty() or board_data == null:
		return []
	var current_player := players[active_player_index]
	var special_id := current_player.character.special_id if current_player.character != null else ""
	if special_id == "explorer":
		return get_all_space_ids()
	var current_space := board_data.get_space(current_player.current_space_id)
	var neighbors: Array[int] = []
	if current_space != null:
		for n: int in current_space.neighbors:
			if not _is_water(n):
				neighbors.append(n)
	match special_id:
		"inspector":
			for sid in get_monster_spaces():
				if not neighbors.has(sid):
					neighbors.append(sid)
		"courier":
			for sid in get_other_player_spaces():
				if not neighbors.has(sid):
					neighbors.append(sid)
	return neighbors

func _get_dracula() -> MonsterData:
	for m in MonsterManager.monsters:
		if m.monster_name == "Dracula":
			return m
	return null

func get_item_strength_boost() -> int:
	if players.is_empty():
		return 0
	var char_data := players[active_player_index].character
	return 1 if (char_data != null and char_data.special_id == "scientist") else 0

func can_advance() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	if _get_dracula() == null:
		return false
	var space_id := players[active_player_index].current_space_id
	return dracula_coffins.has(space_id) and dracula_coffins[space_id] == false

func try_advance(items: Array[ItemData]) -> bool:
	if not can_advance():
		return false
	var boost := get_item_strength_boost()
	var total := 0
	for item in items:
		if item.color != "red":
			return false
		total += item.strength + boost
	if total < 6:
		return false
	var current_player := players[active_player_index]
	for item in items:
		if not current_player.inventory.has(item):
			return false
	for item in items:
		current_player.inventory.erase(item)
	dracula_coffins[current_player.current_space_id] = true
	moves_remaining -= 1
	items_changed.emit()
	var all_smashed := true
	for smashed in dracula_coffins.values():
		if not smashed:
			all_smashed = false
			break
	if all_smashed:
		var dracula := _get_dracula()
		if dracula != null:
			dracula.task_complete = true
	return true

func can_defeat() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var dracula := _get_dracula()
	if dracula == null or not dracula.task_complete:
		return false
	return players[active_player_index].current_space_id == dracula.current_space_id

func try_defeat(items: Array[ItemData]) -> bool:
	if not can_defeat():
		return false
	var boost := get_item_strength_boost()
	var total := 0
	for item in items:
		if item.color != "yellow":
			return false
		total += item.strength + boost
	if total < 6:
		return false
	var current_player := players[active_player_index]
	for item in items:
		if not current_player.inventory.has(item):
			return false
	for item in items:
		current_player.inventory.erase(item)
	moves_remaining -= 1
	items_changed.emit()
	monster_defeated.emit("Dracula")
	MonsterManager.remove_monster("Dracula")
	if MonsterManager.monsters.is_empty():
		game_over = true
		game_won.emit()
	return true

# --- Special Actions ---

func can_use_special() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var char_data := players[active_player_index].character
	if char_data == null or char_data.special_id == "" or char_data.special_id == "scientist":
		return false
	match char_data.special_id:
		"archaeologist":
			return not get_archaeologist_targets().is_empty()
		"professor":
			return not get_other_player_indices().is_empty()
	return false

func get_archaeologist_targets() -> Array[int]:
	if players.is_empty() or board_data == null:
		return []
	var current_space := board_data.get_space(players[active_player_index].current_space_id)
	if current_space == null:
		return []
	var result: Array[int] = []
	for neighbor_id: int in current_space.neighbors:
		if board_items.has(neighbor_id) and (board_items[neighbor_id] as Array).size() > 0:
			result.append(neighbor_id)
	return result

func try_archaeologist(space_id: int) -> bool:
	if not can_use_special():
		return false
	if players[active_player_index].character.special_id != "archaeologist":
		return false
	if not get_archaeologist_targets().has(space_id):
		return false
	var current_player := players[active_player_index]
	for item in board_items[space_id]:
		current_player.inventory.append(item as ItemData)
	board_items.erase(space_id)
	moves_remaining -= 1
	items_changed.emit()
	return true

func get_other_player_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(players.size()):
		if i != active_player_index:
			result.append(i)
	return result

func get_professor_targets_for_player(player_index: int) -> Array[int]:
	if board_data == null or player_index < 0 or player_index >= players.size():
		return []
	var space := board_data.get_space(players[player_index].current_space_id)
	if space == null:
		return []
	var result: Array[int] = []
	for n: int in space.neighbors:
		if not _is_water(n):
			result.append(n)
	return result

func try_professor(target_player_index: int, space_id: int) -> bool:
	if not can_use_special():
		return false
	if players[active_player_index].character.special_id != "professor":
		return false
	if target_player_index == active_player_index:
		return false
	if target_player_index < 0 or target_player_index >= players.size():
		return false
	if not get_professor_targets_for_player(target_player_index).has(space_id):
		return false
	players[target_player_index].current_space_id = space_id
	player_moved.emit(target_player_index, space_id)
	moves_remaining -= 1
	return true

func _get_wolfman() -> MonsterData:
	for m in MonsterManager.monsters:
		if m.monster_name == "Wolfman":
			return m
	return null


func can_contribute_cure() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	if _get_wolfman() == null:
		return false
	var lab_id := _find_space_by_name("Laboratory")
	if players[active_player_index].current_space_id != lab_id:
		return false
	return not get_contribute_cure_items().is_empty()


func get_contribute_cure_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in players[active_player_index].inventory:
		var i := item as ItemData
		if i.color != "blue":
			continue
		if i.strength == 1 and wolfman_cure_s1 < 2:
			result.append(i)
		elif i.strength == 2 and wolfman_cure_s2 < 2:
			result.append(i)
		elif i.strength == 3 and wolfman_cure_s3 < 2:
			result.append(i)
	return result


func try_contribute_cure(items: Array[ItemData]) -> bool:
	if not can_contribute_cure():
		return false
	var current_player := players[active_player_index]
	for item in items:
		if not current_player.inventory.has(item):
			continue
		match item.strength:
			1:
				if wolfman_cure_s1 < 2:
					wolfman_cure_s1 += 1
					current_player.inventory.erase(item)
			2:
				if wolfman_cure_s2 < 2:
					wolfman_cure_s2 += 1
					current_player.inventory.erase(item)
			3:
				if wolfman_cure_s3 < 2:
					wolfman_cure_s3 += 1
					current_player.inventory.erase(item)
	moves_remaining -= 1
	items_changed.emit()
	if wolfman_cure_s1 >= 2 and wolfman_cure_s2 >= 2 and wolfman_cure_s3 >= 2:
		_give_the_cure(active_player_index)
	return true


func _give_the_cure(player_index: int) -> void:
	var cure := ItemData.new()
	cure.item_name = "The Cure"
	cure.color = ""
	cure.strength = 0
	players[player_index].inventory.append(cure)
	wolfman_cure_complete.emit(player_index)
	items_changed.emit()


func can_defeat_wolfman() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var wolfman := _get_wolfman()
	if wolfman == null:
		return false
	var player := players[active_player_index]
	if player.current_space_id != wolfman.current_space_id:
		return false
	for item in player.inventory:
		if (item as ItemData).item_name == "The Cure":
			return true
	return false


func try_defeat_wolfman(red_items: Array[ItemData]) -> bool:
	if not can_defeat_wolfman():
		return false
	var current_player := players[active_player_index]
	var boost := get_item_strength_boost()
	var total := 0
	for item in red_items:
		if not current_player.inventory.has(item) or item.color != "red":
			return false
		total += item.strength + boost
	if total < 6:
		return false
	var cure_item: ItemData = null
	for item in current_player.inventory:
		if (item as ItemData).item_name == "The Cure":
			cure_item = item as ItemData
			break
	if cure_item == null:
		return false
	current_player.inventory.erase(cure_item)
	for item in red_items:
		current_player.inventory.erase(item)
	moves_remaining -= 1
	items_changed.emit()
	monster_defeated.emit("Wolfman")
	MonsterManager.remove_monster("Wolfman")
	if MonsterManager.monsters.is_empty():
		game_over = true
		game_won.emit()
	return true


func get_monster_spaces() -> Array[int]:
	var spaces: Array[int] = []
	for m: MonsterData in MonsterManager.monsters:
		var sid: int = m.current_space_id
		if not spaces.has(sid):
			spaces.append(sid)
	return spaces

func try_inspector(space_id: int) -> bool:
	if not can_use_special():
		return false
	if players[active_player_index].character.special_id != "inspector":
		return false
	if not get_monster_spaces().has(space_id):
		return false
	players[active_player_index].current_space_id = space_id
	player_moved.emit(active_player_index, space_id)
	moves_remaining -= 1
	return true

func get_other_player_spaces() -> Array[int]:
	if players.is_empty():
		return []
	var spaces: Array[int] = []
	for i in range(players.size()):
		if i != active_player_index:
			var sid: int = players[i].current_space_id
			if not spaces.has(sid):
				spaces.append(sid)
	return spaces

func try_courier(space_id: int) -> bool:
	if not can_use_special():
		return false
	if players[active_player_index].character.special_id != "courier":
		return false
	if not get_other_player_spaces().has(space_id):
		return false
	players[active_player_index].current_space_id = space_id
	player_moved.emit(active_player_index, space_id)
	moves_remaining -= 1
	return true

func get_all_space_ids() -> Array[int]:
	if board_data == null:
		return []
	var result: Array[int] = []
	for space in board_data.spaces:
		if not space.is_water:
			result.append(space.id)
	return result

func try_explorer(space_id: int) -> bool:
	if not can_use_special():
		return false
	if players[active_player_index].character.special_id != "explorer":
		return false
	if not get_all_space_ids().has(space_id):
		return false
	players[active_player_index].current_space_id = space_id
	player_moved.emit(active_player_index, space_id)
	moves_remaining -= 1
	return true


func setup_mummy_puzzle() -> void:
	mummy_slot_contents.clear()
	mummy_slot_revealed.clear()
	mummy_moves_remaining = 0
	mummy_soul_player = -1
	if _get_mummy() == null:
		return
	mummy_slot_contents.resize(7)
	mummy_slot_revealed.resize(7)
	var high := [4, 5, 6]
	high.shuffle()
	for i in range(3):
		mummy_slot_contents[i] = high[i]
		mummy_slot_revealed[i] = false
	var low := [1, 2, 3]
	low.shuffle()
	for i in range(3):
		mummy_slot_contents[3 + i] = low[i]
		mummy_slot_revealed[3 + i] = false
	mummy_slot_contents[6] = 0
	mummy_slot_revealed[6] = true


func _get_mummy() -> MonsterData:
	for m in MonsterManager.monsters:
		if m.monster_name == "Mummy":
			return m
	return null


func can_advance_mummy() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	if _get_mummy() == null:
		return false
	if is_mummy_puzzle_solved():
		return false
	var museum_id := _find_space_by_name("Museum")
	if players[active_player_index].current_space_id != museum_id:
		return false
	return not get_advance_mummy_items().is_empty()


func get_advance_mummy_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in players[active_player_index].inventory:
		var it := item as ItemData
		if it.color == "yellow":
			result.append(it)
	return result


func try_advance_mummy(item: ItemData) -> bool:
	if not can_advance_mummy():
		return false
	if item.color != "yellow":
		return false
	players[active_player_index].inventory.erase(item)
	mummy_moves_remaining = item.strength
	moves_remaining -= 1
	items_changed.emit()
	mummy_changed.emit()
	return true


func _mummy_empty_slot() -> int:
	for i in range(mummy_slot_contents.size()):
		if mummy_slot_contents[i] == 0:
			return i
	return -1


func can_flip_mummy_token(slot_idx: int) -> bool:
	if mummy_moves_remaining <= 0:
		return false
	if slot_idx < 0 or slot_idx >= mummy_slot_contents.size():
		return false
	if mummy_slot_contents[slot_idx] == 0:
		return false
	return not mummy_slot_revealed[slot_idx]


func try_flip_mummy_token(slot_idx: int) -> bool:
	if not can_flip_mummy_token(slot_idx):
		return false
	mummy_slot_revealed[slot_idx] = true
	mummy_moves_remaining -= 1
	mummy_changed.emit()
	if is_mummy_puzzle_solved():
		mummy_changed.emit()
	return true


func can_slide_mummy_token(slot_idx: int) -> bool:
	if mummy_moves_remaining <= 0:
		return false
	if slot_idx < 0 or slot_idx >= mummy_slot_contents.size():
		return false
	if mummy_slot_contents[slot_idx] == 0:
		return false
	if not mummy_slot_revealed[slot_idx]:
		return false
	var empty := _mummy_empty_slot()
	if empty < 0:
		return false
	return (MUMMY_ADJACENCY[slot_idx] as Array).has(empty)


func try_slide_mummy_token(slot_idx: int) -> bool:
	if not can_slide_mummy_token(slot_idx):
		return false
	var empty := _mummy_empty_slot()
	mummy_slot_contents[empty] = mummy_slot_contents[slot_idx]
	mummy_slot_revealed[empty] = mummy_slot_revealed[slot_idx]
	mummy_slot_contents[slot_idx] = 0
	mummy_slot_revealed[slot_idx] = true
	mummy_moves_remaining -= 1
	mummy_changed.emit()
	return true


func is_mummy_puzzle_solved() -> bool:
	if mummy_slot_contents.size() < 7:
		return false
	for i in range(6):
		if not mummy_slot_revealed[i]:
			return false
		if mummy_slot_contents[i] != i + 1:
			return false
	return true


func can_defeat_mummy() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var mummy := _get_mummy()
	if mummy == null:
		return false
	if not is_mummy_puzzle_solved():
		return false
	var player := players[active_player_index]
	if player.current_space_id != mummy.current_space_id:
		return false
	for item in player.inventory:
		if (item as ItemData).color == "red":
			return true
	return false


func try_defeat_mummy(red_items: Array[ItemData]) -> bool:
	if not can_defeat_mummy():
		return false
	var boost := get_item_strength_boost()
	var total := 0
	for item in red_items:
		if not players[active_player_index].inventory.has(item) or item.color != "red":
			return false
		total += item.strength + boost
	if total < 9:
		return false
	for item in red_items:
		players[active_player_index].inventory.erase(item)
	moves_remaining -= 1
	mummy_soul_player = -1
	mummy_soul_changed.emit(-1)
	items_changed.emit()
	monster_defeated.emit("Mummy")
	MonsterManager.remove_monster("Mummy")
	if MonsterManager.monsters.is_empty():
		game_over = true
		game_won.emit()
	return true


func _get_frankenstein() -> MonsterData:
	for m in MonsterManager.monsters:
		if m.monster_name == "Frankenstein":
			return m
	return null


func _get_bride() -> MonsterData:
	for m in MonsterManager.monsters:
		if m.monster_name == "Bride":
			return m
	return null


func can_advance_frankenstein() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var frank := _get_frankenstein()
	if frank == null or frank.dial_value >= frank.dial_max:
		return false
	if players[active_player_index].current_space_id != frank.current_space_id:
		return false
	return not get_advance_frankenstein_items().is_empty()


func get_advance_frankenstein_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in players[active_player_index].inventory:
		var it := item as ItemData
		if it.color == "yellow":
			result.append(it)
	return result


func get_frankenstein_destinations() -> Array[int]:
	var frank := _get_frankenstein()
	if frank == null:
		return [-1]
	var reachable := get_spaces_reachable(frank.current_space_id, frank_pending_strength)
	var destinations: Array[int] = [-1]
	destinations.append_array(reachable)
	return destinations


func try_advance_frankenstein(item: ItemData) -> bool:
	if not can_advance_frankenstein():
		return false
	if item.color != "yellow":
		return false
	var frank := _get_frankenstein()
	if frank == null:
		return false
	players[active_player_index].inventory.erase(item)
	frank.dial_value = mini(frank.dial_value + item.strength, frank.dial_max)
	frank_pending_strength = item.strength
	items_changed.emit()
	frankenstein_changed.emit()
	return true


func move_frankenstein(space_id: int) -> void:
	var frank := _get_frankenstein()
	if frank == null:
		frank_pending_strength = 0
		return
	if space_id >= 0:
		frank.current_space_id = space_id
		MonsterManager.monster_relocated.emit()
	frank_pending_strength = 0
	moves_remaining -= 1
	frankenstein_changed.emit()
	check_frankenstein_meeting()


func can_advance_bride() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var bride := _get_bride()
	if bride == null or bride.dial_value >= bride.dial_max:
		return false
	if players[active_player_index].current_space_id != bride.current_space_id:
		return false
	return not get_advance_bride_items().is_empty()


func get_advance_bride_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in players[active_player_index].inventory:
		var it := item as ItemData
		if it.color == "blue":
			result.append(it)
	return result


func get_bride_destinations() -> Array[int]:
	var bride := _get_bride()
	if bride == null:
		return [-1]
	var reachable := get_spaces_reachable(bride.current_space_id, bride_pending_strength)
	var destinations: Array[int] = [-1]
	destinations.append_array(reachable)
	return destinations


func try_advance_bride(item: ItemData) -> bool:
	if not can_advance_bride():
		return false
	if item.color != "blue":
		return false
	var bride := _get_bride()
	if bride == null:
		return false
	players[active_player_index].inventory.erase(item)
	bride.dial_value = mini(bride.dial_value + item.strength, bride.dial_max)
	bride_pending_strength = item.strength
	items_changed.emit()
	frankenstein_changed.emit()
	return true


func move_bride(space_id: int) -> void:
	var bride := _get_bride()
	if bride == null:
		bride_pending_strength = 0
		return
	if space_id >= 0:
		bride.current_space_id = space_id
		MonsterManager.monster_relocated.emit()
	bride_pending_strength = 0
	moves_remaining -= 1
	frankenstein_changed.emit()
	check_frankenstein_meeting()


func check_frankenstein_meeting() -> void:
	var frank := _get_frankenstein()
	var bride := _get_bride()
	if frank == null or bride == null:
		return
	if frank.current_space_id != bride.current_space_id:
		return
	if frank.dial_value >= frank.dial_max and bride.dial_value >= bride.dial_max:
		monster_defeated.emit("Frankenstein")
		monster_defeated.emit("Bride")
		MonsterManager.remove_monster("Frankenstein")
		MonsterManager.remove_monster("Bride")
		frankenstein_changed.emit()
		if MonsterManager.monsters.is_empty():
			game_over = true
			game_won.emit()
	else:
		terror_level += 1
		terror_changed.emit(terror_level)
		frank.current_space_id = frank.starting_space_id
		bride.current_space_id = bride.starting_space_id
		MonsterManager.monster_relocated.emit()
		frankenstein_changed.emit()
		if terror_level >= TERROR_MAX:
			game_over = true
			game_lost.emit()
