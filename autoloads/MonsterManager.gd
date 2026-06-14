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
signal frenzy_changed

var monsters: Array[MonsterData] = []
var draw_pile: Array[MonsterCardData] = []
var discard_pile: Array[MonsterCardData] = []
var skip_next_phase: bool = false
var frenzied_monster_name: String = ""


func setup(monster_list: Array[MonsterData], deck_data: MonsterDeckData) -> void:
	monsters = monster_list
	draw_pile = deck_data.cards.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
	for monster in monsters:
		monster.current_space_id = monster.starting_space_id
		monster.dial_value = 0
	frenzied_monster_name = ""
	_update_frenzied_monster()
	GameManager.setup_mummy_puzzle()


func _update_frenzied_monster() -> void:
	var lowest := 999999
	var name := ""
	for m in monsters:
		if m.monster_name == "Bride":
			continue
		if m.frenzy_number < lowest:
			lowest = m.frenzy_number
			name = m.monster_name
	if name != frenzied_monster_name:
		frenzied_monster_name = name
		frenzy_changed.emit()


func remove_monster(monster_name: String) -> void:
	var removed := false
	for i in range(monsters.size() - 1, -1, -1):
		if monsters[i].monster_name == monster_name:
			monsters.remove_at(i)
			removed = true
			break
	if not removed:
		push_warning("MonsterManager.remove_monster: '%s' not found" % monster_name)
		return
	_update_frenzied_monster()


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
	var power_move_data: Array = []
	var attack_dice: Array = []
	var hit_spaces: Dictionary = {}   # space_id -> int
	# Pass 1: named monsters (skip Frenzy entry)
	for monster_name: String in card.monster_names:
		if monster_name == "Frenzy":
			continue
		var monster := _find_monster(monster_name)
		if monster == null:
			continue
		_process_monster_for_card(monster, card, move_data, power_move_data, attack_dice, hit_spaces, summary_parts)
	monsters_moved.emit(move_data)
	await phase_animation_done
	GameManager.check_frankenstein_meeting()
	if not attack_dice.is_empty():
		dice_rolled.emit(attack_dice)
		await dice_animation_done
	for space_id in hit_spaces:
		if GameManager.game_over:
			break
		space_attacked.emit(space_id as int, hit_spaces[space_id] as int)
		await hit_resolved
	if not power_move_data.is_empty():
		monsters_moved.emit(power_move_data)
		await phase_animation_done
		GameManager.check_frankenstein_meeting()

	# Pass 2: Frenzy monster (separate move+attack cycle so first kill doesn't block second)
	if card.monster_names.has("Frenzy") and frenzied_monster_name != "" and not GameManager.game_over:
		var frenzy_monster := _find_monster(frenzied_monster_name)
		if frenzy_monster != null:
			var frenzy_move: Array = []
			var frenzy_power_move: Array = []
			var frenzy_dice: Array = []
			var frenzy_hits: Dictionary = {}
			_process_monster_for_card(frenzy_monster, card, frenzy_move, frenzy_power_move, frenzy_dice, frenzy_hits, summary_parts)
			monsters_moved.emit(frenzy_move)
			await phase_animation_done
			GameManager.check_frankenstein_meeting()
			if not frenzy_dice.is_empty():
				dice_rolled.emit(frenzy_dice)
				await dice_animation_done
			for space_id in frenzy_hits:
				if GameManager.game_over:
					break
				space_attacked.emit(space_id as int, frenzy_hits[space_id] as int)
				await hit_resolved
			if not frenzy_power_move.is_empty():
				monsters_moved.emit(frenzy_power_move)
				await phase_animation_done
				GameManager.check_frankenstein_meeting()

	phase_completed.emit(" | ".join(summary_parts))


func _find_monster(monster_name: String) -> MonsterData:
	for m in monsters:
		if m.monster_name == monster_name:
			return m
	return null


func _process_monster_for_card(monster: MonsterData, card: MonsterCardData,
		move_data: Array, power_move_data: Array, attack_dice: Array, hit_spaces: Dictionary, summary_parts: Array) -> void:
	var allow_water := monster.can_move_through_water
	var target_space := _nearest_target_space(monster.current_space_id, allow_water)
	if target_space == -1:
		summary_parts.append(monster.monster_name + " didn't move")
		return
	var path := _bfs_path(monster.current_space_id, target_space, allow_water)
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
	var frank := _find_monster("Frankenstein")
	var bride := _find_monster("Bride")
	if frank != null and bride != null and frank.current_space_id == bride.current_space_id:
		summary_parts.append(monster.monster_name + " moved to " + dest_name + " (meeting!)")
		return
	var targets_here := false
	for p in GameManager.players:
		if p.current_space_id == destination:
			targets_here = true
			break
	if not targets_here:
		for v in VillagerManager.villagers:
			if (v as VillagerData).current_space_id == destination:
				targets_here = true
				break
	if not targets_here:
		summary_parts.append(monster.monster_name + " moved to " + dest_name)
		return
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
		var power_note := _trigger_power(monster, power_move_data)
		atk_text += " [POWER: " + power_note + "]"
		if monster.monster_name == "Wolfman":
			var extra := 0
			for p in GameManager.players:
				if p.current_space_id == destination:
					extra += 1
			for v in VillagerManager.villagers:
				if (v as VillagerData).current_space_id == destination:
					extra += 1
			if extra > 0:
				hit_spaces[destination] = (hit_spaces.get(destination, 0) as int) + extra
	summary_parts.append(atk_text)
	if hits > 0:
		hit_spaces[destination] = (hit_spaces.get(destination, 0) as int) + hits


func _run_card_logic(card: MonsterCardData, summary: Array[String]) -> void:
	match card.card_name:
		"Sunrise":
			_logic_sunrise(summary)
		"Form of the Bat":
			_logic_form_of_the_bat(summary)
		"Worried Fiancee":
			_logic_worried_fiancee(summary)
		"The Enthralled":
			_logic_the_enthralled(summary)
		"Insane Survivor":
			_logic_insane_survivor(summary)
		"Fortune Teller":
			_logic_fortune_teller(summary)
		"Egyptian Expert":
			_logic_egyptian_expert(summary)
		"The Ichthyologist":
			_logic_the_ichthyologist(summary)
		"Hurried Assistant":
			_logic_hurried_assistant(summary)
		"The Delivery":
			_logic_the_delivery(summary)
		"The Hunt Is On":
			_logic_the_hunt_is_on(summary)
		"On the Move":
			_logic_on_the_move(summary)
		"Reincarnated Soul":
			_logic_reincarnated_soul(summary)
		"The Meeting":
			_logic_the_meeting(summary)
		"The Innocent":
			_logic_the_innocent(summary)
		"Former Employer":
			_logic_former_employer(summary)
		"Retreat (Lagoon)":
			_logic_creature_retreat("Lagoon", summary)
		"Retreat (River)":
			_logic_creature_retreat("River", summary)
		"Retreat (Waterfront)":
			_logic_creature_retreat("Waterfront", summary)


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


func _logic_worried_fiancee(summary: Array[String]) -> void:
	var elizabeth: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Elizabeth":
			elizabeth = v as VillagerData
			break
	if elizabeth == null:
		return
	var mansion_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Mansion":
			mansion_id = space.id
			break
	if mansion_id == -1:
		return
	elizabeth.current_space_id = mansion_id
	VillagerManager.villagers_changed.emit()
	summary.append("Elizabeth appeared at the Mansion")


func _logic_the_enthralled(summary: Array[String]) -> void:
	var lucy: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Lucy":
			lucy = v as VillagerData
			break
	if lucy == null:
		return
	var theatre_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Theatre":
			theatre_id = space.id
			break
	if theatre_id == -1:
		return
	lucy.current_space_id = theatre_id
	VillagerManager.villagers_changed.emit()
	summary.append("Lucy appeared at the Theatre")


func _logic_insane_survivor(summary: Array[String]) -> void:
	var renfield: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Renfield":
			renfield = v as VillagerData
			break
	if renfield == null:
		return
	var docks_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Docks":
			docks_id = space.id
			break
	if docks_id == -1:
		return
	renfield.current_space_id = docks_id
	VillagerManager.villagers_changed.emit()
	summary.append("Renfield appeared at the Docks")


func _logic_fortune_teller(summary: Array[String]) -> void:
	var maleva: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Maleva":
			maleva = v as VillagerData
			break
	if maleva == null:
		return
	var camp_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Camp":
			camp_id = space.id
			break
	if camp_id == -1:
		return
	maleva.current_space_id = camp_id
	VillagerManager.villagers_changed.emit()
	summary.append("Maleva appeared at the Camp")


func _logic_former_employer(summary: Array[String]) -> void:
	var cranley: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Dr. Cranley":
			cranley = v as VillagerData
			break
	if cranley == null:
		return
	var lab_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Laboratory":
			lab_id = space.id
			break
	if lab_id == -1:
		return
	cranley.current_space_id = lab_id
	VillagerManager.villagers_changed.emit()
	summary.append("Dr. Cranley appeared at the Laboratory")


func _logic_the_innocent(summary: Array[String]) -> void:
	var maria: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Maria":
			maria = v as VillagerData
			break
	if maria == null:
		return
	var barn_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Barn":
			barn_id = space.id
			break
	if barn_id == -1:
		return
	maria.current_space_id = barn_id
	VillagerManager.villagers_changed.emit()
	summary.append("Maria appeared at the Barn")


func _logic_the_delivery(summary: Array[String]) -> void:
	var wilbur: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Wilbur & Chick":
			wilbur = v as VillagerData
			break
	if wilbur == null:
		return
	var shop_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Shop":
			shop_id = space.id
			break
	if shop_id == -1:
		return
	wilbur.current_space_id = shop_id
	VillagerManager.villagers_changed.emit()
	summary.append("Wilbur & Chick appeared at the Shop")


func _logic_hurried_assistant(summary: Array[String]) -> void:
	var fritz: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Fritz":
			fritz = v as VillagerData
			break
	if fritz == null:
		return
	var tower_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Tower":
			tower_id = space.id
			break
	if tower_id == -1:
		return
	fritz.current_space_id = tower_id
	VillagerManager.villagers_changed.emit()
	summary.append("Fritz appeared at the Tower")


func _logic_the_ichthyologist(summary: Array[String]) -> void:
	var reed: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Dr. Reed":
			reed = v as VillagerData
			break
	if reed == null:
		return
	var institute_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Institute":
			institute_id = space.id
			break
	if institute_id == -1:
		return
	reed.current_space_id = institute_id
	VillagerManager.villagers_changed.emit()
	summary.append("Dr. Reed appeared at the Institute")


func _logic_on_the_move(summary: Array[String]) -> void:
	var eligible: Array[MonsterData] = []
	for m in monsters:
		if m.monster_name != "Bride":
			eligible.append(m)
	if eligible.size() > 1:
		var sorted := eligible.duplicate()
		sorted.sort_custom(func(a: MonsterData, b: MonsterData) -> bool:
			return a.frenzy_number < b.frenzy_number)
		var current_idx := 0
		for i in range(sorted.size()):
			if (sorted[i] as MonsterData).monster_name == frenzied_monster_name:
				current_idx = i
				break
		var next_name: String = (sorted[(current_idx + 1) % sorted.size()] as MonsterData).monster_name
		frenzied_monster_name = next_name
		frenzy_changed.emit()
		summary.append("Frenzy marker moved to " + frenzied_monster_name)
	elif eligible.size() == 1:
		summary.append("Frenzy marker stays on " + frenzied_monster_name)
	if GameManager.board_data == null:
		return
	var villager_snapshot := VillagerManager.villagers.duplicate()
	var moved := 0
	for v_ref in villager_snapshot:
		var v := v_ref as VillagerData
		if not VillagerManager.villagers.has(v):
			continue
		if v.current_space_id < 0 or v.current_space_id == v.target_space_id:
			continue
		var path := _bfs_path(v.current_space_id, v.target_space_id)
		if path.size() >= 2:
			VillagerManager.move_villager(v, path[1])
			moved += 1
	if moved > 0:
		summary.append(str(moved) + " villager(s) moved toward their targets")


func _logic_the_hunt_is_on(summary: Array[String]) -> void:
	var wolfman: MonsterData = null
	for m in monsters:
		if m.monster_name == "Wolfman":
			wolfman = m
			break
	if wolfman == null:
		return
	if GameManager.wolfman_hunted_player < 0:
		GameManager.wolfman_hunted_player = GameManager.active_player_index
		GameManager.wolfman_hunted_changed.emit(GameManager.wolfman_hunted_player)
		summary.append(GameManager.players[GameManager.wolfman_hunted_player].display_name + " is now being hunted")
	var hunted_space := GameManager.players[GameManager.wolfman_hunted_player].current_space_id
	var path := _bfs_path(wolfman.current_space_id, hunted_space)
	if path.size() < 2:
		summary.append("Wolfman is already at the hunted player's location")
		return
	var steps := mini(3, path.size() - 1)
	wolfman.current_space_id = path[steps]
	var dest_space := GameManager.board_data.get_space(wolfman.current_space_id)
	var dest_name := dest_space.name if dest_space != null else str(wolfman.current_space_id)
	summary.append("Wolfman stalked " + str(steps) + " step(s) toward " +
			GameManager.players[GameManager.wolfman_hunted_player].display_name +
			", now at " + dest_name)
	monster_relocated.emit()


func _logic_egyptian_expert(summary: Array[String]) -> void:
	var pearson: VillagerData = null
	for v in VillagerManager.villagers:
		if (v as VillagerData).villager_name == "Prof. Pearson":
			pearson = v as VillagerData
			break
	if pearson == null:
		return
	var cave_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == "Cave":
			cave_id = space.id
			break
	if cave_id == -1:
		return
	pearson.current_space_id = cave_id
	VillagerManager.villagers_changed.emit()
	summary.append("Prof. Pearson appeared at the Cave")


func _logic_reincarnated_soul(summary: Array[String]) -> void:
	var mummy: MonsterData = null
	for m in monsters:
		if m.monster_name == "Mummy":
			mummy = m
			break
	if mummy == null:
		return
	if GameManager.mummy_soul_player < 0:
		GameManager.mummy_soul_player = GameManager.active_player_index
		GameManager.mummy_soul_changed.emit(GameManager.mummy_soul_player)
		summary.append(GameManager.players[GameManager.mummy_soul_player].display_name + " received the Soul Token")
	var soul_player := GameManager.players[GameManager.mummy_soul_player]
	var path := _bfs_path(soul_player.current_space_id, mummy.current_space_id)
	if path.size() < 2:
		summary.append(soul_player.display_name + " is already at the Mummy's location")
		return
	var steps := mini(3, path.size() - 1)
	soul_player.current_space_id = path[steps]
	GameManager.player_moved.emit(GameManager.mummy_soul_player, soul_player.current_space_id)
	var dest_space := GameManager.board_data.get_space(soul_player.current_space_id)
	var dest_name := dest_space.name if dest_space != null else str(soul_player.current_space_id)
	summary.append(soul_player.display_name + " drawn " + str(steps) + " step(s) toward the Mummy, now at " + dest_name)


func _logic_the_meeting(summary: Array[String]) -> void:
	var frank: MonsterData = null
	var bride: MonsterData = null
	for m in monsters:
		if m.monster_name == "Frankenstein": frank = m
		elif m.monster_name == "Bride": bride = m
	if frank == null or bride == null:
		return
	if bride.current_space_id == frank.current_space_id:
		summary.append("The Bride is already with Frankenstein")
		GameManager.check_frankenstein_meeting()
		return
	var path := _bfs_path(bride.current_space_id, frank.current_space_id)
	if path.size() < 2:
		summary.append("The Bride cannot reach Frankenstein")
		return
	var steps := mini(2, path.size() - 1)
	bride.current_space_id = path[steps]
	monster_relocated.emit()
	var dest_space := GameManager.board_data.get_space(bride.current_space_id)
	var dest_name := dest_space.name if dest_space != null else str(bride.current_space_id)
	summary.append("The Bride moved " + str(steps) + " step(s) toward Frankenstein, now at " + dest_name)
	GameManager.check_frankenstein_meeting()


func _logic_creature_retreat(space_name: String, summary: Array[String]) -> void:
	var creature: MonsterData = null
	for m in monsters:
		if m.monster_name == "Creature":
			creature = m
			break
	if creature == null:
		return
	if GameManager.board_data == null:
		return
	var target_id := -1
	for space in GameManager.board_data.spaces:
		if space.name == space_name:
			target_id = space.id
			break
	if target_id == -1:
		return
	creature.current_space_id = target_id
	monster_relocated.emit()
	summary.append("Creature retreated to the " + space_name)


func _nearest_target_space(from_id: int, allow_water: bool = false) -> int:
	if GameManager.board_data == null:
		return -1
	var target_spaces: Dictionary = {}
	for p in GameManager.players:
		if p.current_space_id >= 0:
			target_spaces[p.current_space_id] = true
	for v in VillagerManager.villagers:
		if (v as VillagerData).current_space_id >= 0:
			target_spaces[(v as VillagerData).current_space_id] = true
	if target_spaces.is_empty():
		return -1
	if target_spaces.has(from_id):
		return from_id
	var queue: Array[int] = [from_id]
	var visited: Dictionary = {from_id: true}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var space := GameManager.board_data.get_space(current)
		if space == null:
			continue
		for neighbor_id: int in space.neighbors:
			if not allow_water and GameManager._is_water(neighbor_id):
				continue
			if target_spaces.has(neighbor_id):
				return neighbor_id
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)
	return -1


func _bfs_path(from_id: int, to_id: int, allow_water: bool = false) -> Array[int]:
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
			if not allow_water and GameManager._is_water(neighbor_id):
				continue
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


func _trigger_power(monster: MonsterData, power_move_data: Array) -> String:
	match monster.monster_name:
		"Dracula":
			return _power_dracula(monster)
		"Wolfman":
			return _power_wolfman(monster)
		"Mummy":
			return _power_mummy(monster)
		"Frankenstein", "Bride":
			return _power_frankenstein_or_bride(power_move_data)
		"Creature":
			return _power_creature()
		"Invisible Man":
			return _power_invisible_man(monster, power_move_data)
	return ""


func _power_wolfman(_wolfman: MonsterData) -> String:
	return "all targets at this location take a hit"


func _power_mummy(_mummy: MonsterData) -> String:
	if GameManager.mummy_slot_contents.is_empty():
		return "no scarab tokens"
	var min_token := 999
	var min_idx := -1
	for i in range(GameManager.mummy_slot_contents.size()):
		var token: int = GameManager.mummy_slot_contents[i]
		if token > 0 and GameManager.mummy_slot_revealed[i] and token < min_token:
			min_token = token
			min_idx = i
	if min_idx < 0:
		return "no revealed scarab tokens to flip"
	GameManager.mummy_slot_revealed[min_idx] = false
	GameManager.mummy_changed.emit()
	return "scarab token " + str(min_token) + " flipped face-down"


func _power_frankenstein_or_bride(power_move_data: Array) -> String:
	var frank: MonsterData = null
	var bride: MonsterData = null
	for m in monsters:
		if m.monster_name == "Frankenstein": frank = m
		elif m.monster_name == "Bride": bride = m
	if frank == null or bride == null:
		return "power: one of the pair is missing"
	if frank.current_space_id == bride.current_space_id:
		return "Bride is already with Frankenstein"
	var path := _bfs_path(bride.current_space_id, frank.current_space_id)
	if path.size() < 2:
		return "Bride cannot reach Frankenstein"
	var from_id := bride.current_space_id
	bride.current_space_id = path[1]
	power_move_data.append({
		"monster_idx": monsters.find(bride),
		"path": [from_id, path[1]]
	})
	var dest_space := GameManager.board_data.get_space(bride.current_space_id)
	var dest_name := dest_space.name if dest_space != null else str(bride.current_space_id)
	return "Bride moved 1 step toward Frankenstein, now at " + dest_name


func _power_creature() -> String:
	if GameManager.creature_path_index > 0:
		GameManager.creature_path_index -= 1
		GameManager.creature_changed.emit()
		return "indicator moved back (now at position %d)" % GameManager.creature_path_index
	return "indicator is already at the start"


func _power_invisible_man(monster: MonsterData, power_move_data: Array) -> String:
	var villager_spaces: Array[int] = []
	for v in VillagerManager.villagers:
		var vs := (v as VillagerData).current_space_id
		if vs >= 0:
			villager_spaces.append(vs)
	if villager_spaces.is_empty():
		return "no villagers on board"
	var best_target := -1
	var best_dist := 999999
	for vs in villager_spaces:
		var p := _bfs_path(monster.current_space_id, vs)
		if p.size() > 1 and p.size() - 1 < best_dist:
			best_dist = p.size() - 1
			best_target = vs
	if best_target == -1:
		return "no villager reachable"
	var path := _bfs_path(monster.current_space_id, best_target)
	if path.size() < 2:
		return "already at villager location"
	var steps := mini(2, path.size() - 1)
	monster.current_space_id = path[steps]
	power_move_data.append({
		"monster_idx": monsters.find(monster),
		"path": path.slice(0, steps + 1)
	})
	var dest_space := GameManager.board_data.get_space(monster.current_space_id)
	var dest_name := dest_space.name if dest_space != null else str(monster.current_space_id)
	return "moved " + str(steps) + " step(s) toward nearest villager, now at " + dest_name


func _power_dracula(dracula: MonsterData) -> String:
	if GameManager.players.is_empty():
		return ""
	var target := GameManager.players[GameManager.active_player_index]
	target.current_space_id = dracula.current_space_id
	GameManager.player_moved.emit(GameManager.active_player_index, dracula.current_space_id)
	var space := GameManager.board_data.get_space(dracula.current_space_id)
	var space_name: String = space.name if space != null else str(dracula.current_space_id)
	return target.display_name + " dragged to " + space_name
