# Movement Animation Design

**Date:** 2026-06-08  
**Status:** Approved

## Overview

Animate player and monster token movement on the board. Player tokens slide smoothly to their destination on each move. Monster tokens animate one at a time in card order, hopping through each intermediate space before the next monster begins moving. The player turn does not advance until all monster animations complete.

## Token Animation

`PlayerToken.move_to(world_pos: Vector2)` and `MonsterToken.move_to(world_pos: Vector2)` each create and return a `Tween` instead of instantly setting `position`. Parameters:

- Duration: 0.25s per hop
- Easing: `TRANS_SINE / EASE_IN_OUT`
- The caller `await`s `tween.finished` when sequencing depends on completion

## Signal Changes

### `MonsterManager`

`monsters_moved` changes signature:
```gdscript
signal monsters_moved(move_data: Array)
```

Each element of `move_data` is a `Dictionary`:
```gdscript
{ "monster_idx": int, "path": Array[int] }
```

Only monsters that actually move (path length > 1) are included. Monsters that stay put are omitted.

A new signal is added:
```gdscript
signal phase_animation_done
```

`Monsters.gd` emits this when all animation completes. `GameManager` awaits it before advancing the turn.

## Monster Sequencing (`Monsters.gd`)

On receiving `monsters_moved(move_data)`:

1. For each entry in `move_data` (in order):
   a. For each hop in `entry.path` (skipping the first element, which is the starting space):
      - Compute the world position for that space (center, no cluster offset)
      - Call `token.move_to(world_pos)` and `await tween.finished`
   b. After the monster reaches its final space, apply cluster offsets across all tokens on that space (instant reposition or a short tween — instant is fine)
2. After all monsters finish, emit `MonsterManager.phase_animation_done`

Player token placement (`Players.gd`) on `player_moved`: animate only the moved token (identified by `player_index`) from its current position to the new cluster-offset position. Other tokens at the destination may need a quick instant reposition to make room.

## Turn Advancement Blocking (`GameManager`)

`end_turn()` becomes a coroutine:

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

`phase_running: bool` is a new property on `GameManager`. `try_move()` returns `false` early when `phase_running` is `true`.

`UI.gd._on_end_turn_pressed()` disables the End Turn button and Pickup button immediately before calling `GameManager.end_turn()` — no signal needed since the UI triggered it. Both buttons are re-enabled in the existing `_on_turn_changed` handler when `turn_changed` fires. Board space clicks are already gated by `try_move()` returning false.

## Edge Cases

- **Monster already at target (path length 1):** Excluded from `move_data`; no animation runs for it.
- **Empty move_data:** `Monsters.gd` receives an empty array, skips the loop, and immediately emits `phase_animation_done`.
- **Multiple tokens stacking:** Cluster offset is applied instantly at the end of each monster's full move. Mid-hop positions use the raw space center.
- **Player stacking after player move:** Only the active player's token animates; any tokens already at the destination are instantly repositioned to the new cluster layout.
