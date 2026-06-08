class_name BoardData
extends Resource

@export var spaces: Array[SpaceData] = []

func get_space(space_id: int) -> SpaceData:
	for space in spaces:
		if space.id == space_id:
			return space
	return null
