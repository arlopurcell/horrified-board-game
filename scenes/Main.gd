extends Node

const PLAYER_COUNT := 4
const CAMERA_SPEED := 400.0

func _ready() -> void:
	GameManager.start_game(PLAYER_COUNT)
	var base_monster := load("res://resources/data/base_monster.tres") as MonsterData
	var deck_data := load("res://resources/data/monster_deck.tres") as MonsterDeckData
	MonsterManager.setup([base_monster], deck_data)
	$UI.setup(GameManager.players)
	$Players.setup(GameManager.players, $Board)
	$Monsters.setup(MonsterManager.monsters, $Board)

func _process(delta: float) -> void:
	var camera := $Board/Camera2D as Camera2D
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAMERA_SPEED * delta
