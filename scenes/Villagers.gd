extends Node

const VillagerTokenScene := preload("res://scenes/VillagerToken.tscn")

var _villagers: Array[VillagerData] = []
var _tokens: Array[VillagerToken] = []
var _board: Board = null
var _animating: Dictionary = {}  # VillagerData -> true while tween is running


func setup(villager_list: Array[VillagerData], board: Board) -> void:
	_board = board
	_villagers = villager_list.duplicate()
	for v in _villagers:
		_add_token(v as VillagerData)
	VillagerManager.villager_moved.connect(_on_villager_moved)
	VillagerManager.villagers_changed.connect(_on_villagers_changed)
	_place_all_tokens()


func _add_token(villager: VillagerData) -> void:
	var token: VillagerToken = VillagerTokenScene.instantiate()
	add_child(token)
	token.setup(villager)
	_tokens.append(token)


func _on_villager_moved(villager: VillagerData) -> void:
	var idx := _villagers.find(villager)
	if idx < 0:
		return
	var positions := _compute_positions()
	_animating[villager] = true
	var tween := _tokens[idx].move_to(positions[idx])
	tween.finished.connect(func(): _animating.erase(villager))


func _on_villagers_changed() -> void:
	var i := _villagers.size() - 1
	while i >= 0:
		if not VillagerManager.villagers.has(_villagers[i]):
			_tokens[i].queue_free()
			_tokens.remove_at(i)
			_villagers.remove_at(i)
		i -= 1
	_place_all_tokens()


func _place_all_tokens() -> void:
	var positions := _compute_positions()
	for i in range(_tokens.size()):
		if _animating.has(_villagers[i]):
			continue
		var on_board := _villagers[i].current_space_id >= 0
		_tokens[i].visible = on_board
		if on_board:
			_tokens[i].position = positions[i]


func _compute_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.resize(_tokens.size())
	var by_space: Dictionary = {}
	for i in range(_villagers.size()):
		var sid := _villagers[i].current_space_id
		if sid not in by_space:
			by_space[sid] = []
		by_space[sid].append(i)
	for space_id in by_space:
		var occupants: Array = by_space[space_id]
		var base := _board.get_space_center(space_id) + Vector2(26.0, 0.0)
		for j in range(occupants.size()):
			var idx: int = occupants[j]
			positions[idx] = base + _cluster_offset(j, occupants.size())
	return positions


func _cluster_offset(slot: int, total: int) -> Vector2:
	if total == 1:
		return Vector2.ZERO
	var angle := (TAU / total) * slot
	return Vector2(cos(angle), sin(angle)) * 8.0
