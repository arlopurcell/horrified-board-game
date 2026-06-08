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
]
const PLAYER_NAMES: Array[String] = ["Player 1", "Player 2", "Player 3", "Player 4"]

var players: Array[PlayerData] = []
var active_player_index: int = 0
var moves_remaining: int = 0
var board_data: BoardData = null
var bag: Array[ItemData] = []
var board_items: Dictionary = {}    # space_id (int) -> Array[ItemData]

func start_game(player_count: int) -> void:
    player_count = clampi(player_count, 2, 4)
    board_data = load("res://resources/data/board.tres") as BoardData
    if board_data == null:
        push_error("GameManager: failed to load board.tres")
        return
    players.clear()
    for i in range(player_count):
        var p := PlayerData.new()
        p.player_name = PLAYER_NAMES[i]
        p.color = PLAYER_COLORS[i]
        p.current_space_id = 0
        players.append(p)
    active_player_index = 0
    moves_remaining = MOVES_PER_TURN
    board_items.clear()
    _place_initial_items()
    turn_changed.emit(0)

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

func try_move(space_id: int) -> bool:
    if moves_remaining <= 0 or players.is_empty() or board_data == null:
        return false
    var current_player := players[active_player_index]
    var current_space := board_data.get_space(current_player.current_space_id)
    if current_space == null or space_id not in current_space.neighbors:
        return false
    current_player.current_space_id = space_id
    moves_remaining -= 1
    player_moved.emit(active_player_index, space_id)
    return true

func end_turn() -> void:
    if players.is_empty():
        return
    # Run phase before advancing so active_player_index still refers to the player who just finished.
    MonsterManager.run_phase()
    active_player_index = (active_player_index + 1) % players.size()
    moves_remaining = MOVES_PER_TURN
    turn_changed.emit(active_player_index)

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
    var current_space := board_data.get_space(current_player.current_space_id)
    if current_space == null:
        return []
    return current_space.neighbors.duplicate()
