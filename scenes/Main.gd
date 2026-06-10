extends Node

const CAMERA_SPEED := 400.0

func _ready() -> void:
	GameManager.start_game(GameManager.pending_player_count)
	var monsters: Array[MonsterData] = []
	for path in GameManager.pending_monster_paths:
		var m := load(path) as MonsterData
		if m != null:
			monsters.append(m)
	var deck_data := load("res://resources/data/monster_deck.tres") as MonsterDeckData
	MonsterManager.setup(monsters, deck_data)
	$UI.setup(GameManager.players)
	$Players.setup(GameManager.players, $Board)
	$Monsters.setup(MonsterManager.monsters, $Board, $Board/Camera2D)
	var terror_meter := load("res://scenes/TerrorMeter.gd").new() as Node2D
	terror_meter.position = Vector2(250.0, 70.0)
	$Board.add_child(terror_meter)
	GameManager.turn_changed.connect(_on_turn_changed)
	_center_camera_on_player(GameManager.active_player_index)

func _on_turn_changed(player_index: int) -> void:
	_center_camera_on_player(player_index)

func _center_camera_on_player(player_index: int) -> void:
	if player_index < 0 or player_index >= GameManager.players.size():
		return
	var space_id := GameManager.players[player_index].current_space_id
	var space := GameManager.board_data.get_space(space_id) if GameManager.board_data != null else null
	if space == null:
		return
	var target := space.position + Vector2(50, 40)
	var tween := create_tween()
	tween.tween_property($Board/Camera2D, "position", target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	var camera := $Board/Camera2D as Camera2D
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAMERA_SPEED * delta
