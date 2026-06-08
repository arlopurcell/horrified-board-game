extends Node

signal monsters_moved(move_data: Array)
signal phase_animation_done
signal phase_completed(summary: String)

var monsters: Array[MonsterData] = []
var draw_pile: Array[MonsterCardData] = []
var discard_pile: Array[MonsterCardData] = []


func setup(monster_list: Array[MonsterData], deck_data: MonsterDeckData) -> void:
	monsters = monster_list
	draw_pile = deck_data.cards.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
	for monster in monsters:
		monster.current_space_id = monster.starting_space_id


func run_phase() -> void:
	if monsters.is_empty():
		monsters_moved.emit([])
		return
	if draw_pile.is_empty():
		draw_pile = discard_pile.duplicate()
		draw_pile.shuffle()
		discard_pile.clear()
	if draw_pile.is_empty():
		monsters_moved.emit([])
		phase_completed.emit("")
		return
	var card := draw_pile.pop_front() as MonsterCardData
	discard_pile.append(card)
	GameManager.draw_items_to_board(card.items_to_draw)
	var summary_parts: Array[String] = []
	var move_data: Array = []
	for monster_name: String in card.monster_names:
		var monster: MonsterData = null
		for m in monsters:
			if m.monster_name == monster_name:
				monster = m
				break
		if monster == null:
			push_warning("MonsterManager: card references unknown monster '%s'" % monster_name)
			continue
		var target_space := _nearest_player_space(monster.current_space_id)
		if target_space == -1:
			summary_parts.append(monster.monster_name + " didn't move")
			continue
		var path := _bfs_path(monster.current_space_id, target_space)
		var destination: int
		if path.is_empty():
			destination = monster.current_space_id
		else:
			var dest_idx := mini(card.move_steps, path.size() - 1)
			destination = path[dest_idx]
			if dest_idx > 0:
				move_data.append({
					"monster_idx": monsters.find(monster),
					"path": path.slice(0, dest_idx + 1)
				})
		monster.current_space_id = destination
		var dest_space := GameManager.board_data.get_space(destination)
		var dest_name := dest_space.name if dest_space != null else str(destination)
		var players_here := false
		for p in GameManager.players:
			if p.current_space_id == destination:
				players_here = true
				break
		if not players_here:
			summary_parts.append(monster.monster_name + " moved to " + dest_name)
		else:
			var hits := _roll_dice(card.attack_dice)
			var die_word := "die" if card.attack_dice == 1 else "dice"
			var hit_word := "hit" if hits == 1 else "hits"
			summary_parts.append(monster.monster_name + " moved to " + dest_name +
				", rolled " + str(card.attack_dice) + " " + die_word +
				" → " + str(hits) + " " + hit_word)
	monsters_moved.emit(move_data)
	phase_completed.emit(" | ".join(summary_parts))


func _nearest_player_space(from_id: int) -> int:
	if GameManager.players.is_empty() or GameManager.board_data == null:
		return -1
	var player_spaces: Dictionary = {}
	for p in GameManager.players:
		player_spaces[p.current_space_id] = true
	if player_spaces.has(from_id):
		return from_id
	var queue: Array[int] = [from_id]
	var visited: Dictionary = {from_id: true}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var space := GameManager.board_data.get_space(current)
		if space == null:
			continue
		for neighbor_id: int in space.neighbors:
			if player_spaces.has(neighbor_id):
				return neighbor_id
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	return -1


func _bfs_path(from_id: int, to_id: int) -> Array[int]:
	if from_id == to_id:
		return [from_id]
	if GameManager.board_data == null:
		return []
	var queue: Array[int] = [from_id]
	var visited: Dictionary = {from_id: true}
	var parent: Dictionary = {}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var space := GameManager.board_data.get_space(current)
		if space == null:
			continue
		for neighbor_id: int in space.neighbors:
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			parent[neighbor_id] = current
			if neighbor_id == to_id:
				var path: Array[int] = []
				var node := to_id
				while node != from_id:
					path.push_front(node)
					node = parent[node] as int
				path.push_front(from_id)
				return path
			queue.append(neighbor_id)
	return []


func _roll_dice(count: int) -> int:
	var hits := 0
	for i in range(count):
		if randi() % 6 + 1 <= 3:
			hits += 1
	return hits
