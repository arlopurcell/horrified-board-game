# Monster Tasks and Defeat Design

**Date:** 2026-06-09
**Status:** Approved

## Overview

Add two new player actions (advance task, defeat monster), implement Dracula as the first real monster with hardcoded task/defeat logic, and add a win condition. Monster logic for all 6 monsters will be hardcoded — no generic framework needed.

---

## Data Model

### `MonsterData`

Add one runtime field:

```gdscript
var task_complete: bool = false
```

No `defeated` flag — when a monster is defeated it is removed from `MonsterManager.monsters` entirely.

### Coffin State (`GameManager`)

Dracula's coffin state is tracked in `GameManager`:

```gdscript
var dracula_coffins: Dictionary = {}   # space_id (int) -> smashed (bool)
```

Populated during `start_game()` by iterating `board_data.spaces` and collecting spaces whose `name` is in `["Cave", "Crypt", "Dungeon", "Graveyard"]`, each initialised to `false` (unsmashed).

### Game-Over State (`GameManager`)

```gdscript
var game_over: bool = false
```

Set to `true` when `game_won` fires. All `can_*()` checks return `false` when `game_over` is true. `try_move()` and `end_turn()` also return early.

---

## Dracula Resource

Replace `resources/data/base_monster.tres` with `resources/data/dracula.tres`:

- `monster_name = "Dracula"`
- `starting_space_id` = the space ID of the **Crypt** (look up in `board.tres`)

Update `Main.gd` to load `dracula.tres` instead of `base_monster.tres`.

---

## MonsterManager Changes

Add `remove_monster(monster_name: String)`:

```gdscript
func remove_monster(monster_name: String) -> void:
    for i in range(monsters.size() - 1, -1, -1):
        if monsters[i].monster_name == monster_name:
            monsters.remove_at(i)
            return
```

The existing `run_phase()` already handles `monsters.is_empty()` by emitting `monsters_moved([])`, so end-turn continues to work cleanly after the last monster is defeated.

---

## GameManager: New Signals

```gdscript
signal monster_defeated(monster_name: String)
signal game_won
```

---

## GameManager: New Actions

All four new methods gate on `game_over` in addition to existing guards.

### `can_advance() -> bool`

```
not game_over
AND not phase_running
AND moves_remaining > 0
AND Dracula is in MonsterManager.monsters
AND dracula_coffins contains active player's space_id
AND dracula_coffins[active_player.current_space_id] == false  (unsmashed)
```

### `try_advance(items: Array[ItemData]) -> bool`

1. Return `false` if `not can_advance()`.
2. Validate: all items are red AND sum of `item.strength` ≥ 6. Return `false` if not.
3. Remove `items` from `active_player.inventory`.
4. Set `dracula_coffins[active_player.current_space_id] = true`.
5. Decrement `moves_remaining`.
6. Emit `items_changed` (so inventory display refreshes).
7. If all values in `dracula_coffins` are `true`: find Dracula in `MonsterManager.monsters` and set `task_complete = true`.
8. Return `true`.

### `can_defeat() -> bool`

```
not game_over
AND not phase_running
AND moves_remaining > 0
AND Dracula is in MonsterManager.monsters
AND Dracula.task_complete == true
AND active player's space_id == Dracula's current_space_id
```

### `try_defeat(items: Array[ItemData]) -> bool`

1. Return `false` if `not can_defeat()`.
2. Validate: all items are yellow AND sum of `item.strength` ≥ 6. Return `false` if not.
3. Remove `items` from `active_player.inventory`.
4. Decrement `moves_remaining`.
5. Emit `items_changed`.
6. Emit `monster_defeated("Dracula")` — **before** `remove_monster()` so `Monsters.gd` can still find the monster's index in `MonsterManager.monsters`.
7. Call `MonsterManager.remove_monster("Dracula")`.
8. If `MonsterManager.monsters.is_empty()`: set `game_over = true`, emit `game_won`.
9. Return `true`.

---

## Monsters.gd Changes

Connect to `GameManager.monster_defeated`. Because `monster_defeated` is emitted **before** `MonsterManager.remove_monster()` (see `try_defeat` step 6), the monster is still present in `MonsterManager.monsters` when the handler runs.

On `monster_defeated(monster_name)`:
1. Find the monster's index in `MonsterManager.monsters` by name — it's still there.
2. Call `queue_free()` on `_tokens[idx]`.
3. Remove `_tokens[idx]` from `_tokens`.

After the handler returns, `try_defeat` calls `remove_monster()`, keeping `_tokens` and `MonsterManager.monsters` in sync (same index removed from both).

---

## ItemSelectionPanel Scene

New scene: `scenes/ItemSelectionPanel.tscn` — a `PanelContainer` child of the `CanvasLayer` in `Main.tscn`, hidden by default.

**Signals:**
```gdscript
signal confirmed(selected_items: Array[ItemData])
signal cancelled
```

**API:**
```gdscript
func open(items: Array[ItemData], required_strength: int) -> void
```

Called by `UI.gd` with the filtered item list (red or yellow only) and the required total (6 for both actions).

**Behaviour:**
- Displays each item as a row: name, color, strength, and a checkbox.
- Shows a running total of checked items' strength.
- Confirm button enabled only when total ≥ `required_strength`.
- Cancel button always enabled; emits `cancelled`.
- On confirm: collects checked items, emits `confirmed(selected_items)`, hides itself.

---

## UI Changes

### New Buttons

Two new buttons in the UI scene: **Advance** and **Defeat**. Both are hidden (not just disabled) when the action is unavailable. Visibility is refreshed after every action and on `turn_changed`.

- Advance visible when `GameManager.can_advance()`.
- Defeat visible when `GameManager.can_defeat()`.

### Action Flow

**Advance pressed:**
1. Filter `active_player.inventory` for red items.
2. Call `ItemSelectionPanel.open(red_items, 6)`.
3. On `confirmed(items)`: call `GameManager.try_advance(items)`, refresh buttons.
4. On `cancelled`: do nothing.

**Defeat pressed:**
1. Filter `active_player.inventory` for yellow items.
2. Call `ItemSelectionPanel.open(yellow_items, 6)`.
3. On `confirmed(items)`: call `GameManager.try_defeat(items)`, refresh buttons.
4. On `cancelled`: do nothing.

### Win Overlay

A `Label` node (`GameWonLabel`) in the `CanvasLayer`, hidden by default, centered on screen. When `GameManager.game_won` fires: set its text to `"You Win!"` and make it visible. No further input processing is needed — `game_over = true` blocks all game actions.

---

## Edge Cases

- **Player discards items they don't have:** `try_advance`/`try_defeat` validate that each item in the selection exists in the player's inventory before removing.
- **Advance on already-smashed coffin:** `can_advance()` returns false for smashed coffins — button is hidden.
- **Defeat when task not complete:** `can_defeat()` returns false — button hidden.
- **End turn after game won:** `end_turn()` returns early when `game_over` is true.
- **Monster phase after last monster defeated:** `run_phase()` emits `monsters_moved([])` immediately (existing guard), so end-turn resolves cleanly even with no monsters.
