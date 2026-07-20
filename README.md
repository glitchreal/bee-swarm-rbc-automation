# Bee Swarm RBC Automation

Robo Bear Challenge automation for Bee Swarm Simulator. The existing automation file is the entry point:

- `rbc_quest_detector_no_atlas (1).lua`
- `bss-align-field-farm.client.lua` is retained as the field-alignment reference used during development.

## Automated Flow

- Starts and advances Robo Bear rounds only after the live round has ended.
- Claims Game Over rewards and closes stale NPC dialogue before starting again.
- Selects quests, bees, and upgrades using RBC guide priorities.
- Adapts upgrade choices to the selected quest, current round, attack, capacity, and active Homepage level.
- Routes multi-color pollen quests through overlapping fields, then switches fields as objectives complete.
- Runs the game's `Collectors.LocalCollect` loop while farming, which fires the real `ToolCollect` remote at the equipped collector's cooldown, and places sprinklers after entering a field.
- Uses a persistent, priority-aware token queue with strict field bounds and stall pathfinding.
- Finishes owned Precise crosshairs before changing fields.
- Uses quest-aware materials only when they solve a current weakness: color extracts, emergency late-round potions, field dice, goo support, and instant conversion.
- Limits Golden Cogmower chases to rounds below 20 and focuses objective Mechsquitos without sacrificing short-lived Precise marks.
- Limits upgrade rerolls to one per round and only after an upgrade was purchased.
- Applies a configurable movement speed from 20 to 70, with 70 as both the default and maximum.
- Leaves the player's hive composition unchanged.

## Boost Policy

The `Boosts` tab controls smart boosts, smart materials, smart combat, and the minimum rounds for field boosts, Gumdrops, and instant conversion. Scarce inventory is protected by reserves, material cooldowns are respected, and Super Smoothies are reserved for late-round emergencies rather than consumed continuously.

These policies were derived from the supplied RBC guide and compared against a live Atlas Auto RBC run. The comparison exposed repeated early Gumdrop use, quest-mismatched field choices, and upgrades that did not fit the active objective; this script evaluates those decisions from the current quest state instead.

## Runtime Requirements

The script expects executor APIs used by the existing project, including filesystem config access, `getgc`, `getconnections`, `firetouchinterest`, and virtual input support. Execute the main Lua file in an active Bee Swarm Simulator client, then enable `Auto RBC` in the overlay.

The generated `rbc_quest_detector_config.json` file is local runtime state and is not committed.

## Validation

The main file has been loaded repeatedly in a live client and tested across challenge starts, completed rounds, field transitions, tool collection, token routing, Game Over reward claims, and overlapping NPC/prompt states. The script reports its active build version in the overlay.
