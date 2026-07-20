# Bee Swarm RBC Automation

Robo Bear Challenge automation for Bee Swarm Simulator. The automation entry point is:

- `rbc_quest_detector_no_atlas (1).lua`

## Automated Flow

- Starts and advances Robo Bear rounds only after the live round has ended.
- Claims Game Over rewards and closes stale NPC dialogue before starting again.
- Selects quests, bees, and upgrades using RBC guide priorities.
- Adapts upgrade choices to the selected quest, current round, attack, capacity, and active Homepage level.
- Routes multi-color pollen quests through overlapping fields, then switches fields as objectives complete.
- Runs the game's `Collectors.LocalCollect` loop while farming, which fires the real `ToolCollect` remote at the equipped collector's cooldown, and places sprinklers after entering a field.
- Detects token spawns immediately, rebuilds its priority route without the old polling delay, and recovers stalled token movement.
- Reads live Precise target state plus `Precision` and `Precise Mark` buff stacks to build x10 Precision, cap gifted marks at x3, and refresh expiring stacks.
- Scores fields from the live game's tier-weighted flower composition and active RBC field upgrades, then switches as individual pollen objectives complete.
- Cancels or recovers stale field/Robo Bear movement sessions instead of remaining stuck in a tween.
- Uses quest-aware materials only when they solve a current weakness: color extracts, emergency late-round potions, field dice, goo support, and instant conversion.
- Limits Golden Cogmower chases to rounds below 20 and focuses objective Mechsquitos without sacrificing short-lived Precise marks.
- Limits upgrade rerolls to one per round and only after an upgrade was purchased.
- Applies a configurable movement speed from 20 to 70, with 70 as both the default and maximum.
- Leaves the player's hive composition unchanged.

## Boost Policy

The `Boosts` tab controls smart boosts, smart materials, smart combat, and the minimum rounds for field boosts, Gumdrops, and instant conversion. Scarce inventory is protected by reserves, material cooldowns are respected, and Super Smoothies are reserved for late-round emergencies rather than consumed continuously.

These policies were derived from the supplied RBC guide and compared against a live Atlas Auto RBC run. The comparison exposed repeated early Gumdrop use, quest-mismatched field choices, and upgrades that did not fit the active objective; this script evaluates those decisions from the current quest state instead.

## Runtime Requirements

The script expects executor APIs used by the existing project, including filesystem config access, `getgc`, `getconnections`, and virtual input support. It does not use touch simulation or character teleports. Execute the main Lua file in an active Bee Swarm Simulator client, then enable `Auto RBC` in the overlay.

The generated `rbc_quest_detector_config.json` file is local runtime state and is not committed.

Press Right Shift to show or hide the overlay.

## Validation

The main file has been loaded repeatedly in a live client and tested across challenge starts, completed rounds, field transitions, tool collection, token routing, Game Over reward claims, and overlapping NPC/prompt states. The script reports its active build version in the overlay.
