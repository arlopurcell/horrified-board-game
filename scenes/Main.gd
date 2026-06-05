extends Node

const PLAYER_COUNT := 4

func _ready() -> void:
	GameManager.start_game(PLAYER_COUNT)
	$UI.setup(GameManager.players)
	$Players.setup(GameManager.players, $Board)
