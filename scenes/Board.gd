class_name Board
extends Node2D

const SpaceNodeScene := preload("res://scenes/SpaceNode.tscn")
const BOARD_CENTER := Vector2(640, 360)
const BOARD_RADIUS := 200.0

var _space_nodes: Dictionary = {}   # space_id (int) -> SpaceNode

func _ready() -> void:
    var board_data: BoardData = load("res://resources/data/board.tres")
    _spawn_spaces(board_data)
    GameManager.turn_changed.connect(_on_turn_changed)
    GameManager.player_moved.connect(_on_player_moved)

func get_space_center(space_id: int) -> Vector2:
    if space_id in _space_nodes:
        return _space_nodes[space_id].get_space_center()
    return BOARD_CENTER

func _spawn_spaces(board_data: BoardData) -> void:
    var count := board_data.spaces.size()
    for i in range(count):
        var space_data := board_data.spaces[i]
        var angle := (TAU / count) * i - PI / 2.0
        var pos := BOARD_CENTER + Vector2(cos(angle), sin(angle)) * BOARD_RADIUS
        var node: SpaceNode = SpaceNodeScene.instantiate()
        add_child(node)
        node.position = pos - Vector2(50, 40)   # offset so center aligns to circle
        node.setup(space_data)
        node.clicked.connect(_on_space_clicked)
        _space_nodes[space_data.id] = node

func _on_space_clicked(space_id: int) -> void:
    GameManager.try_move(space_id)

func _on_turn_changed(_player_index: int) -> void:
    _refresh_legal_moves()

func _on_player_moved(_player_index: int, _space_id: int) -> void:
    _refresh_legal_moves()

func _refresh_legal_moves() -> void:
    var legal := GameManager.get_legal_moves()
    for space_id in _space_nodes:
        _space_nodes[space_id].set_legal_move(space_id in legal)
