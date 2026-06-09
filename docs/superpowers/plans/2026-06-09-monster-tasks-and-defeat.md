# Monster Tasks and Defeat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add advance-task and defeat-monster player actions, implement Dracula as the first real monster with coffin-smashing task and yellow-item defeat mechanic, and show a win screen when all monsters are defeated.

**Architecture:** Dracula-specific logic is hardcoded in `GameManager` new methods (`can_advance`, `try_advance`, `can_defeat`, `try_defeat`). Monster removal keeps `MonsterManager.monsters` and `Monsters.gd`'s `_tokens` in sync by emitting `monster_defeated` before calling `remove_monster()`. A self-contained `ItemSelectionPanel` scene (programmatic UI, no .tscn) handles item selection with a strength total and a gated Confirm button.

**Tech Stack:** Godot 4 GDScript, `PanelContainer`, `CheckBox`, `Array[ItemData]`, resource `.tres` files

---

## File Map

| File | Change |
|------|--------|
| `resources/monster_data.gd` | Add `var task_complete: bool = false` |
| `resources/data/dracula.tres` | New file — Dracula monster resource (starting space = Crypt, id 15) |
| `autoloads/MonsterManager.gd` | Add `remove_monster(name)` method |
| `autoloads/GameManager.gd` | Add `dracula_coffins`, `game_over`, two signals, four new action methods; update `try_move`, `end_turn`, `start_game` |
| `scenes/Monsters.gd` | Add `_on_monster_defeated` handler; connect in `setup()` |
| `scenes/ItemSelectionPanel.gd` | New file — builds full UI programmatically, emits `confirmed`/`cancelled` |
| `scenes/UI.gd` | Add advance/defeat buttons, win label, item panel; refresh action buttons on state changes |
| `scenes/UI.tscn` | Add AdvanceButton, DefeatButton, GameWonLabel nodes |
| `scenes/Main.gd` | Load `dracula.tres` instead of `base_monster.tres` |

---

### Task 1: Add `task_complete` to MonsterData

**Files:**
- Modify: `resources/monster_data.gd`

- [ ] **Step 1: Add the field**

Replace the contents of `resources/monster_data.gd` with:

```gdscript
class_name MonsterData
extends Resource

@export var monster_name: String = ""
@export var starting_space_id: int = 0
var current_space_id: int = 0
var task_complete: bool = false
```

- [ ] **Step 2: Commit**

```bash
git add resources/monster_data.gd
git commit -m "feat: add task_complete field to MonsterData"
```

---

### Task 2: Create Dracula resource

**Files:**
- Create: `resources/data/dracula.tres`

Board space IDs for reference: Cave=0, Crypt=15, Dungeon=5, Graveyard=20.

- [ ] **Step 1: Create the resource file**

Create `resources/data/dracula.tres` with these exact contents:

```
[gd_resource type="Resource" script_class="MonsterData" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/monster_data.gd" id="1"]

[resource]
script = ExtResource("1")
monster_name = "Dracula"
starting_space_id = 15
```

- [ ] **Step 2: Update Main.gd to load dracula.tres**

In `scenes/Main.gd`, change line 8 from:
```gdscript
var base_monster := load("res://resources/data/base_monster.tres") as MonsterData
```
to:
```gdscript
var dracula := load("res://resources/data/dracula.tres") as MonsterData
```

And line 10 from:
```gdscript
MonsterManager.setup([base_monster], deck_data)
```
to:
```gdscript
MonsterManager.setup([dracula], deck_data)
```

- [ ] **Step 3: Verify**

Run the game. Dracula's token should start at the Crypt (the space at approximately x=100, y=495 on the board).

- [ ] **Step 4: Commit**

```bash
git add resources/data/dracula.tres scenes/Main.gd
git commit -m "feat: add Dracula resource, starting at the Crypt"
```

---

### Task 3: Add `remove_monster` to MonsterManager

**Files:**
- Modify: `autoloads/MonsterManager.gd`

- [ ] **Step 1: Add the method**

Add this method to `autoloads/MonsterManager.gd` (after `_roll_dice`):

```gdscript
func remove_monster(monster_name: String) -> void:
	for i in range(monsters.size() - 1, -1, -1):
		if monsters[i].monster_name == monster_name:
			monsters.remove_at(i)
			return
	push_warning("MonsterManager.remove_monster: '%s' not found" % monster_name)
```

- [ ] **Step 2: Commit**

```bash
git add autoloads/MonsterManager.gd
git commit -m "feat: add remove_monster to MonsterManager"
```

---

### Task 4: Add state, signals, and guards to GameManager

**Files:**
- Modify: `autoloads/GameManager.gd`

This task adds the new state variables, signals, and updates the existing guards. The new action methods come in Task 5.

- [ ] **Step 1: Add signals and state variables**

After `var phase_running: bool = false` (line 22), add:

```gdscript
var dracula_coffins: Dictionary = {}   # space_id (int) -> smashed (bool)
var game_over: bool = false

signal monster_defeated(monster_name: String)
signal game_won
```

- [ ] **Step 2: Initialise coffin state and game_over in start_game()**

In `start_game()`, after `board_items.clear()` (before `_place_initial_items()`), add:

```gdscript
game_over = false
dracula_coffins.clear()
for space in board_data.spaces:
	if space.name in ["Cave", "Crypt", "Dungeon", "Graveyard"]:
		dracula_coffins[space.id] = false
```

- [ ] **Step 3: Guard try_move() against game_over**

Change the first line of `try_move()` from:
```gdscript
if phase_running or moves_remaining <= 0 or players.is_empty() or board_data == null:
```
to:
```gdscript
if game_over or phase_running or moves_remaining <= 0 or players.is_empty() or board_data == null:
```

- [ ] **Step 4: Guard end_turn() against game_over**

Change the guard at the top of `end_turn()` from:
```gdscript
if players.is_empty() or phase_running:
```
to:
```gdscript
if players.is_empty() or phase_running or game_over:
```

- [ ] **Step 5: Commit**

```bash
git add autoloads/GameManager.gd
git commit -m "feat: add coffin state, game_over flag, and new signals to GameManager"
```

---

### Task 5: Add advance and defeat action methods to GameManager

**Files:**
- Modify: `autoloads/GameManager.gd`

Add all four methods after `get_legal_moves()` at the end of the file.

- [ ] **Step 1: Add the helper and all four action methods**

Append to the end of `autoloads/GameManager.gd`:

```gdscript
func _get_dracula() -> MonsterData:
	for m in MonsterManager.monsters:
		if m.monster_name == "Dracula":
			return m
	return null

func can_advance() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	if _get_dracula() == null:
		return false
	var space_id := players[active_player_index].current_space_id
	return dracula_coffins.has(space_id) and dracula_coffins[space_id] == false

func try_advance(items: Array[ItemData]) -> bool:
	if not can_advance():
		return false
	var total := 0
	for item in items:
		if item.color != "red":
			return false
		total += item.strength
	if total < 6:
		return false
	var current_player := players[active_player_index]
	for item in items:
		current_player.inventory.erase(item)
	dracula_coffins[current_player.current_space_id] = true
	moves_remaining -= 1
	items_changed.emit()
	var all_smashed := true
	for smashed in dracula_coffins.values():
		if not smashed:
			all_smashed = false
			break
	if all_smashed:
		var dracula := _get_dracula()
		if dracula != null:
			dracula.task_complete = true
	return true

func can_defeat() -> bool:
	if game_over or phase_running or moves_remaining <= 0 or players.is_empty():
		return false
	var dracula := _get_dracula()
	if dracula == null or not dracula.task_complete:
		return false
	return players[active_player_index].current_space_id == dracula.current_space_id

func try_defeat(items: Array[ItemData]) -> bool:
	if not can_defeat():
		return false
	var total := 0
	for item in items:
		if item.color != "yellow":
			return false
		total += item.strength
	if total < 6:
		return false
	var current_player := players[active_player_index]
	for item in items:
		current_player.inventory.erase(item)
	moves_remaining -= 1
	items_changed.emit()
	monster_defeated.emit("Dracula")
	MonsterManager.remove_monster("Dracula")
	if MonsterManager.monsters.is_empty():
		game_over = true
		game_won.emit()
	return true
```

- [ ] **Step 2: Commit**

```bash
git add autoloads/GameManager.gd
git commit -m "feat: add can_advance, try_advance, can_defeat, try_defeat to GameManager"
```

---

### Task 6: Update Monsters.gd to handle monster removal

**Files:**
- Modify: `scenes/Monsters.gd`

When `monster_defeated` fires, the monster is still in `MonsterManager.monsters` (signal fires before `remove_monster` is called in `try_defeat`). Find the index by name, free the token, and remove it from `_tokens`.

- [ ] **Step 1: Connect signal in setup() and add handler**

Replace the full contents of `scenes/Monsters.gd` with:

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
	GameManager.monster_defeated.connect(_on_monster_defeated)
	_place_all_tokens()

func _on_monster_defeated(monster_name: String) -> void:
	var idx := -1
	for i in range(MonsterManager.monsters.size()):
		if MonsterManager.monsters[i].monster_name == monster_name:
			idx = i
			break
	if idx == -1:
		push_error("Monsters.gd: no monster named '%s' found for removal" % monster_name)
		return
	_tokens[idx].queue_free()
	_tokens.remove_at(idx)

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
git commit -m "feat: handle monster_defeated signal in Monsters.gd to remove token"
```

---

### Task 7: Create ItemSelectionPanel

**Files:**
- Create: `scenes/ItemSelectionPanel.gd`

Builds its entire node tree in `_ready()`. Positioned centered in the CanvasLayer. Hidden by default.

- [ ] **Step 1: Create the file**

Create `scenes/ItemSelectionPanel.gd` with these exact contents:

```gdscript
class_name ItemSelectionPanel
extends PanelContainer

signal confirmed(selected_items: Array[ItemData])
signal cancelled

const REQUIRED_STRENGTH := 6

var _items: Array[ItemData] = []
var _checkboxes: Array[CheckBox] = []
var _total_label: Label
var _confirm_btn: Button
var _item_list: VBoxContainer

func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -210.0
	offset_top = -220.0
	offset_right = 210.0
	offset_bottom = 220.0

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Select Items to Discard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 250)
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	scroll.add_child(_item_list)

	_total_label = Label.new()
	_total_label.text = "Total strength: 0 / 6 required"
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_total_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.pressed.connect(_on_cancelled)
	btn_row.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.custom_minimum_size = Vector2(120, 36)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirmed)
	btn_row.add_child(_confirm_btn)

func open(items: Array[ItemData]) -> void:
	_items = items
	_checkboxes.clear()
	for child in _item_list.get_children():
		child.queue_free()
	for item in items:
		var cb := CheckBox.new()
		cb.text = "%s  (str %d)" % [item.item_name, item.strength]
		cb.toggled.connect(_on_toggled)
		_item_list.add_child(cb)
		_checkboxes.append(cb)
	_update_total()
	visible = true

func _on_toggled(_pressed: bool) -> void:
	_update_total()

func _update_total() -> void:
	var total := 0
	for i in range(_checkboxes.size()):
		if _checkboxes[i].button_pressed:
			total += _items[i].strength
	_total_label.text = "Total strength: %d / %d required" % [total, REQUIRED_STRENGTH]
	_confirm_btn.disabled = total < REQUIRED_STRENGTH

func _on_confirmed() -> void:
	var selected: Array[ItemData] = []
	for i in range(_checkboxes.size()):
		if _checkboxes[i].button_pressed:
			selected.append(_items[i])
	visible = false
	confirmed.emit(selected)

func _on_cancelled() -> void:
	visible = false
	cancelled.emit()
```

- [ ] **Step 2: Commit**

```bash
git add scenes/ItemSelectionPanel.gd
git commit -m "feat: add ItemSelectionPanel with checkbox item selection and strength gate"
```

---

### Task 8: Add UI nodes and wire up actions in UI.gd and UI.tscn

**Files:**
- Modify: `scenes/UI.tscn`
- Modify: `scenes/UI.gd`

Add AdvanceButton, DefeatButton, and GameWonLabel to the scene. Wire them up in the script along with the ItemSelectionPanel.

- [ ] **Step 1: Add nodes to UI.tscn**

Append these node definitions to the end of `scenes/UI.tscn` (before the closing of the file, after the last `[node ...]` block):

```
[node name="AdvanceButton" type="Button" parent="."]
offset_left = 10.0
offset_top = 260.0
offset_right = 155.0
offset_bottom = 300.0
text = "ADVANCE TASK"
theme_override_font_sizes/font_size = 13
visible = false

[node name="DefeatButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 260.0
offset_right = 300.0
offset_bottom = 300.0
text = "DEFEAT MONSTER"
theme_override_font_sizes/font_size = 13
visible = false

[node name="GameWonLabel" type="Label" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -50.0
offset_right = 200.0
offset_bottom = 50.0
text = "You Win!"
horizontal_alignment = 1
vertical_alignment = 1
theme_override_font_sizes/font_size = 64
visible = false
```

- [ ] **Step 2: Replace UI.gd**

Replace the full contents of `scenes/UI.gd` with:

```gdscript
extends CanvasLayer

@onready var turn_banner: Label = $TurnBanner
@onready var player_roster: HBoxContainer = $PlayerRoster
@onready var end_turn_button: Button = $EndTurnButton
@onready var moves_indicator: Label = $MovesIndicator
@onready var monster_log: Label = $MonsterLog
@onready var inventory_list: RichTextLabel = $InventoryPanel/InventoryList
@onready var pickup_button: Button = $PickupButton
@onready var advance_button: Button = $AdvanceButton
@onready var defeat_button: Button = $DefeatButton
@onready var game_won_label: Label = $GameWonLabel

const ItemSelectionPanelScene := preload("res://scenes/ItemSelectionPanel.gd")

var _item_panel: ItemSelectionPanel
var _pending_action: String = ""

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pickup_button.pressed.connect(_on_pickup_pressed)
	advance_button.pressed.connect(_on_advance_pressed)
	defeat_button.pressed.connect(_on_defeat_pressed)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.player_moved.connect(_on_player_moved)
	GameManager.items_changed.connect(_on_items_changed)
	GameManager.monster_defeated.connect(_on_monster_defeated)
	GameManager.game_won.connect(_on_game_won)
	MonsterManager.phase_completed.connect(_on_phase_completed)
	_item_panel = ItemSelectionPanelScene.new()
	add_child(_item_panel)
	_item_panel.confirmed.connect(_on_item_panel_confirmed)
	_item_panel.cancelled.connect(_on_item_panel_cancelled)

func setup(player_list: Array[PlayerData]) -> void:
	for child in player_roster.get_children():
		child.queue_free()
	for i in range(player_list.size()):
		var lbl := Label.new()
		lbl.text = player_list[i].player_name
		lbl.add_theme_color_override("font_color", player_list[i].color)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.name = "Player" + str(i)
		player_roster.add_child(lbl)
	_refresh_turn_display()

func _on_end_turn_pressed() -> void:
	end_turn_button.disabled = true
	pickup_button.disabled = true
	GameManager.end_turn()
	_refresh_action_buttons()

func _on_pickup_pressed() -> void:
	GameManager.try_pickup()

func _on_advance_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var red_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "red":
			red_items.append(item as ItemData)
	_pending_action = "advance"
	_item_panel.open(red_items)

func _on_defeat_pressed() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var yellow_items: Array[ItemData] = []
	for item in active.inventory:
		if (item as ItemData).color == "yellow":
			yellow_items.append(item as ItemData)
	_pending_action = "defeat"
	_item_panel.open(yellow_items)

func _on_item_panel_confirmed(selected_items: Array[ItemData]) -> void:
	if _pending_action == "advance":
		GameManager.try_advance(selected_items)
	elif _pending_action == "defeat":
		GameManager.try_defeat(selected_items)
	_pending_action = ""
	_refresh_action_buttons()

func _on_item_panel_cancelled() -> void:
	_pending_action = ""

func _on_turn_changed(_player_index: int) -> void:
	end_turn_button.disabled = false
	_refresh_turn_display()

func _on_player_moved(_player_index: int, _space_id: int) -> void:
	_update_moves_indicator()
	_refresh_pickup_button()
	_refresh_action_buttons()

func _on_items_changed() -> void:
	_refresh_inventory()
	_refresh_pickup_button()
	_refresh_action_buttons()

func _on_phase_completed(summary: String) -> void:
	monster_log.text = summary

func _on_monster_defeated(_monster_name: String) -> void:
	_refresh_action_buttons()

func _on_game_won() -> void:
	game_won_label.visible = true

func _refresh_action_buttons() -> void:
	advance_button.visible = GameManager.can_advance()
	defeat_button.visible = GameManager.can_defeat()

func _refresh_turn_display() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	turn_banner.text = active.player_name + "'s Turn"
	turn_banner.add_theme_color_override("font_color", active.color)
	for i in range(player_roster.get_child_count()):
		var lbl := player_roster.get_child(i) as Label
		if lbl == null:
			continue
		var is_active := (i == GameManager.active_player_index)
		lbl.add_theme_font_size_override("font_size", 18 if is_active else 13)
	_update_moves_indicator()
	_refresh_inventory()
	_refresh_pickup_button()
	_refresh_action_buttons()

func _update_moves_indicator() -> void:
	var active := GameManager.get_active_player()
	if active == null:
		return
	var remaining := GameManager.moves_remaining
	var total := GameManager.MOVES_PER_TURN
	var parts: Array[String] = []
	for i in range(total):
		parts.append("●" if i < remaining else "○")
	moves_indicator.text = " ".join(parts)
	moves_indicator.add_theme_color_override("font_color", active.color)

func _refresh_inventory() -> void:
	var active := GameManager.get_active_player()
	inventory_list.clear()
	if active == null:
		return
	for item in active.inventory:
		var item_data := item as ItemData
		if item_data == null:
			continue
		var color: Color
		match item_data.color:
			"red":    color = Color(0.75, 0.22, 0.17)
			"blue":   color = Color(0.16, 0.50, 0.73)
			"yellow": color = Color(0.95, 0.77, 0.06)
			_:        color = Color.WHITE
		inventory_list.push_color(color)
		inventory_list.add_text("● %s  %d\n" % [item_data.item_name, item_data.strength])
		inventory_list.pop()

func _refresh_pickup_button() -> void:
	pickup_button.disabled = not GameManager.can_pickup()
```

- [ ] **Step 3: Run the game and verify**

Start a game. Collect some red items by picking them up. Navigate to the Cave (space 0), Crypt (space 15), Dungeon (space 5), or Graveyard (space 20). The "ADVANCE TASK" button should appear. Click it — an item selection panel should open showing red items. Check items totalling ≥6 strength and confirm. The button should disappear (coffin smashed). After all 4 coffins are smashed, find Dracula (at the Crypt initially), collect yellow items, stand in Dracula's space — "DEFEAT MONSTER" button appears. Select yellow items ≥6 strength and confirm. Dracula's token disappears and "You Win!" appears.

- [ ] **Step 4: Commit**

```bash
git add scenes/UI.tscn scenes/UI.gd
git commit -m "feat: add Advance/Defeat buttons, item selection panel, and win screen to UI"
```
