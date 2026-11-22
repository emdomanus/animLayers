# Changelog

## Unreleased

The package was rewritten (VMMO-90). Every 0.1 name is removed with no alias;
`docs/guides/migrating.md` maps each old call to its replacement. This entry replaces the unreleased
absolute-time work (`TimeReader`, the command queue, `sampledPosition`), which is removed with the
rest and remains in the repository's history.

### Added

- `controllers.layerController.new(animator, layerDefinitions)`: named layers over one `Animator`,
  each playing one clip or nothing. Commands (`play`, `stop`, `setClipSpeed`, `setClipTime`,
  `setClipNormalizedTime`, `setLayerWeight`, `setLayerTimeScale`) write the controller's state;
  `update()` is the only place the engine is called, makes one engine call per difference, and
  returns at its first statement when nothing changed.
- Speed and position belong to the clip playing on a layer. Weight and time scale belong to the
  layer, stay across plays and start at 1. The engine's speed is the clip's speed times the layer's
  time scale.
- `utils.clipDefinition.build(assetId, looped)`: a frozen definition, `{ assetId, looped }`. It
  carries, under a field the public type does not declare, the one `Animation` Instance every
  controller loads that clip's tracks from.
- `trackManager`, a private object the controller constructs: it owns the engine's tracks and makes
  every engine call. The entry exports nothing of it.
- `getPlayId(layer)` on `LayerController`: the id of the play on the layer now, or nil when the
  layer plays nothing. It is nil after `stop` and `clear`, and already inside `onPlayEnded`.
- `play` returns the play's id, a number. `onMarker(markerName, callback)` is called inside the
  engine's marker signal.
- `onPlayEnded(callback)` reports every play once, `(layer, playId, reason)`, where `reason` is a
  `PlayEndedReason`: `"completed"` from `update` when a clip that does not loop reached its end,
  `"stopped"` inside `stop`, and inside `clear` and `deconstruct` for each layer with a play, and
  `"replaced"` inside the `play` that displaced it. A play the engine had already ended is
  `"completed"` however it leaves its layer. The layer shows its new state inside the callback, and
  a callback may call any method. `clear` and `deconstruct` report before they return.
- `common.playEndedReason` on the entry: the three `PlayEndedReason` values, each under its name.
- A speed tolerance: `setClipSpeed` replaces a clip's speed only beyond 0.005 and 1%, or to or from
  0, or across a change of sign, and returns the speed in effect.
- Kept tracks: a controller plays a loaded `AnimationTrack` again while it is idle, and destroys
  tracks only at `deconstruct` or above 64, where it drops the idle track played longest ago.
- `update` raises when an engine call raises, and the next `update` makes the calls that had not
  returned.
- A Lune case that shows `update` allocates nothing, quiet or with a speed changing on every call.
- `compass.json`, `AGENTS.md`, `seleneLuau.yml`, and the dependency `emdomanus/luau_utils` for
  `callbackList`.

### Changed

- The package is renamed from `animGraph` (pesde `emdomanus/anim_graph`) to `animLayers` (pesde
  `emdomanus/anim_layers`): it has layers and no graph. The entry's module type is
  `AnimLayersModule`, and the dev place maps the package at `ReplicatedStorage.packages.animLayers`.
- The entry is `src/shared.luau`, typed and frozen, with its exports under `controllers` and
  `utils`. Requires are by string; type files are `public.luau` and `private.luau` leaves.
- Tests moved to `tests/src/...` beside what they test and are found by suffix by
  `scripts/verify/tests.ps1`. They require the real modules through `@game`.
- The dev place calls the new API and shows the engine's playing tracks.

### Removed

- `onPlayCompleted`, with no alias. Revisions `9b014d4` to `6cc6f09` had it; code pinned at one of
  them moves to `onPlayEnded`, whose `"completed"` reports are the ends `onPlayCompleted` reported.
- `AnimationController`, `robloxAnimatorBackend` as a public object, and the backend contract.
- Motion nodes (`clipNode`, `blend1DNode`, `blend2DNode`), `stateMachineRuntime`, transitions,
  triggers, the parameter store and the graph events.
- `TimeReader`, `TimeSample`, the three reader levels and the `sampleTime` argument of `update`.
- The command queue, `trackKey`, `LayerPlayOptions`, `AnimationPosition`, `offsetTrackPosition`,
  `logicalPriority` and priority bands, the debug snapshots, and all five type parameters.
- The `sampledPosition` backend mode.
- `stackModifier`, the package's only use of `task.delay`.
- The bench suite and its script, the old verification scripts, the docs diagrams and their
  renderer.

## 0.1.0

- Replaced the category mixer API with the first `AnimationController` vertical
  slice.
- Added typed logical layers, clip motion nodes, controller parameters, debug
  snapshots, and a Roblox `Animator` backend.
- Added `Blend1DNode`, `Blend2DNode`, transition runtime, authored
  state-machine runtime, and controller event dispatch.
- Added runtime setters/getters for layer logical priority and explicit Roblox
  priority overrides.
- Added backend-neutral clip request contracts so a future Crunchyroll/custom
  solver backend can share the public controller API.
- Kept `StackModifier` as a shared component for future speed/weight modifier
  stacks.
- Added an interactive Rojo dev harness for spawning a local R6 dummy and testing
  blend parameters, state-machine triggers, event logs, weights, priority
  mapping, and debug snapshots.
