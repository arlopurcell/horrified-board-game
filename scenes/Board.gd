class_name Board
extends Node2D

const SpaceNodeScene := preload("res://scenes/SpaceNode.tscn")

const CONNECTION_COLOR := Color(0.353, 0.235, 0.1, 0.5)
const WATER_CONNECTION_COLOR := Color(0.20, 0.48, 0.78, 0.65)
const CONNECTION_WIDTH := 4.0
const BORDER_COLOR := Color(0.353, 0.235, 0.1, 1.0)
const BORDER_PAD := 20.0
const BORDER_TOP_EXTRA := 65.0

var _space_nodes: Dictionary = {}   # space_id (int) -> SpaceNode
var _board_data: BoardData = null
var _water_ids: Dictionary = {}     # set of water space IDs

func _ready() -> void:
	_board_data = load("res://resources/data/board.tres")
	for space in _board_data.spaces:
		if space.is_water:
			_water_ids[space.id] = true
	_spawn_spaces(_board_data)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.items_changed.connect(_on_items_changed)

func _draw() -> void:
	if _board_data == null:
		return
	_draw_board_border()
	for space_data in _board_data.spaces:
		if not space_data.id in _space_nodes:
			continue
		var from: Vector2 = (_space_nodes[space_data.id] as SpaceNode).position + SpaceNode.SIZE / 2
		for neighbor_id in space_data.neighbors:
			if neighbor_id <= space_data.id or not neighbor_id in _space_nodes:
				continue
			var to: Vector2 = (_space_nodes[neighbor_id] as SpaceNode).position + SpaceNode.SIZE / 2
			var is_water_conn := _water_ids.has(space_data.id) or _water_ids.has(neighbor_id)
			draw_line(from, to, WATER_CONNECTION_COLOR if is_water_conn else CONNECTION_COLOR, CONNECTION_WIDTH, true)

func _draw_board_border() -> void:
	if _space_nodes.is_empty():
		return
	var min_x := INF; var min_y := INF; var max_x := -INF; var max_y := -INF
	for space_id in _space_nodes:
		var sn := _space_nodes[space_id] as SpaceNode
		min_x = minf(min_x, sn.position.x)
		min_y = minf(min_y, sn.position.y)
		max_x = maxf(max_x, sn.position.x + SpaceNode.SIZE.x)
		max_y = maxf(max_y, sn.position.y + SpaceNode.SIZE.y)
	var top := min_y - BORDER_PAD - BORDER_TOP_EXTRA
	draw_rect(Rect2(min_x - BORDER_PAD, top,
			max_x - min_x + BORDER_PAD * 2, max_y - top + BORDER_PAD),
			BORDER_COLOR, false, 4.0)

func get_space_center(space_id: int) -> Vector2:
	if space_id in _space_nodes:
		return _space_nodes[space_id].get_space_center()
	return Vector2(640, 360)

func _spawn_spaces(board_data: BoardData) -> void:
	for space_data in board_data.spaces:
		var node: SpaceNode = SpaceNodeScene.instantiate()
		add_child(node)
		node.position = space_data.position - SpaceNode.SIZE / 2
		node.setup(space_data)
		node.clicked.connect(_on_space_clicked)
		_space_nodes[space_data.id] = node

func _on_space_clicked(space_id: int) -> void:
	GameManager.try_move(space_id)

func _on_turn_changed(_player_index: int) -> void:
	_refresh_legal_moves()

func _on_player_moved(_player_index: int, _space_id: int) -> void:
	_refresh_legal_moves()

func _on_items_changed() -> void:
	for space_id in _space_nodes:
		(_space_nodes[space_id] as SpaceNode).set_items(GameManager.get_board_items(space_id))

func _refresh_legal_moves() -> void:
	var legal := GameManager.get_legal_moves()
	for space_id in _space_nodes:
		_space_nodes[space_id].set_legal_move(space_id in legal)
