class_name PlayerData
extends Resource

@export var player_name: String = ""
@export var color: Color = Color.WHITE
var current_space_id: int = 0
var inventory: Array[ItemData] = []
var character: CharacterData = null

var display_name: String:
	get:
		if character != null:
			return character.character_name
		return player_name
