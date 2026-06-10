extends Node

signal villagers_changed
signal villager_rescued(villager_name: String)

var villagers: Array[VillagerData] = []


func setup(list: Array[VillagerData]) -> void:
	villagers = list


func get_villagers_at(space_id: int) -> Array:
	var result: Array = []
	for v in villagers:
		if (v as VillagerData).current_space_id == space_id:
			result.append(v)
	return result


func move_villager(villager: VillagerData, space_id: int) -> void:
	villager.current_space_id = space_id
	villagers_changed.emit()
	if villager.current_space_id == villager.target_space_id:
		_rescue(villager)


func kill_villager(villager: VillagerData) -> void:
	villagers.erase(villager)
	villagers_changed.emit()
	GameManager.terror_level += 1
	GameManager.terror_changed.emit(GameManager.terror_level)
	if GameManager.terror_level >= GameManager.TERROR_MAX:
		GameManager.game_over = true
		GameManager.game_lost.emit()


func _rescue(villager: VillagerData) -> void:
	villagers.erase(villager)
	villagers_changed.emit()
	villager_rescued.emit(villager.villager_name)
	GameManager.add_perk_card_to_pool()
