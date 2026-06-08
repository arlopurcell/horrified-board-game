# Movement Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Animate player and monster token movement — players slide to their destination on each step, monsters hop through each intermediate space one at a time before the next monster moves.

**Architecture:** `PlayerToken.move_to()` and `MonsterToken.move_to()` return a `Tween` instead of teleporting. `MonsterManager.run_phase()` emits full path data per monster; `Monsters.gd` animates them sequentially using `await`. `GameManager.end_turn()` becomes a coroutine that awaits `phase_animation_done` before advancing the turn.

**Tech Stack:** Godot 4 GDScript — `Tween`, `await`, typed `Array[Vector2]`, `Dictionary`

---

## File Map

| File | Change |
|------|--------|
| `scenes/PlayerToken.gd` | `move_to()` creates and returns a Tween |
| `scenes/MonsterToken.gd` | `move_to()` creates and returns a Tween |
| `autoloads/MonsterManager.gd` | Change `monsters_moved` signature; add `phase_animation_done`; emit path data from `run_phase()` |
| `scenes/Players.gd` | Extract `_compute_positions()`; animate moved token; instant-reposition others |
| `scenes/Monsters.gd` | Extract `_compute_positions()`; animate moves sequentially; emit `phase_animation_done` |
| `autoloads/GameManager.gd` | Add `phase_running` flag; make `end_turn()` a coroutine |
| `scenes/UI.gd` | Disable buttons on end turn press; re-enable on `turn_changed` |

---

### Task 1: Animate PlayerToken

**Files:**
- Modify: `scenes/PlayerToken.gd`

- [ ] **Step 1: Replace `move_to()` with a tween**

Replace the body of `PlayerToken.gd` with:

```gdscript
class_name PlayerToken
extends Node2D

const RADIUS := 14.0
const BORDER_COLOR := Color(0.353, 0.235, 0.1, 1)

var _color: Color = Color.WHITE

func setup(data: PlayerData) -> void:
	_color = data.color
	queue_redraw()

func move_to(world_pos: Vector2) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, _color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BORDER_COLOR, 2.0)
```

- [ ] **Step 2: Commit**

```bash
git add scenes/PlayerToken.gd
git commit -m "feat: animate PlayerToken.move_to with tween"
```

---

### Task 2: Animate MonsterToken

**Files:**
- Modify: `scenes/MonsterToken.gd`

- [ ] **Step 1: Replace `move_to()` with a tween**

Replace the body of `MonsterToken.gd` with:

```gdscript
class_name MonsterToken
extends Node2D

const RADIUS := 14.0
const FILL_COLOR := Color(0.15, 0.10, 0.10)
const BORDER_COLOR := Color(0.80, 0.10, 0.10)

func setup(_data: MonsterData) -> void:
	queue_redraw()

func move_to(world_pos: Vector2) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL_COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, BORDER_COLOR, 2.0)
```

- [ ] **Step 2: Commit**

```bash
git add scenes/MonsterToken.gd
git commit -m "feat: animate MonsterToken.move_to with tween"
```

---

### Task 3: Update MonsterManager signals and emit path data

**Files:**
- Modify: `autoloads/MonsterManager.gd`

`monsters_moved` gains a parameter carrying per-monster animation paths. A new `phase_animation_done` signal is added so `GameManager` can await animation completion. `run_phase()` builds the path data and emits it.

- [ ] **Step 1: Replace the full contents of `MonsterManager.gd`**

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add autoloads/MonsterManager.gd
git commit -m "feat: emit path data and phase_animation_done from MonsterManager"
```

---

### Task 4: Animate player token in Players.gd

**Files:**
- Modify: `scenes/Players.gd`

Extract position computation into `_compute_positions()`. On `player_moved`, animate only the moved token and instantly reposition any others that shifted due to stacking. On `turn_changed`, keep the existing instant full placement.

- [ ] **Step 1: Replace the full contents of `Players.gd`**

```gdscript
extends Node

const PlayerTokenScene := preload("res://scenes/PlayerToken.tscn")

var _tokens: Array[PlayerToken] = []
var _board: Board = null

func setup(player_list: Array[PlayerData], board: Board) -> void:
	_board = board
	for i in range(player_list.size()):
		var token: PlayerToken = PlayerTokenScene.instantiate()
		add_child(token)
		token.setup(player_list[i])
		_tokens.append(token)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.turn_changed.connect(_on_turn_changed)
	_place_all_tokens()

func _on_player_moved(player_index: int, _space_id: int) -> void:
	var positions := _compute_positions()
	await _tokens[player_index].move_to(positions[player_index]).finished
	for i in range(_tokens.size()):
		if i != player_index:
			_tokens[i].position = positions[i]

func _on_turn_changed(_player_index: int) -> void:
	_place_all_tokens()

func _place_all_tokens() -> void:
	if GameManager.players.size() != _tokens.size():
		push_error("Players.gd: token/player count mismatch")
		return
	var positions := _compute_positions()
	for i in range(_tokens.size()):
		_tokens[i].position = positions[i]

func _compute_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.resize(_tokens.size())
	var by_space: Dictionary = {}
	for i in range(GameManager.players.size()):
		var sid := GameManager.players[i].current_space_id
		if sid not in by_space:
			by_space[sid] = []
		by_space[sid].append(i)
	for space_id in by_space:
		var occupants: Array = by_space[space_id]
		var base := _board.get_space_center(space_id)
		for j in range(occupants.size()):
			var idx: int = occupants[j]
			positions[idx] = base + _cluster_offset(j, occupants.size())
	return positions

func _cluster_offset(slot: int, total: int) -> Vector2:
	if total == 1:
		return Vector2.ZERO
	var angle := (TAU / total) * slot
	return Vector2(cos(angle), sin(angle)) * 12.0
```

- [ ] **Step 2: Run the game and verify**

Start a 2-player game and move a player. The token should smoothly slide to the destination (0.25s, ease-in-out). Other tokens should not visibly jump.

- [ ] **Step 3: Commit**

```bash
git add scenes/Players.gd
git commit -m "feat: animate player token movement"
```

---

### Task 5: Animate monster tokens sequentially in Monsters.gd

**Files:**
- Modify: `scenes/Monsters.gd`

Receive `move_data` from `monsters_moved`. For each monster in order, await each hop. After all monsters finish, instantly reposition all tokens for stacking, then emit `phase_animation_done`.

- [ ] **Step 1: Replace the full contents of `Monsters.gd`**

```gdscript
extends Node

const MonsterTokenScene := preload("res://scenes/MonsterToken.tscn")

var _tokens: Array[MonsterToken] = []
var _board: Board = null

func setup(monster_list: Array[MonsterData], board: Board) -> void:
	_board = board
	for monster in monster_list:
		var token: MonsterToken = MonsterTokenScene.instantiate()
		add_child(token)
		token.setup(monster)
		_tokens.append(token)
	MonsterManager.monsters_moved.connect(_on_monsters_moved)
	_place_all_tokens()

func _on_monsters_moved(move_data: Array) -> void:
	for entry in move_data:
		var idx: int = entry["monster_idx"]
		var path: Array = entry["path"]
		for i in range(1, path.size()):
			await _tokens[idx].move_to(_board.get_space_center(path[i])).finished
	_place_all_tokens()
	MonsterManager.phase_animation_done.emit()

func _place_all_tokens() -> void:
	if MonsterManager.monsters.size() != _tokens.size():
		push_error("Monsters.gd: token/monster count mismatch")
		return
	var positions := _compute_positions()
	for i in range(_tokens.size()):
		_tokens[i].position = positions[i]

func _compute_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.resize(_tokens.size())
	var by_space: Dictionary = {}
	for i in range(MonsterManager.monsters.size()):
		var sid := MonsterManager.monsters[i].current_space_id
		if sid not in by_space:
			by_space[sid] = []
		by_space[sid].append(i)
	for space_id in by_space:
		var occupants: Array = by_space[space_id]
		var base := _board.get_space_center(space_id)
		for j in range(occupants.size()):
			var idx: int = occupants[j]
			positions[idx] = base + _cluster_offset(j, occupants.size())
	return positions

func _cluster_offset(slot: int, total: int) -> Vector2:
	if total == 1:
		return Vector2.ZERO
	var angle := (TAU / total) * slot
	return Vector2(cos(angle), sin(angle)) * 12.0
```

- [ ] **Step 2: Commit**

```bash
git add scenes/Monsters.gd
git commit -m "feat: animate monster tokens sequentially with hop-by-hop movement"
```

---

### Task 6: Make GameManager.end_turn() async

**Files:**
- Modify: `autoloads/GameManager.gd`

Add `phase_running` flag so `try_move()` blocks input during the monster phase. Make `end_turn()` a coroutine that awaits `phase_animation_done` before advancing the turn.

- [ ] **Step 1: Add `phase_running` and update `try_move()` and `end_turn()`**

Add `var phase_running: bool = false` near the other `var` declarations (line 21, after `var board_items`):

```gdscript
var phase_running: bool = false
```

Change `try_move()` to check `phase_running` (add it as the first condition):

```gdscript
func try_move(space_id: int) -> bool:
	if phase_running or moves_remaining <= 0 or players.is_empty() or board_data == null:
		return false
	var current_player := players[active_player_index]
	var current_space := board_data.get_space(current_player.current_space_id)
	if current_space == null or space_id not in current_space.neighbors:
		return false
	current_player.current_space_id = space_id
	moves_remaining -= 1
	player_moved.emit(active_player_index, space_id)
	return true
```

Replace `end_turn()` with a coroutine:

```gdscript
func end_turn() -> void:
	if players.is_empty():
		return
	phase_running = true
	MonsterManager.run_phase()
	await MonsterManager.phase_animation_done
	phase_running = false
	active_player_index = (active_player_index + 1) % players.size()
	moves_remaining = MOVES_PER_TURN
	turn_changed.emit(active_player_index)
```

- [ ] **Step 2: Commit**

```bash
git add autoloads/GameManager.gd
git commit -m "feat: make end_turn async, block input during monster phase"
```

---

### Task 7: Disable UI buttons during monster phase

**Files:**
- Modify: `scenes/UI.gd`

Disable End Turn and Pickup buttons when the monster phase starts, re-enable when the turn advances.

- [ ] **Step 1: Update `_on_end_turn_pressed` and `_on_turn_changed`**

Replace `_on_end_turn_pressed`:

```gdscript
func _on_end_turn_pressed() -> void:
	end_turn_button.disabled = true
	pickup_button.disabled = true
	GameManager.end_turn()
```

Replace `_on_turn_changed`:

```gdscript
func _on_turn_changed(_player_index: int) -> void:
	end_turn_button.disabled = false
	_refresh_turn_display()
```

- [ ] **Step 2: Run the game end-to-end and verify**

1. Start a game and move a player — token slides smoothly.
2. Press End Turn — both buttons disable immediately.
3. Watch monsters animate one at a time, each hopping through intermediate spaces.
4. After all monsters finish, turn advances, buttons re-enable, board shows new player's legal moves.
5. Clicking board spaces during monster animation does nothing (try_move returns false).

- [ ] **Step 3: Commit**

```bash
git add scenes/UI.gd
git commit -m "feat: disable UI buttons during monster animation phase"
```
