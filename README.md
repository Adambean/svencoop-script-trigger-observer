# Sven Co-op script: trigger_observer

This script implements an entity for use in maps, `trigger_observer`, which can be used for a map to arbitrarily start/stop/toggle observer mode on players.

## Installation

This script needs to be at game path "scripts/maps/trigger_observer.as". Then in a map do **one** of the following:

* Add a `trigger_script` entity pointing to file "trigger_observer.as". (No function to call.)
* Add a map configuration entry "map_script trigger_observer".
* In your existing map script add an include `#include trigger_observer`.

## Brush entity

Add a brush entity with class name `trigger_observer`:

* There are no keys to define.
* The brush will always be invisible.
* When players touch the brush they will become an observer.

## Point entity

Add a point entity with classname `trigger_observer`:

* Key `targetname` is necessary to take input from another entity.
* There is currently no `target` key.
* Spawnflag 1 `1<<0`: Do not remember position of players prior to observing.

You can then target the entity however you like, such as a button, brush (e.g. `trigger_multiple`), or logic entity (e.g. `multi_manager`) to start or stop observer mode on a player.

The activating entity must be a fully connected player, so for some entities you will need to use their "Keep Activator" flag (e.g. `trigger_condition`).

You can pass through various `USE_TYPE` to explicitly decide what will happen:

* `USE_ON`: Start observer mode only. (Do not stop if observing.)
* `USE_OFF`: Stop observer mode only. (Do not start if not observing.)
* `USE_TOGGLE`: Switch being in/out of observer mode. (Opposite of whether the player is currently in/out.)

## API

When this script has been included in your own map script using `#include` you can access its functionality directly via the `TriggerObserver` namespace.

* Start observing: `StartObserving(CBasePlayer@ pPlayer, bool fSavePosition = false): void`
* Stop observing: `StopObserving(CBasePlayer@ pPlayer, bool fIgnoreSavedPosition = false): void`

## Exiting observer mode and remembering player position

Players can opt to exit observation at any time by using the tertiary attack bind `+alt`, which is usually bound to mouse middle click. They will be shown a reminder of this whilst observing.

When added as a point entity or called directly via API it can optionally remember where the player was prior to starting observation, so that when they later leave observation they're put back where they were instead of just respawning.

Because observing players are technically dead and "out of play" when the player exits observer they will see themselves respawn for a tiny moment before being moved to back where they were. This also means that if there are no available (active) spawn points, or the map is running survival mode, then a player **cannot exit observer mode** until a spawn point becomes available or survival checkpoint is reached.

As a point entity enable spawn flag 1 to switch this feature off. This is not available to a brush entity because they'd be put back to where the brush is, thus would immediately re-enter observation.
