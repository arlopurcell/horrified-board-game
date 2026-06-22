extends Node

const PlayerTokenScene := preload("res://scenes/PlayerToken.tscn")

var _tokens: Array[PlayerToken] = []
var _board: Board = null
var _move_tween: Tween = null

func setup(player_list: Array[PlayerData], board: Board) -> void:
	_board = board
	for i in range(player_list.size()):
		var token: PlayerToken = PlayerTokenScene.instantiate()
		add_child(token)
		token.setup(player_list[i])
		_tokens.append(token)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.turn_changed.connect(_on_turn_changed)
	_place_all_tokens()

func _on_player_moved(player_index: int, _space_id: int) -> void:
	if GameManager.players.size() != _tokens.size():
		push_error("Players.gd: token/player count mismatch")
		return
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_sync_token_visibility()
	var positions := _compute_positions()
	for i in range(_tokens.size()):
		if i != player_index:
			_tokens[i].position = positions[i]
	if GameManager.players[player_index].current_space_id == -1:
		return
	_move_tween = _tokens[player_index].move_to(positions[player_index])
	await _move_tween.finished

func _on_turn_changed(_player_index: int) -> void:
	_place_all_tokens()

func _place_all_tokens() -> void:
	if GameManager.players.size() != _tokens.size():
		push_error("Players.gd: token/player count mismatch")
		return
	_sync_token_visibility()
	var positions := _compute_positions()
	for i in range(_tokens.size()):
		_tokens[i].position = positions[i]

func _sync_token_visibility() -> void:
	for i in range(_tokens.size()):
		_tokens[i].visible = GameManager.players[i].current_space_id != -1

func _compute_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.resize(_tokens.size())
	var by_space: Dictionary = {}
	for i in range(GameManager.players.size()):
		var sid := GameManager.players[i].current_space_id
		if sid == -1:
			continue
		if sid not in by_space:
			by_space[sid] = []
		by_space[sid].append(i)
	for space_id in by_space:
		var occupants: Array = by_space[space_id]
		var base := _board.get_space_center(space_id)
		for j in range(occupants.size()):
			var idx: int = occupants[j]
			positions[idx] = base + _cluster_offset(j, occupants.size())
	return positions

func _cluster_offset(slot: int, total: int) -> Vector2:
	if total == 1:
		return Vector2.ZERO
	var angle := (TAU / total) * slot
	return Vector2(cos(angle), sin(angle)) * 8.0
