extends Node

const MonsterTokenScene := preload("res://scenes/MonsterToken.tscn")

var _tokens: Array[MonsterToken] = []
var _board: Board = null

func setup(monster_list: Array[MonsterData], board: Board) -> void:
	_board = board
	for monster in monster_list:
		var token: MonsterToken = MonsterTokenScene.instantiate()
		add_child(token)
		token.setup(monster)
		_tokens.append(token)
	MonsterManager.monsters_moved.connect(_on_monsters_moved)
	GameManager.monster_defeated.connect(_on_monster_defeated)
	_place_all_tokens()

func _on_monster_defeated(monster_name: String) -> void:
	var idx := -1
	for i in range(MonsterManager.monsters.size()):
		if MonsterManager.monsters[i].monster_name == monster_name:
			idx = i
			break
	if idx == -1:
		push_error("Monsters.gd: no monster named '%s' found for removal" % monster_name)
		return
	_tokens[idx].queue_free()
	_tokens.remove_at(idx)

func _on_monsters_moved(move_data: Array) -> void:
	for entry in move_data:
		var idx: int = entry["monster_idx"]
		var path: Array = entry["path"]
		for i in range(1, path.size()):
			await _tokens[idx].move_to(_board.get_space_center(path[i])).finished
	_place_all_tokens()
	MonsterManager.phase_animation_done.emit()

func _place_all_tokens() -> void:
	if MonsterManager.monsters.size() != _tokens.size():
		push_error("Monsters.gd: token/monster count mismatch")
		return
	var positions := _compute_positions()
	for i in range(_tokens.size()):
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
