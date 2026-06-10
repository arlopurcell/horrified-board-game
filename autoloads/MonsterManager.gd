extends Node

signal monsters_moved(move_data: Array)
signal phase_animation_done
signal phase_completed(summary: String)
signal dice_rolled(results: Array)
signal dice_animation_done
signal card_drawn(card: MonsterCardData, item_info: Array)
signal card_display_done
signal monster_relocated
signal space_attacked(space_id: int, num_hits: int)
signal hit_resolved

var monsters: Array[MonsterData] = []
var draw_pile: Array[MonsterCardData] = []
var discard_pile: Array[MonsterCardData] = []
var skip_next_phase: bool = false


func setup(monster_list: Array[MonsterData], deck_data: MonsterDeckData) -> void:
	monsters = monster_list
	draw_pile = deck_data.cards.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
	for monster in monsters:
		monster.current_space_id = monster.starting_space_id


func remove_monster(monster_name: String) -> void:
	for i in range(monsters.size() - 1, -1, -1):
		if monsters[i].monster_name == monster_name:
			monsters.remove_at(i)
			return
	push_warning("MonsterManager.remove_monster: '%s' not found" % monster_name)


func run_phase() -> void:
	if skip_next_phase:
		skip_next_phase = false
		monsters_moved.emit([])
		await phase_animation_done
		phase_completed.emit("Monster phase skipped")
		return
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
	var item_info := GameManager.peek_draw_items(card.items_to_draw)
	card_drawn.emit(card, item_info)
	await card_display_done
	GameManager.draw_items_to_board(card.items_to_draw)
	var summary_parts: Array[String] = []
	_run_card_logic(card, summary_parts)
	await get_tree().create_timer(1.0).timeout
	var move_data: Array = []
	var attack_dice: Array = []
	var hit_spaces: Dictionary = {}   # space_id -> int
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
			var dice_results := _roll_dice(card.attack_dice)
			attack_dice.append_array(dice_results)
			var hits := dice_results.count("hit")
			var power_triggered := dice_results.has("power")
			var die_word := "die" if card.attack_dice == 1 else "dice"
			var hit_word := "hit" if hits == 1 else "hits"
			var atk_text := monster.monster_name + " moved to " + dest_name + \
				", rolled " + str(card.attack_dice) + " " + die_word + \
				" → " + str(hits) + " " + hit_word
			if power_triggered:
				var power_note := _trigger_power(monster)
				atk_text += " [POWER: " + power_note + "]"
			summary_parts.append(atk_text)
			if hits > 0:
				hit_spaces[destination] = (hit_spaces.get(destination, 0) as int) + hits
	monsters_moved.emit(move_data)
	await phase_animation_done
	if not attack_dice.is_empty():
		dice_rolled.emit(attack_dice)
		await dice_animation_done
	for space_id in hit_spaces:
		if GameManager.game_over:
			break
		space_attacked.emit(space_id as int, hit_spaces[space_id] as int)
		await hit_resolved
	phase_completed.emit(" | ".join(summary_parts))


func _run_card_logic(card: MonsterCardData, summary: Array[String]) -> void:
	match card.card_name:
		"Sunrise":
			_logic_sunrise(summary)
		"Form of the Bat":
			_logic_form_of_the_bat(summary)


func _logic_sunrise(summary: Array[String]) -> void:
	var dracula: MonsterData = null
	for m in monsters:
		if m.monster_name == "Dracula":
			dracula = m
			break
	if dracula == null:
		return
	if GameManager.board_data == null:
		return
	var crypt_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Crypt":
			crypt_id = space.id
			break
	if crypt_id == -1:
		return
	dracula.current_space_id = crypt_id
	monster_relocated.emit()
	summary.append("Dracula retreated to the Crypt")


func _logic_form_of_the_bat(summary: Array[String]) -> void:
	var dracula: MonsterData = null
	for m in monsters:
		if m.monster_name == "Dracula":
			dracula = m
			break
	if dracula == null:
		return
	if GameManager.players.is_empty():
		return
	var player := GameManager.players[GameManager.active_player_index]
	dracula.current_space_id = player.current_space_id
	monster_relocated.emit()
	var space := GameManager.board_data.get_space(player.current_space_id) if GameManager.board_data != null else null
	var space_name := space.name if space != null else str(player.current_space_id)
	summary.append("Dracula moved to " + space_name + " (" + player.display_name + "'s location)")


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


func _roll_dice(count: int) -> Array[String]:
	var results: Array[String] = []
	for i in range(count):
		var face := randi() % 6
		if face < 2:        # 0-1: hit   (2/6)
			results.append("hit")
		elif face == 5:     # 5:   power (1/6)
			results.append("power")
		else:               # 2-4: miss  (3/6)
			results.append("miss")
	return results


func _trigger_power(monster: MonsterData) -> String:
	match monster.monster_name:
		"Dracula":
			return _power_dracula(monster)
	return ""


func _power_dracula(dracula: MonsterData) -> String:
	if GameManager.players.is_empty():
		return ""
	var target := GameManager.players[GameManager.active_player_index]
	target.current_space_id = dracula.current_space_id
	GameManager.player_moved.emit(GameManager.active_player_index, dracula.current_space_id)
	var space := GameManager.board_data.get_space(dracula.current_space_id)
	var space_name: String = space.name if space != null else str(dracula.current_space_id)
	return target.display_name + " dragged to " + space_name
