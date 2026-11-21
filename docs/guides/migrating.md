# Migrating from the 0.1 graph API

The 0.1 package was `AnimationController` over `robloxAnimatorBackend`, with motion nodes, time
readers and a queue of commands. All of it is removed; there is no alias and no old path. This page
maps each old call to what replaces it.

## Requires and names

| 0.1 | Now |
| --- | --- |
| entry `src/init.luau` | entry `src/shared.luau` |
| the package's name | `emdomanus/anim_layers`, bound as `AnimLayers`; the CHANGELOG names the old one |
| the entry's `robloxAnimatorBackend.new({ animator, resolveAssetId, ... })` | gone: the controller takes the `Animator` |
| the entry's `new({ backend, timeReader, layers })` | `AnimLayers.controllers.layerController.new(animator, layerDefinitions)` |
| the entry's `clip(clip, config)`, one node per play | `AnimLayers.utils.clipDefinition.build(assetId, looped)`, once per clip at load |
| `controller:destroy()` | `controller:deconstruct()` |
| five type parameters on every type | none |

## Layers

| 0.1 `LayerDefinition` | Now |
| --- | --- |
| `id` | `name` |
| `layerBackend = { robloxPriority = ... }` | `robloxPriority`, required |
| `logicalPriority`, the backend's `priorityBands` | gone: a layer's rank is its Roblox priority |
| `defaultFadeIn`, `defaultFadeOut` | `fadeIn`, `fadeOut` |
| `weight` | gone from the definition: `setLayerWeight(layer, weight, fadeTime?)`; a layer starts at 1 |
| `timeReader` | gone: `setLayerTimeScale(layer, rate)` |

## Calls

| 0.1 | Now |
| --- | --- |
| `controller:play(layer, motion, { state, fadeIn, timeReader, weight, looped, logicalPriority, initialPosition, forceRestart })` | `local playId = controller:play(layer, clip, speed, fadeTime)`. `looped` is the definition's, and the weight is the layer's: call `setLayerWeight` before or after. A `play` always starts the clip again. For an initial position call `setClipTime` or `setClipNormalizedTime` right after `play`. |
| `controller:setLayerSpeed(layer, speed)` | `controller:setClipSpeed(layer, speed)`, which returns the speed in effect |
| `controller:setLayerWeight(layer, weight)` | `controller:setLayerWeight(layer, weight, fadeTime?)`: written at once and not queued; while a clip plays, one engine fade |
| `controller:stopLayer(layer, fadeTime)` | `controller:stop(layer, fadeTime)` |
| `controller:setTrackPosition(trackKey, { kind = "seconds", value })` | `controller:setClipTime(layer, seconds)` |
| `controller:setTrackPosition(trackKey, { kind = "normalized", value })` | `controller:setClipNormalizedTime(layer, alpha)` |
| `controller:offsetTrackPosition(trackKey, delta)` | gone |
| `controller:setDefaultTimeReader`, `setLayerTimeReader`, `setActivePlayTimeReader` | gone. When a clock's rate changes, call `controller:setLayerTimeScale(layer, rate)`. A reader's `position` is not used by anything. |
| `controller:setParameter`, `setFloat`, `setBool`, `setTrigger` and the getters | gone, with the blends and the state machine that read them |
| `controller:on("trackCompleted", function(event) ... event.trackKey ... end)` | `controller:onPlayCompleted(function(layer, playId) ... end)` |
| `controller:onMarker(name, function(track, value) ...)`, `controller:onTrackMarker(trackKey, name, ...)` | `controller:onMarker(name, function(layer, playId, clip, value) ...)` |
| `controller:update(sampleTime)` | `controller:update()` |
| `controller:getDebugSnapshot()` | gone. `Animator:GetPlayingAnimationTracks()` shows what the engine plays. |

## Behaviour that changed

- **Commands are state.** A command still reaches the engine at the next `update`, but nothing is
  queued: several commands on one layer cost what their final state costs.
- **A position is accepted at once.** `setClipTime` after `play` needs no retry: the controller holds
  it until the track exists and its length has loaded. A caller's own "pending position" and
  one-shot bookkeeping can go.
- **A play is named by a number**, the one `play` returned, never by a `trackKey` string.
- **`update` is cheap when nothing changed.** It returns at its first statement, so a caller needs
  no dirty flag of its own in front of it.
- **Speed has a tolerance** ([layerController](../api/layerController.md#the-speed-tolerance)).
  Use the value `setClipSpeed` returns wherever you model the clip's phase.
- **Completion is reported from `update`**, never from inside an engine signal, and only for an end
  the engine reached by itself.
- **Markers are delivered inside the engine's signal**, with no queue.
- **Tracks are kept.** A clip that plays again uses the track it already loaded.
- **`update` raises when an engine call raises**, and the next `update` makes the calls that had
  not returned. Nothing is rolled back and nothing is cleared for you.
- **Looping belongs to the definition.** A consumer whose requests carry a loop flag builds two
  definitions per asset, or stores the flag with its clips.

## Removed with no replacement

Blend nodes, the state machine and its events, the parameter store, the `sampledPosition` backend
mode, `stackModifier`, the public backend contract, consumer-written motion nodes and the debug
snapshot. `docs/todo/vmmo90/apiAssessment.md` section 4.3 records how a blend would be added.
