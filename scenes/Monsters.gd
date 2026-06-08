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
	_place_all_tokens()

func _on_monsters_moved() -> void:
	_place_all_tokens()

func _place_all_tokens() -> void:
	if MonsterManager.monsters.size() != _tokens.size():
		push_error("Monsters.gd: token/monster count mismatch")
		return
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
			_tokens[idx].move_to(base + _cluster_offset(j, occupants.size()))

func _cluster_offset(slot: int, total: int) -> Vector2:
	if total == 1:
		return Vector2.ZERO
	var angle := (TAU / total) * slot
	return Vector2(cos(angle), sin(angle)) * 12.0
