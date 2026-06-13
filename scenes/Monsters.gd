extends Node

const MonsterTokenScene := preload("res://scenes/MonsterToken.tscn")

var _tokens: Array[MonsterToken] = []
var _board: Board = null
var _camera: Camera2D = null

func setup(monster_list: Array[MonsterData], board: Board, camera: Camera2D = null) -> void:
	_board = board
	_camera = camera
	for monster in monster_list:
		var token: MonsterToken = MonsterTokenScene.instantiate()
		add_child(token)
		token.setup(monster)
		_tokens.append(token)
	MonsterManager.monsters_moved.connect(_on_monsters_moved)
	MonsterManager.monster_relocated.connect(_place_all_tokens)
	GameManager.monster_defeated.connect(_on_monster_defeated)
	_place_all_tokens()

func _on_monster_defeated(monster_name: String) -> void:
	var idx := -1
	for i in range(_tokens.size()):
		if _tokens[i].monster_name == monster_name:
			idx = i
			break
	if idx == -1:
		push_error("Monsters.gd: no token found for defeated monster '%s'" % monster_name)
		return
	_tokens[idx].queue_free()
	_tokens.remove_at(idx)

func _on_monsters_moved(move_data: Array) -> void:
	for entry in move_data:
		var idx: int = entry["monster_idx"]
		var path: Array = entry["path"]
		for i in range(1, path.size()):
			var target := _board.get_space_center(path[i])
			if _camera != null:
				create_tween().tween_property(_camera, "position", target, MonsterToken.MOVE_DURATION) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await _tokens[idx].move_to(target).finished
	_place_all_tokens()
	# Defer one frame so phase_animation_done always fires after end_turn()'s await is set up,
	# even when move_data is empty and this handler ran synchronously.
	await get_tree().process_frame
	MonsterManager.phase_animation_done.emit()

func _place_all_tokens() -> void:
	if MonsterManager.monsters.size() != _tokens.size():
		push_error("Monsters.gd: token/monster count mismatch")
		return
	var positions := _compute_positions()
	for i in range(_tokens.size()):
		var on_board := MonsterManager.monsters[i].current_space_id >= 0
		_tokens[i].visible = on_board
		if on_board:
			_tokens[i].position = positions[i]

func _compute_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.resize(_tokens.size())
	var by_space: Dictionary = {}
	for i in range(MonsterManager.monsters.size()):
		var sid := MonsterManager.monsters[i].current_space_id
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
	return Vector2(cos(angle), sin(angle)) * 12.0
