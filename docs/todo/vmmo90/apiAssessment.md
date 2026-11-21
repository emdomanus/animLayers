# AnimLayers API assessment (VMMO-90, stage 1)

Written 2026-11-20 on the task's branch, when the package still had its 0.1 name (the CHANGELOG has it). No code changed. Stage 2 does not start until an
API is accepted.

Amended 2026-11-21: candidate C added as section 4.3 from the user's eight points, with section
5.1 and the questions C1 to C8. Sections 1 to 3 and candidates A and B are unchanged.

Decided 2026-11-21: the user chose candidate C with seven changes and answered the questions.
Section 4.3 is rewritten to the accepted API, and section 6.1 records the answers. Stage 2 builds
section 4.3.

Changed after the review, 2026-11-21, and written into section 4.3: the public `ClipDefinition`
has no `animation` field (a private type declares it); the engine side is a private object,
`trackManager`, that the controller constructs; a track is marked as fading, and its layer as not
playing, before `Stop` is called, so a `Stop` that raises is not made again.

Changed 2026-11-21, second review, and written into section 4.3: `setSpeed`, `setTime` and
`setNormalizedTime` are `setClipSpeed`, `setClipTime` and `setClipNormalizedTime`; weight is the
layer's (`setLayerWeight`), not an argument of `play`.

Built 2026-11-21: `src` is section 4.3 as written. Two things differ from the first text of that
section and are corrected in it: `deconstruct` stops a track that is still playing before it
destroys it, and the first subscriber of a marker name also creates that name's record.

- Package read at `de4cdb3`. `git diff 92fc1a7 de4cdb3 -- src` is empty, so its `src` is the tree
  VoxelMMO pins.
- VoxelMMO read at `cbbc2e50`, read only.

How each statement is marked:

| Mark | Meaning |
| --- | --- |
| `code` | Read in the source in this session. Line numbers are for the revisions above. |
| `probe` | Measured in this session; section 1.2 says how. |
| `doc` | Read from documentation in this session by a research subagent, through a fetch tool that returns a model's extraction of the page. The wording is not verbatim and I did not read the raw pages myself. |
| `defs` | Read by me in the Roblox type definitions file that compass caches for `analyze`, dated 2026-11-03. |
| `recalled` | From memory. Not evidence. |

What I read myself: every file under `src`; `docs/architecture.md`, `docs/todo/`,
`docs/research/voxelmmo-migration.md` and `CHANGELOG.md`; in VoxelMMO the animator library, the
animation domain's definitions and entry, the two plan sections, the backlog record, VMMO-90 and the
conventions skill. `tests/`, `dev/` and `scripts/` were read in full by a subagent whose report I
used; from those folders I read only `tests/bench/evaluation.luau`, `scripts/verify/tests.ps1` and
the lines this page cites. I have not read `docs/api`, `docs/guides` (beyond the Studio checklist's
first page) or `README.md`; stage 2 rewrites them.

Paths in section 1 that start with `managers/`, `common/` or `types/` are inside VoxelMMO's
`src/shared/libraries/character/animator/`. `characterVisualizer` is
`libraries/character/visualizer/managers/characterVisualizer/shared/characterVisualizer/init.luau`
and `characterClock` is `libraries/character/clock/components/characterClock/shared/characterClock/init.luau`.

## 1. How VoxelMMO uses the package today

Six files require the package, all in `libraries/character/animator` (`code`). Three of VoxelMMO's
Lune specs also name it (its consumer spec under `tests/lune/`,
`characterAnimationContracts.spec.luau`, `characterAnimator.spec.luau`); I did not read them.

### 1.1 Call sites

All calls are in `managers/characterAnimator/shared/characterAnimator/init.luau`. "Tables" counts Luau
tables the package creates for that call.

| # | Function and line | Call | Runs | Package allocates | VoxelMMO allocates beside it |
| --- | --- | --- | --- | --- | --- |
| 1 | `CharacterAnimator.new` L116 | the entry's `robloxAnimatorBackend.new(backendConfig)` | once per character | 21 tables, 1 closure | `backendConfig`, the `resolveAssetId` closure |
| 2 | `CharacterAnimator.new` L130 | the entry's `new(controllerConfig)` | once per character | 17 tables (9, and one `LayerRuntime` for each of the 8 layers), 5 closures | `controllerConfig`; `createLayerDefinitions()` builds 17 tables that are the same for every character |
| 3 | `CharacterAnimator.new` L168 | `controller:on("trackCompleted", callback)` | once per character | 1 table, 1 closure | the callback closure |
| 4 | `stageSelectedIntent` L74 | `controller:setLayerSpeed(layer, speed)` | when a layer's selected clip changes | 1 command table | |
| 5 | `stageSelectedIntent` L79 | the entry's `clip(resolvedEntry, clipConfig)` | same | 1 `ClipNode` | `clipConfig`, and the string `tostring(selected.request.clip)` |
| 6 | `stageSelectedIntent` L90 | `controller:play(layer, motion, options)` | same | 2 tables at the call (command, `copyPlayOptions`), 1 more with an initial position; at the next update 1 (`copyOverrides`) and, for the new track, 2 tables, 4 closures, 1 `Animation`, 1 `AnimationTrack`, 2 connections and the string `"rbxassetid://" .. tostring(assetId)` | `options` |
| 7 | `_stageSelection` L352, `_stageStop` L369 | `controller:stopLayer(layer, fadeOut)` | clip change or stop | 1 command table; at the next update 2 more | |
| 8 | `_stageSpeed` L379 | `controller:setLayerSpeed(layer, speed)` | every frame in which `playback:setSpeed` changes a selected clip's speed (`characterProceduralAnimator` L285: a body whose movement speed is changing) | 1 command table, and the full `controller:update` then runs that frame | |
| 9 | `_stageReader` L390 | `controller:setActivePlayTimeReader(layer, reader)` | never: only `setPlaybackTimeReader` reaches it and nothing in `src` calls that | 1 command table | |
| 10 | `_applyPhysicalPosition` L404 | `controller:setTrackPosition(trackKey, position)` | only from `playback:setPosition`, which nothing in `src` calls, and from `flushPendingPhysicalPositions` | 1 table (`copyPosition`) | the caller's `{ kind, value }` table |
| 11 | `setLayerTimeReader` L422 | `controller:setLayerTimeReader(layer, reader)` | once per character (`characterVisualizer` L264, layer `base`) | 1 command table | the reader closure |
| 12 | `setParameter` L452 | `controller:setParameter(parameter, value)` | never: nothing in `src` calls `CharacterAnimator.setParameter` | 1 command table | |
| 13 | `update` L527 | `controller:update(sampleTime)` | not every frame: see below | section 1.2 | 1 closure for `pcall`, 1 ticket array, 1 ticket for each staged layer |
| 14 | `_clearController` L208 | `controller:clear()` | detach, disable, backend failure, teardown | 9 tables | |
| 15 | `deconstruct` L566 | `controller:destroy()` | once | | |

Row 13 is the important one. `characterVisualizer._step` (L1063) calls `CharacterAnimator.update`
every frame for a shown character, but `CharacterAnimator.update` returns at L515 when
`_dirtyRevision == _appliedRevision`. So `controller:update` runs only in a frame that follows a
play, a stop, a speed change, a reader change or a target change. A character standing still or
moving at a constant speed does not enter the package at all. The cost in section 1.2 is paid in
frames where something changed, and a body that is speeding up or slowing down has such a frame
every frame (row 8).

Types the six files name: `TimeReader`, `AnimationPosition`, `LayerDefinition`, `RobloxLayerBackend`,
`ClipNodeConfig`, `LayerPlayOptions`, `RobloxAnimatorBackendConfig`, `BackendPositionMode`,
`AnimationControllerConfig`, `AnimationController`, `RobloxAnimatorBackend`, `AnimationEvent`.

### 1.2 What one `controller:update` allocates

Read from the code (`code`). Lines are in
`controller/animationController/shared/animationController/init.luau` unless a file is named.

| Site | Line | Allocates | How often |
| --- | --- | --- | --- |
| `samplesByReader` | 942 | 1 table | every update |
| `samplesByLayer` | 943 | 1 table | every update |
| `updateInvalidated` | 944 | 1 closure | every update |
| `nextCommands` | 970 | 1 table | every update |
| `backendStops` in `commitCommands` | 884 | 1 table | every update |
| `requests` | 985 | 1 table | every update |
| `pcall(function() ... end)` in `RobloxAnimatorBackend.apply` | backend `init.luau` 478 | 1 closure | every update |
| `readTimeSample` copies what the reader returned | 171 | 1 table | per distinct reader of a playing layer |
| the reader, when it builds its result | VoxelMMO `characterClock/init.luau` 29 | 1 table | same |
| the context in `LayerRuntime.evaluate` | `layerRuntime.luau` 214 | 1 table of 13 fields | per playing layer |
| the request and its one-element array in `ClipNode.evaluate` | `clipNode.luau` 116, 140 | 2 tables | per clip evaluated |
| `requests` in `Blend1DNode.evaluate`, `Blend2DNode.evaluate` | `blend1DNode.luau` 165, `blend2DNode.luau` 180 | 1 table | per blend node |
| `requests` and `copyContextWithState` in `StateMachineRuntime.evaluate` | `stateMachineRuntime.luau` 376, 123 | 1 table, and 1 per evaluated state | per state machine |

Measured (`probe`): heap growth per `controller:update` with nothing changing between updates, the
real `robloxAnimatorBackend` over the package's fake `Animator`, clips with a `trackKey`.

| Controller | Bytes per update |
| --- | --- |
| 8 layers, none playing | 416 |
| 8 layers, 1 playing | about 1,850 |
| 8 layers, 3 playing | about 4,370 |
| 8 layers, 3 playing, reader returns a new table | about 4,480 |
| 3 layers, 1 playing | about 1,850 |

How it was measured: a scratch Lune script run through `scripts/verify/tests.ps1 -Spec` on Lune
0.8.9, the package's pin. It warms up with 400 updates, then repeats: `collectgarbage("collect")`,
read `collectgarbage("count")`, run 20 updates (80 repeats) or 60 updates (40 repeats), read the
count again, and keeps the largest growth. Both batch sizes agree within 1%. Batches of 200 let a
collection run inside the batch (the heap is about 285 KB) and read three to four times lower, so I
discarded them. This is Lune's Luau and not Roblox's, and the count has 1 KB resolution. The script
is not in the repository. Your Studio measurement decides the real numbers.

Strings on the same path (`code`):

- `assert(condition, name .. " must be a number")` evaluates its second argument before `assert`
  runs. `assertFiniteNumber` (L66, L67) does this twice per call and is called for `sampleTime`
  (L932) and for each reader's position and rate (L172, L173).
- `RequestValidation.validate` runs twice per update (controller L1002, backend L463). For each
  request it evaluates `"duplicate trackKey in request batch: " .. request.trackKey`
  (`requestValidation.luau` L30) and seven `assertFinite` calls with two concatenations each.
- `ClipNode.evaluate` builds a track key by concatenation on every update when the clip has no
  `trackKey` (`clipNode.luau` L45, L117). VoxelMMO always passes one.
- `probe`: `RequestValidation.validate` on three requests grew the heap by nothing measurable. That
  shows the heap does not grow. It does not show whether each concatenation runs, and I did not
  determine that. Either way stage 2 writes these checks as `if not condition then error(...) end`,
  so no message is built unless the check fails.

### 1.3 The recorded findings, checked

From VMMO-90 and VoxelMMO's high-priority backlog record of the package's allocations:

| Recorded | Result |
| --- | --- |
| Four scratch tables in `AnimationController.update` | Confirmed (L942, L943, L970, L985). Two closures per update are missing from the record (L944, backend L478). |
| One `TimeSample` per reader | Confirmed, and it is two tables per reader when the reader builds one: the reader's, and `readTimeSample`'s copy (L171). |
| One context per layer, "or `{}` when a layer has nothing to evaluate" | One per playing layer. A layer that is not playing is never evaluated (`readLayerTimeSample` returns nil, L845), so it costs nothing. The `{}` needs a playing layer with weight 0 or no motion. |
| `backendStops` | Confirmed (L884). |
| "About 14 tables per frame" for a body controller | Not what the code does. The record leaves out the largest part, 3 tables per playing clip (context, request, array), and it is per update, not per frame: VoxelMMO skips the update in frames where nothing changed (section 1.1, row 13). |
| Not recorded | Every setter allocates a command table (`play`, `stopLayer`, `setLayerSpeed`, `setParameter`, ...). `tests/lune/evaluationReuse.spec.luau` L179 asserts that the batch and its request tables are new objects on every update, so the current tests require the allocation. |

### 1.4 Package features nothing in VoxelMMO uses

`code`, by searching `src` for each name.

- Motions other than a clip: `blend1D`, `blend2D`, `stateMachine`, with transitions, conditions and
  triggers.
- Parameters. VoxelMMO plays only clip motions, and a clip reads no parameter, so the parameter
  store has no reader: `setParameter` (forwarded, never called), `setFloat`, `getFloat`, `setBool`,
  `getBool`, `setTrigger`, `consumeTrigger`, `getParameter`, `parameterDefaults`.
- Events `stateEntered`, `stateExited`, `transitionStarted`, `transitionEnded`.
- Markers: `onMarker`, `onTrackMarker`.
- `offsetTrackPosition`, `setDefaultTimeReader`, `addLayer` after construction, `hasLayer`,
  `setLayerWeight`, the four layer getters, `setLayerLogicalPriority`, `setLayerBackend`,
  `getDebugSnapshot`.
- Backend: `positionMode = "sampledPosition"`, `priorityBands`, `defaultPriority`, `defaultFadeOut`,
  `getCapabilities`.
- `stackModifier`, the only caller of `task.delay`.
- Fields: `LayerDefinition.weight`, `.speed`, `.timeReader`; every `ClipNodeConfig` field but `name`
  and `trackKey`; `LayerPlayOptions.fadeTime`, `.trackKey`, `.speed`, `.layerBackend`.

Three things that are called but change nothing today (`code`):

- **A reader's `position`.** With `positionMode = "nativeRate"` the backend reads only
  `request.timeRate` (`animPlayback.luau` L175, L227). `timePosition` is read by
  `sampledAnimPlayback` and by `TransitionRuntime`, and VoxelMMO uses neither.
- **A reader's `rate`.** `CharacterClock.sample` returns `rate = 1` always
  (`characterClock/init.luau` L31). So the default reader, the `base` layer reader and the per-play
  reader have no effect in the engine yet.
- **`logicalPriority`.** VoxelMMO sets `layerBackend.robloxPriority` on all eight layers, and
  `RobloxAnimatorBackend._mapPriority` returns that before it looks at `logicalPriority` (backend
  L224). `ROBLOX_PRIORITY_BY_LAYER` gives `block` and `action` the same value, `Action3`, and
  `transition` and `lowAction` the same value, `Action2`. Roblox's documentation says tracks of equal
  priority blend in proportion to their weights (`doc`, RB-AP). So within each of those two pairs the
  higher layer does not override the lower one; I have not checked this in Studio.

## 2. What the new stack will need

From `docs/todo/entityRework/presentation.md` sections 5 and 7 (`code`: read in this session).

| # | The plan says | What it asks of the package | Used today |
| --- | --- | --- | --- |
| 1 | One animator object type for the body and for every animated visual component, constructed positionally with a layer list, a clip catalog and a `TimeReader`; layer ids are strings at the root | A controller constructed positionally from a layer list and a reader. String layer names, so no type parameter is needed for them | yes, with a config record |
| 2 | About 1.7 controllers per entity, all ticked by one evaluate step with the body's sample time | An `update` that costs almost nothing when nothing changed, with no engine connection or schedule of its own | the gate is in VoxelMMO, not in the package |
| 3 | Component layers `base`, `state`, `action`, with their `Enum.AnimationPriority` mapping beside the layer list | A layer-to-`Enum.AnimationPriority` mapping given at construction | yes, through `layerBackend` |
| 4 | `playByKey`, `setSpeed`, `stop`, the timing commands | play, stop, speed and a time reader per layer | yes |
| 5 | `animate(target, clip, looped?, speedFrom?)`, where `speedFrom` applies the clip's `velocityToSpeed` on every evaluation | Setting a playing clip's speed every frame must allocate nothing | allocates a command table and runs a full update |
| 6 | `setAnimationParameter(target, name, value)`, and "a `blend1D` parameter" as one way to get speed from velocity | A 1D blend driven by a named number, set every frame | **no** |
| 7 | Sequences and skills learn that a clip ended | completion reporting | yes |
| 8 | `stopAnimation(target)` | stop a layer with a fade | yes |
| 9 | The server composes the body animator for kinds with `serverPose` | the package runs on the server | yes, it is shared |
| 10 | Previews run the same animators inside a `ViewportFrame` | nothing new, but see the note below | |

Not asked for by either section: `blend2D`, state machines, triggers, graph events, markers,
`sampledPosition`, debug snapshots, the modifier stack, additive layers and joint masks. Markers are
the one I am unsure about: the package's own backlog names footsteps (VMMO-26) and native marker
acceptance (VMMO-43), and neither plan section mentions them.

Note for row 10: Roblox's documentation says `Animator:LoadAnimation` throws unless the `Animator`
is in `Workspace` (`doc`, RB-AN). A preview's `Animator` is in a `WorldModel` under a
`ViewportFrame`. The plan already marks previews "Studio check required"; this is one more reason.

**Calls on a path that can run every frame**, for either candidate:

- `update(sampleTime)`, and the time readers it calls.
- Setting a layer's speed or weight, and setting a blend parameter (rows 5 and 6).

Everything else runs on a change: construction, `play`, `stop`, setting a reader, setting a
position, subscribing, and the dispatch of a completion or a marker.

## 3. What comparable runtimes do

Seven runtimes. Source keys are listed at the end of the section. Where a runtime is missing from a
table, the pages read say nothing about that operation.

### Starting a clip

| Runtime | What it does | Source | Mark |
| --- | --- | --- | --- |
| Roblox | `Animator:LoadAnimation(animation)` returns an `AnimationTrack`; every call creates a new track, the page warns against overuse and points to `Animator:GetTrackByAnimationId`. `track:Play(fadeTime, weight, speed)` defaults to 0.1, 1, 1 | RB-AN, RB-AT | `doc` |
| Unity `Animator` | `Play(stateName or stateNameHash, layer, normalizedTime)` returns nothing | U-play | `doc` |
| Unity Playables | `AnimationClipPlayable.Create(graph, clip)` returns a struct handle | U-clipplayable | `doc` |
| Unreal | `Montage_Play(montage, playRate, ...)` returns the montage length, not a handle; later calls take the montage asset | UE-play, UE-inst | `doc` |
| Godot | `AnimationPlayer.play(name, custom_blend, custom_speed, from_end)` returns nothing; clips are named by string | G-player | `doc` |
| three.js | `mixer.clipAction(clip)` returns an `AnimationAction`, the same object for the same clip and root; `action.play()` | T-mixer, T-actionsrc | `doc` |
| Bevy | `AnimationPlayer::play(nodeIndex)` returns a mutable `ActiveAnimation`; the index comes from `AnimationGraph::add_clip` | B-player, B-graph | `doc` |
| ozz-animation | No player. The caller fills a `SamplingJob` (animation, context, ratio, output) and runs it | O-sampling | `doc` |

### Changing speed and weight

| Runtime | What it does | Source | Mark |
| --- | --- | --- | --- |
| Roblox | `AdjustSpeed(speed)`: negative plays backwards, 0 pauses. `AdjustWeight(weight, fadeTime)`. `Speed`, `WeightCurrent`, `WeightTarget` are read-only | RB-AT | `doc` |
| Unity | `Animator.speed` for the whole animator; on a playable, `SetSpeed(value)` and, on its parent, `SetInputWeight(index, weight)` | U-speed, U-setspeed, U-setinputweight | `doc` |
| Unreal | `Montage_SetPlayRate(montage, rate)`; weights are node inputs (a blend node's alpha) | UE-inst, UE-blendnodes | `doc` |
| Godot | `speed_scale` times `custom_speed`; no per-clip weight on `AnimationPlayer` | G-player | `doc` |
| three.js | `action.timeScale`, `action.weight`, `setEffectiveTimeScale`, `setEffectiveWeight` | T-action | `doc` |
| Bevy | `ActiveAnimation::set_speed`, `set_weight` | B-active | `doc` |
| ozz-animation | No speed; the caller owns time. `BlendingJob::Layer.weight` | O-sampling, O-blending | `doc` |

### Blending

| Runtime | What it does | Source | Mark |
| --- | --- | --- | --- |
| Roblox, plain tracks | Fades through `Play`, `Stop` and `AdjustWeight`; the pose is a weighted average of tracks at one priority | RB-AT | `doc` |
| Roblox, animation graph | The engine has its own graph: `AnimationGraphDefinition`, `AnimationNodeDefinition`, `StateMachineDefinition`, and `Enum.AnimationNodeType` with `ClipNode`, `Blend1DNode`, `Blend2DNode`, `StateMachineNode`, `AddNode`, `MaskNode`, `OverNode` and nine more. `AnimationTrack` has `SetParameter(key, value)`, `GetParameter`, `ParameterChanged` | definitions file | `defs` |
| Roblox, animation graph | A published graph is loaded by asset id through `LoadAnimation` and driven with `AnimationTrack:SetParameter` | RB-GE | `doc` |
| Unity | `CrossFade(state, duration, ...)`. Blend trees: 1D with a threshold per motion, 2D with a position per motion, driven by the controller's numeric parameters set with `SetFloat(name or id, value)` | U-crossfade, U-blend1d, U-setfloat | `doc` |
| Unity Playables | `AnimationMixerPlayable`; the example sets both input weights itself every frame. No crossfade or blend-tree helper | U-graph | `doc`; the absence is `recalled` |
| Unreal | Montage blend in and out; Blend Space assets with samples on a 1D or 2D graph; parameters are Animation Blueprint variables | UE-inst, UE-blendspace, UE-graphing | `doc` |
| Godot | Crossfade by `custom_blend`. `AnimationTree` nodes `BlendSpace1D`, `BlendSpace2D`, `Blend2`; a parameter is set by string property path, `animation_tree.set("parameters/...", value)` | G-player, G-bs1d, G-tree | `doc` |
| three.js | `crossFadeTo(action, duration)`, `fadeIn`, `fadeOut`; no blend-space type | T-action | `doc` |
| Bevy | `AnimationTransitions::play(player, node, duration)`; blend nodes whose children's weights are normalised | B-transitions, B-graph | `doc` |
| ozz-animation | `BlendingJob` blends poses by layer weight; the sample derives three weights from one speed value in application code | O-blending, O-runtime | `doc` |

### Layering

| Runtime | What it does | Source | Mark |
| --- | --- | --- | --- |
| Roblox, plain tracks | Seven priorities. A higher priority overrides a lower one per joint; equal priorities blend in proportion to weight. The track, animator and priority pages have no additive mode and no joint mask | RB-AP, RB-AT, RB-AN | `doc` |
| Roblox, animation graph | Additive and per-joint masks exist only as graph node types (`AddNode`, `MaskNode`, `OverNode`) | RB-NT, definitions file | `doc`, `defs` |
| Unity | Each layer has a mask and is override or additive; `SetLayerWeight(index, weight)`; a layer at weight 0 is skipped | U-layers, U-layerweight, U-perf | `doc` |
| Unreal | Layered blend per bone with a branch filter or a blend mask; additive is its own node; a slot overrides only while something plays on it | UE-blendnodes, UE-slots | `doc` |
| Godot | No layer object. `Blend2` and `Add2` with track filters | G-node, G-tree | `doc` |
| three.js | Additive blend mode per clip or action; no masks | T-r160 | `doc` |
| Bevy | Blend and additive-blend nodes; a bit mask per node | B-graph | `doc` |
| ozz-animation | Normal layers and additive layers, each with optional per-joint weights | O-blending | `doc` |

### Driving a clip from an external clock

| Runtime | What it does | Source | Mark |
| --- | --- | --- | --- |
| Roblox | `TimePosition` is writable while the track is playing, and `AdjustSpeed(0)` freezes it there. The page does not say that writing it every frame is supported. `Animator:StepAnimations(deltaTime)` is for plugins and the command bar only | RB-AT, RB-AN | `doc` |
| Unity `Animator` | `Animator.Update(deltaTime)` evaluates with the caller's delta | U-update | `doc` |
| Unity Playables | `DirectorUpdateMode.Manual` with `graph.Evaluate(deltaTime)`; `playable.SetTime(seconds)`; the example pauses the clip once and calls `SetTime` every frame | U-manual, U-evaluate, U-settime, U-timing | `doc` |
| Unreal | A Sequence Evaluator node takes an explicit time, with a flag for whether moving to it fires notifies; `Montage_SetPosition` | UE-eval, UE-inst | `doc` |
| Godot | Process mode `MANUAL` with `advance(delta)`; `seek(seconds, update)` | G-mixer, G-player | `doc` |
| three.js | `mixer.update(deltaSeconds)`; `mixer.setTime`; `action.time` is writable | T-mixer, T-action | `doc` |
| Bevy | `seek_to`, `set_seek_time`; the pages show no method that takes a caller's delta | B-active | `doc` |
| ozz-animation | Always external: the caller passes `ratio` on every run | O-sampling | `doc` |

### Reporting markers and completion

| Runtime | What it does | Source | Mark |
| --- | --- | --- | --- |
| Roblox | `track:GetMarkerReachedSignal(name)` fires with the marker's value string. `Stopped` fires when the track finishes or `Stop` is called; `Ended` fires after the fade-out is done. The pages do not say whether a marker fires when `TimePosition` is written | RB-AT, RB-KM | `doc` |
| Unity | An `AnimationEvent` calls a function by name on a script of the object. `Play` returns nothing; completion is read from `AnimatorStateInfo.normalizedTime`, or `IsDone()` on a playable | U-event, U-statetime, U-isdone | `doc` |
| Unreal | Notifies and notify states in the asset. `OnMontageEnded` and `OnMontageBlendingOut` fire whether the montage finished or was interrupted; the Play Montage node has separate completed and interrupted outputs | UE-notifies, UE-inst, UE-proxy | `doc` |
| Unreal | The ended delegate's boolean is "interrupted" | | `recalled` |
| Godot | Signal `animation_finished(name)`, not fired for a looping clip. Method-call tracks call a function per key. Markers exist but no signal fires when one is passed | G-mixer, G-animation | `doc` |
| three.js | Mixer events `finished` and `loop`, each carrying the action | T-r160, T-actionsrc | `doc` |
| Bevy | `AnimationClip::add_event(time, event)`. Completion is polled: `is_finished()`, `just_completed()` | B-clip, B-active | `doc` |
| ozz-animation | `TrackTriggeringJob` returns the edges crossed between two ratios; nothing reports completion | O-trigger | `doc` |

### Allocation on the per-frame path

| Runtime | What the documentation says | Source | Mark |
| --- | --- | --- | --- |
| Unity | Playable types are structs so that they allocate no garbage-collected memory. The performance page says to query the animator with hashes and not strings | U-graph, U-perf | `doc` |
| ozz-animation | The caller allocates and owns every job's inputs and outputs; a job owns no buffer. The pages do not state in one sentence that a job allocates nothing | O-runtime, O-advanced, O-blending | `doc` |
| Roblox, Unreal, Godot, three.js, Bevy | The pages read say nothing about it | | `doc` |

### What I take from this

These are my conclusions, not statements from a source.

- **A play is identified by an object the caller keeps or by nothing.** three.js and Bevy return the
  object and Unity Playables a struct; Unity's `Animator`, Unreal and Godot address what is playing by
  state, asset or name. No runtime read identifies a play by a string the library builds, which is
  what `trackKey` is.
- **Speed, weight and parameters are written as values, and take effect at the next evaluation.**
  None of the pages describes a queue of command records.
- **A clock is pushed, not pulled.** Every runtime read takes a delta or a time from the caller
  (`Evaluate(deltaTime)`, `advance(delta)`, `update(delta)`, `SetTime`, `seek`, `ratio`). None takes
  a function that it calls for a position and a rate, which is what `TimeReader` is. On Roblox a game
  script cannot step an `Animator`, so a clock reaches a native track only as a speed.
- **Masks and additive layers are standard elsewhere and unavailable to this package.** Roblox
  offers them only inside its own animation graph. A graph built from track weights, as this package
  was, cannot add them.
- **The engine now ships the node kinds this package implements.** The definitions file has them as
  of 2026-11-03. I could not learn from documentation how mature or fast that graph is, or whether a
  graph can be built from VoxelMMO's clip catalog at run time.

### Sources

- Roblox, prefix `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/`:
  RB-AT `reference/engine/classes/AnimationTrack.yaml`, RB-AN `reference/engine/classes/Animator.yaml`,
  RB-AP `reference/engine/enums/AnimationPriority.yaml`, RB-KM `reference/engine/classes/KeyframeMarker.yaml`,
  RB-NT `reference/engine/enums/AnimationNodeType.yaml`, RB-GE `animation/graph-editor.md`.
  Definitions file: `.cache/roblox/globalTypes.d.luau` in the workflowCompass checkout.
- Unity, prefix `https://docs.unity.com/en-us/engine/current/`: U-play
  `script-reference/unityengine/animator/play`, U-crossfade `.../animator/crossfade`, U-setfloat
  `.../animator/setfloat`, U-speed `.../animator/speed`, U-layerweight `.../animator/setlayerweight`,
  U-update `.../animator/update`, U-clipplayable `.../animations/animationclipplayable`, U-setspeed
  `.../playables/playableextensions/setspeed`, U-setinputweight `.../playableextensions/setinputweight`,
  U-settime `.../playableextensions/settime`, U-isdone `.../playableextensions/isdone`, U-manual
  `.../playables/directorupdatemode`, U-evaluate `.../playables/playablegraph/evaluate`, U-event
  `.../animationevent`, U-statetime `.../animatorstateinfo/normalizedtime`, U-graph
  `manual/animation-section/animation-mecanim/playables/graph`, U-timing
  `.../playables/examples/ex-control-timing`, U-perf `.../mecanim-peformanceand-optimization`,
  U-layers `.../animation-animator-controller/animation-state-machines/animation-layers`, U-blend1d
  `.../animation-state-machines/animation-blend-trees/blend-tree-1dblending`.
- Unreal, prefix `https://dev.epicgames.com/documentation/en-us/unreal-engine/`: UE-inst
  `API/Runtime/Engine/Animation/UAnimInstance?application_version=5.5`, UE-play
  `API/Runtime/Engine/Animation/UAnimInstance/Montage_Play?application_version=5.5`, UE-eval
  `API/Runtime/AnimGraphRuntime/AnimNodes/FAnimNode_SequenceEvaluator?application_version=5.5`,
  UE-slots `animation-slots-in-unreal-engine`, UE-blendnodes
  `animation-blueprint-blend-nodes-in-unreal-engine`, UE-blendspace `blend-spaces-in-unreal-engine`,
  UE-notifies `animation-notifies-in-unreal-engine`, UE-graphing
  `graphing-in-animation-blueprints-in-unreal-engine`, UE-proxy
  `python-api/class/PlayMontageCallbackProxy`.
- Godot, prefix `https://docs.godotengine.org/en/stable/`: G-player
  `classes/class_animationplayer.html`, G-mixer `classes/class_animationmixer.html`, G-tree
  `tutorials/animation/animation_tree.html`, G-bs1d `classes/class_animationnodeblendspace1d.html`,
  G-node `classes/class_animationnode.html`, G-animation `classes/class_animation.html`.
- three.js: T-action `https://threejs.org/docs/pages/AnimationAction.html`, T-mixer
  `https://threejs.org/docs/pages/AnimationMixer.html`, T-actionsrc
  `https://raw.githubusercontent.com/mrdoob/three.js/dev/src/animation/AnimationAction.js`, T-r160
  `https://raw.githubusercontent.com/mrdoob/three.js/r160/docs/api/en/animation/AnimationAction.html`.
- Bevy 0.20.1, prefix `https://docs.rs/bevy/latest/bevy/animation/`: B-player
  `struct.AnimationPlayer.html`, B-active `struct.ActiveAnimation.html`, B-graph
  `graph/struct.AnimationGraph.html`, B-transitions `transition/struct.AnimationTransitions.html`,
  B-clip `struct.AnimationClip.html`.
- ozz-animation: O-runtime
  `https://guillaumeblanc.github.io/ozz-animation/documentation/animation_runtime/`, O-advanced
  `https://guillaumeblanc.github.io/ozz-animation/documentation/advanced/`, and, under
  `https://raw.githubusercontent.com/guillaumeblanc/ozz-animation/master/include/ozz/animation/runtime/`,
  O-sampling `sampling_job.h`, O-blending `blending_job.h`, O-trigger `track_triggering_job.h`.

## 4. Candidate APIs

### 4.0 What candidates A and B share

1. **Commands are state, not a queue.** Today every setter appends a record to `_pendingCommands`
   and `update` commits them. In both candidates a setter writes one field of the layer it names,
   and `update` reads those fields. A getter returns what was just set. That is where the
   per-command table goes.
2. **A quiet update returns early inside the package.** `update(sampleTime)` calls each time reader
   in use once. If no command changed anything since the last evaluation and no reader's rate
   changed, it returns. VoxelMMO's `_dirtyRevision` gate is then not needed.
3. **Records that outlive the update.** Each clip keeps one record that is rewritten in place; the
   controller keeps its arrays and clears them. Nothing is created to carry one update's result.
4. **`TimeReader = (sampleTime: number) -> (number, number)`**: position, then rate.
5. **No strings.** A play is identified by an object or a number the caller already holds, never by
   a key the package concatenates. A check is `if not condition then error(...) end`.
6. **No type parameters.** Layer, parameter and state names are `string`. A clip is a Roblox
   animation asset id, a `number`; callbacks hand back the caller's own object or number. Today's
   five parameters exist to type the layer id, the state id, the parameter name, the clip and the
   backend's per-layer data. The plan uses strings for layers at its root, and VoxelMMO needs a
   cast today to make the parameters line up (`characterAnimator/init.luau` L117).
7. **Positional constructors.** Every object here is built per entity, so compass allows no options
   record.
8. **Subscriptions are `on<Event>(callback)` and return a function that unsubscribes.** Callbacks
   take positional arguments, not an event table.
9. **`deconstruct`, not `destroy`.** `update`, `clear` and `deconstruct` are on the `Owned` view
   that `new` returns, as compass places lifecycle.
10. **No scheduler parameter, because nothing is deferred.** Fades run in the engine and a retired
    track is cleaned up from its `Ended` signal. `stackModifier` is the only caller of `task.delay`
    and both candidates remove it (question 6 gives its signature if you keep it).
11. **Names.** `AnimationController` is a Roblox class, so the object is renamed. `AnimationPlayer`,
    `AnimationNode` and `StateMachineDefinition` are Roblox classes too (`defs`), so no type takes
    those names. `ClipNode`, `Blend1DNode`, `Blend2DNode` and `StateMachineNode` are not classes but
    are items of `Enum.AnimationNodeType` (`defs`); candidate A avoids them as well.
12. **Layout.** `src/` is the package root with `shared.luau` as its one entry and the compass
    categories directly beneath it. The package is entirely shared and says so once.

### 4.1 Candidate A: the general graph

Motions, blends, layers and parameters, evaluated by one controller into a backend. Entry, by
category because it exports three:

```luau
local AnimLayers = require(...)   -- src/shared.luau
AnimLayers.controllers.graphController.new
AnimLayers.components.clipMotion.new
AnimLayers.components.blend1DMotion.new
AnimLayers.components.blend2DMotion.new
AnimLayers.managers.robloxAnimatorBackend.new
```

Public types:

```luau
export type TimeReader = (sampleTime: number) -> (number, number)
export type Unsubscribe = () -> ()

-- Motions. Built by the caller, held by the caller, and handed back in callbacks.
-- A motion object plays on one layer of one controller at a time.
export type Motion = { read kind: "clip" | "blend1D" | "blend2D" }
export type ClipMotion = Motion & {
	read assetId: number,
	read looped: boolean,
	read speed: number,
	read weight: number,
}
export type Blend1DMotion = Motion & { read parameter: string }
export type Blend2DMotion = Motion & { read parameterX: string, read parameterY: string }

clipMotion.new(assetId: number, looped: boolean?, speed: number?, weight: number?): ClipMotion
blend1DMotion.new(parameter: string, thresholds: { number }, motions: { Motion }, defaultValue: number?): Blend1DMotion
blend2DMotion.new(
	parameterX: string, parameterY: string,
	xs: { number }, ys: { number }, motions: { Motion },
	maxInfluences: number?
): Blend2DMotion

export type LayerDefinition = {
	read name: string,
	read fadeIn: number?,          -- seconds, default 0.2
	read fadeOut: number?,         -- seconds, default 0.2
	read weight: number?,          -- default 1
	read speed: number?,           -- default 1
	read timeReader: TimeReader?,  -- default: the controller's
}

export type GraphController = {
	-- Commands: each writes the controller's state at the call; the engine sees it at the next update.
	read play: (self: GraphController, layer: string, motion: Motion, fadeTime: number?) -> (),
	read stop: (self: GraphController, layer: string, fadeTime: number?) -> (),
	read setLayerWeight: (self: GraphController, layer: string, weight: number) -> (),
	read setLayerSpeed: (self: GraphController, layer: string, speed: number) -> (),
	read setLayerTimeReader: (self: GraphController, layer: string, timeReader: TimeReader?) -> (),
	read setNumber: (self: GraphController, parameter: string, value: number) -> (),

	-- The engine position of one clip, applied at the call. Accepted from the moment the clip's
	-- motion is played, before its track exists. False when the clip is in no playing motion.
	read setClipTime: (self: GraphController, clip: ClipMotion, seconds: number) -> boolean,
	read setClipNormalizedTime: (self: GraphController, clip: ClipMotion, alpha: number) -> boolean,
	read offsetClipTime: (self: GraphController, clip: ClipMotion, deltaSeconds: number) -> boolean,

	-- Reads of what was last set.
	read getLayerWeight: (self: GraphController, layer: string) -> number,
	read getLayerSpeed: (self: GraphController, layer: string) -> number,
	read getNumber: (self: GraphController, parameter: string) -> number?,
	read getDebugSnapshot: (self: GraphController) -> GraphControllerDebugSnapshot,   -- allocates

	-- Events, dispatched after the update that caused them has finished writing to the engine.
	read onClipCompleted: (self: GraphController, callback: (clip: ClipMotion) -> ()) -> Unsubscribe,
	read onMarker: (
		self: GraphController,
		markerName: string,
		callback: (clip: ClipMotion, value: string) -> ()
	) -> Unsubscribe,
}

export type GraphControllerOwned = GraphController & {
	read update: (self: GraphControllerOwned, sampleTime: number) -> (),
	read clear: (self: GraphControllerOwned) -> (),
	read deconstruct: (self: GraphControllerOwned) -> (),
}

graphController.new(
	backend: GraphBackend,
	layerDefinitions: { LayerDefinition },
	timeReader: TimeReader
): GraphControllerOwned

-- What the controller asks of a backend. robloxAnimatorBackend is the one implementer.
export type ClipBatch = {       -- owned by the controller, borrowed for the call, rows 1..count
	count: number,
	clips: { ClipMotion },
	layers: { string },
	weights: { number },        -- layer and blend weights multiplied in
	speeds: { number },         -- signed; layer speed and the reader's rate multiplied in
	fadeTimes: { number },
}
export type GraphBackend = {
	read apply: (self: GraphBackend, batch: ClipBatch) -> (),
	read setClipTime: (self: GraphBackend, clip: ClipMotion, seconds: number) -> boolean,
	read setClipNormalizedTime: (self: GraphBackend, clip: ClipMotion, alpha: number) -> boolean,
	read offsetClipTime: (self: GraphBackend, clip: ClipMotion, deltaSeconds: number) -> boolean,
	read onClipCompleted: (self: GraphBackend, callback: (clip: ClipMotion) -> ()) -> Unsubscribe,
	read onMarker: (
		self: GraphBackend,
		markerName: string,
		callback: (clip: ClipMotion, value: string) -> ()
	) -> Unsubscribe,
	read clear: (self: GraphBackend) -> (),
	read deconstruct: (self: GraphBackend) -> (),
}

robloxAnimatorBackend.new(
	animator: Animator,
	robloxPriorityByLayer: { read [string]: Enum.AnimationPriority }
): GraphBackend
```

`GraphControllerDebugSnapshot` keeps today's content (parameters, a row per layer, a row per engine
track) with the type parameters removed; the `dev` place reads it.

How it evaluates without allocating: `update` walks each playing layer's motion. A blend computes
its weights into an array it owns and calls its children with a weight. A clip writes one row of the
controller's `ClipBatch`. The backend compares each row with what it last applied to that clip's
track and calls the engine only for a difference; a track whose clip has no row this update is
retired.

Every VoxelMMO call site, rewritten:

```luau
-- 1, 2, 3: construction, once per animator. CharacterAnimationLayers.definitions is passed as it
-- is; the 17 tables that createLayerDefinitions built per character are not needed.
local backend = AnimLayers.managers.robloxAnimatorBackend.new(animator, ROBLOX_PRIORITY_BY_LAYER)
local controller = AnimLayers.controllers.graphController.new(backend, CharacterAnimationLayers.definitions, timeReader)
self._unsubscribeClipCompleted = controller:onClipCompleted(function(clip)
	self._playbackArbitrator:handleClipCompleted(clip)
end)

-- 4, 5, 6: a layer's selected clip changes
local clip = AnimLayers.components.clipMotion.new(resolvedEntry.definition.assetId, request.looped == true, 1, request.weight)
entry._clip = clip
controller:setLayerSpeed(layer, entry._speed)
controller:setLayerTimeReader(layer, entry._reader)        -- nil restores the layer's own reader
controller:play(layer, clip, request.fadeIn)
if initialSeconds ~= nil then
	controller:setClipTime(clip, initialSeconds)
end

-- 7: stop
controller:stop(layer, fadeOut)
-- 8: speed, every frame while it changes
controller:setLayerSpeed(layer, speed)
-- 9: the per-play reader is the layer's reader for as long as that play is selected
controller:setLayerTimeReader(layer, reader)
-- 10: position
controller:setClipTime(entry._clip, seconds)
controller:setClipNormalizedTime(entry._clip, alpha)
-- 11: once
controller:setLayerTimeReader("base", worldReader)
-- 12: a blend parameter
controller:setNumber(parameter, value)
-- 13: every frame
controller:update(sampleTime)
-- 14, 15
controller:clear()
controller:deconstruct()
```

What each call allocates in the package:

| Call | Tables | Closures | Strings | Path |
| --- | --- | --- | --- | --- |
| `update`, quiet or not | 0 | 0 | 0 | every frame |
| `setLayerSpeed`, `setLayerWeight`, `setNumber` | 0 | 0 | 0 | can be every frame |
| a time reader's result | 0 | 0 | 0 | every frame |
| `clipMotion.new` | 1 | 0 | 0 | on a change of clip |
| `play`, `stop`, `setLayerTimeReader`, `setClipTime`, `setClipNormalizedTime` | 0 | 0 | 0 | on a change |
| the first update after a `play`, per new engine track | 1 record | 2, one per signal connection | the content id, unless tracks are reused (question 10) | on a change |
| `onClipCompleted`, `onMarker` | 1 entry | 1 | 0 | at subscription |
| `clear` | 0 | 0 | 0 | on a change |
| `robloxAnimatorBackend.new`, `graphController.new` | a fixed set, and one record per layer | 0 | 0 | construction |

In VoxelMMO the `clipConfig` table, the `options` table, the `tostring` and the position table go
as well. So does the bookkeeping that exists because today's options are one-shot and a position is
refused before the track exists: `captureUpdateTickets`, `acceptUpdateTickets`,
`flushPendingPhysicalPositions` and the `_entriesByTrackKey` map.

What candidate A removes:

- The command queue: `GraphIntentCommand`, `_pendingCommands`, and "a setter takes effect on the next
  update" as something a getter can observe. The controller spec pins that today (a getter returns
  the old value until `update`), and those cases change.
- The public evaluation contract: `MotionNode.evaluate(context)`, `MotionEvaluateContext`,
  `ClipRequest`, `MotionRequestOverrides`. A consumer can no longer write its own motion; today only
  the tests do.
- Track keys: `trackKey` in `ClipNodeConfig` and `LayerPlayOptions`, `setTrackPosition(trackKey)`,
  `onTrackMarker(trackKey)`, `TrackMarkerSource`, the duplicate-key check, `TrackCompletedEvent`.
- `LayerPlayOptions`. Its `fadeTime` is a parameter of `play`; `looped`, `speed`, `weight` are the
  clip's; `initialPosition` is `setClipTime` after `play`; `forceRestart` is playing a clip again,
  which always starts it again; `state` goes.
- `AnimationPosition` and `TimeSample` as tables.
- `setActivePlayTimeReader` and `setDefaultTimeReader`. Two reader levels remain: the controller's
  and a layer's.
- `logicalPriority`, `LogicalPriorityBand`, `priorityBands`, `defaultPriority`, `RobloxLayerBackend`,
  `setLayerLogicalPriority`, `setLayerBackend`: the backend takes the mapping once.
- `addLayer`, `hasLayer`, `BackendCapabilities`, `getCapabilities`.
- `positionMode` and `sampledAnimPlayback` (question 2).
- The state machine: `stateMachineRuntime`, `transitionRuntime`, triggers, boolean and string
  parameter values, and the events `stateEntered`, `stateExited`, `transitionStarted`,
  `transitionEnded` (question 1 gives its signatures if you keep it).
- `on(name, callback)` and the `AnimationEvent` union.
- `stackModifier`.
- All five type parameters.
- The second names on the entry: `new`, `clip`, `blend1D`, `blend2D`, `stateMachine`.

### 4.2 Candidate B: clips on layers

One object over a Roblox `Animator`. A layer plays one clip, or one blend of clips along one
number. There are no motion objects, no parameter store and no backend contract. The entry is flat
because it exports one category; the package name would no longer describe it.

```luau
local AnimLayers = require(...)   -- src/shared.luau
AnimLayers.clipLayerController.new
```

```luau
export type TimeReader = (sampleTime: number) -> (number, number)
export type Unsubscribe = () -> ()

export type ClipLayerDefinition = {
	read name: string,
	read robloxPriority: Enum.AnimationPriority,
	read fadeIn: number?,          -- seconds, default 0.2
	read fadeOut: number?,         -- seconds, default 0.2
	read timeReader: TimeReader?,  -- default: the controller's
}

-- Authored once and frozen; every controller that plays it shares it.
export type ClipBlendDefinition = {
	read thresholds: { number },   -- ascending
	read assetIds: { number },     -- one per threshold
	read looped: boolean,
}

export type ClipLayerController = {
	-- Each returns the play's id, a number that counts up per controller.
	read play: (
		self: ClipLayerController, layer: string, assetId: number,
		looped: boolean?, fadeTime: number?, speed: number?, weight: number?, startSeconds: number?
	) -> number,
	read playBlend: (
		self: ClipLayerController, layer: string, definition: ClipBlendDefinition,
		fadeTime: number?, speed: number?, weight: number?
	) -> number,
	read stop: (self: ClipLayerController, layer: string, fadeTime: number?) -> (),
	read setSpeed: (self: ClipLayerController, layer: string, speed: number) -> (),
	read setWeight: (self: ClipLayerController, layer: string, weight: number) -> (),
	read setBlendValue: (self: ClipLayerController, layer: string, value: number) -> (),
	read setTime: (self: ClipLayerController, layer: string, seconds: number) -> boolean,
	read setNormalizedTime: (self: ClipLayerController, layer: string, alpha: number) -> boolean,
	read setLayerTimeReader: (self: ClipLayerController, layer: string, timeReader: TimeReader?) -> (),
	-- A layer's clip that does not loop reached its end. Not fired for stop or replacement.
	read onCompleted: (self: ClipLayerController, callback: (layer: string, playId: number) -> ()) -> Unsubscribe,
}

export type ClipLayerControllerOwned = ClipLayerController & {
	read update: (self: ClipLayerControllerOwned, sampleTime: number) -> (),
	read clear: (self: ClipLayerControllerOwned) -> (),
	read deconstruct: (self: ClipLayerControllerOwned) -> (),
}

clipLayerController.new(
	animator: Animator,
	layerDefinitions: { ClipLayerDefinition },
	timeReader: TimeReader
): ClipLayerControllerOwned
```

Every VoxelMMO call site, rewritten:

```luau
-- 1, 2, 3: construction. The layer definitions carry robloxPriority.
local controller = AnimLayers.clipLayerController.new(animator, CharacterAnimationLayers.definitions, timeReader)
self._unsubscribeCompleted = controller:onCompleted(function(layer, playId)
	self._playbackArbitrator:handleCompleted(layer, playId)
end)

-- 4, 5, 6: a layer's selected clip changes
controller:setLayerTimeReader(layer, entry._reader)
entry._playId = controller:play(
	layer, resolvedEntry.definition.assetId,
	request.looped == true, request.fadeIn, entry._speed, request.weight, initialSeconds
)

-- 7
controller:stop(layer, fadeOut)
-- 8: every frame while it changes
controller:setSpeed(layer, speed)
-- 9
controller:setLayerTimeReader(layer, reader)
-- 10
controller:setTime(layer, seconds)
controller:setNormalizedTime(layer, alpha)
-- 11
controller:setLayerTimeReader("base", worldReader)
-- 12: a component's blend, once at mount and then every frame
controller:playBlend("base", WING_SPEED_BLEND, 0.2)
controller:setBlendValue("base", value)
-- 13, 14, 15
controller:update(sampleTime)
controller:clear()
controller:deconstruct()
```

What each call allocates in the package:

| Call | Tables | Closures | Strings | Path |
| --- | --- | --- | --- | --- |
| `update`, quiet or not | 0 | 0 | 0 | every frame |
| `setSpeed`, `setWeight`, `setBlendValue` | 0 | 0 | 0 | can be every frame |
| a time reader's result | 0 | 0 | 0 | every frame |
| `play`, `playBlend`, `stop`, `setLayerTimeReader`, `setTime`, `setNormalizedTime` | 0 | 0 | 0 | on a change |
| the first update after a `play`, per new engine track | 1 record | 2 | the content id, unless tracks are reused | on a change |
| `onCompleted` | 1 entry | 1 | 0 | at subscription |
| `clipLayerController.new` | a fixed set, and one record per layer | 0 | 0 | construction |

What candidate B removes: everything candidate A removes, and also

- motion objects, and with them nested blends (a blend of blends) and a blend inside a blend's sample;
- `blend2D`;
- the named parameter store: a blend's number is set on its layer;
- the backend contract and the fake backend the controller tests use;
- markers;
- `offsetTrackPosition`, the layer getters and the debug snapshot.

### 4.3 Candidate C: layers that play shared clip definitions

Added 2026-11-21 from your eight points, and amended the same day with your seven changes and your
answers; this is the accepted API and what stage 2 builds. It keeps 4.0 except items 2 and 4: there
is no `TimeReader`, and `update` takes no argument and makes no call at all when nothing changed.

The model:

```luau
ClipDefinition = {                               -- built once, shared by every controller
	assetId: number, looped: boolean,
	animation: Animation,                        -- the one Instance for this definition; private
}
LayerController = {
	layers: { [string]: Layer },                 -- fixed at construction
	tracks: { Track },                           -- every AnimationTrack this controller has loaded
}
Layer = {
	robloxPriority: Enum.AnimationPriority,
	weight: number,                              -- 1 until setLayerWeight; stays across plays
	timeScale: number,                           -- 1 until setLayerTimeScale; stays across plays
	play: Play?,                                 -- one clip, or nothing
}
Play = {
	id: number,                                  -- what `play` returned
	clip: ClipDefinition,
	speed: number,                               -- the clip's; set by each play
}
-- the speed the engine is given for a play's track:
nativeSpeed = play.speed * layer.timeScale
```

A command writes these fields and nothing else. `update()` is the only place the package calls the
engine. Its first statement is `if not self._changed then return end`. `_changed` is set by a
command that changed a field, by an engine signal that reported an end, and it stays set while a
track that was given a position is waiting for its `Length` to load; in those updates the package
reads `Length` once per waiting track.

**An engine call that raises** (change 1). `update` does not catch: it raises with the engine's
error. Afterwards the command fields are as the caller left them, the controller has recorded as
applied exactly the engine calls that returned, and `_changed` is still set, so the next `update`
makes the remaining calls again. A `Stop` that raised is the exception, since the review: its track
is marked as fading and its layer as not playing before the call, so that an `Ended` arriving
inside `Stop` returns the track to idle, and the `Stop` is not made again.

Entry, by category because it exports two:

```luau
local AnimLayers = require(...)   -- src/shared.luau
AnimLayers.controllers.layerController.new
AnimLayers.utils.clipDefinition.build
```

Public types:

```luau
export type Unsubscribe = () -> ()

-- Built once and frozen. `build` also creates the one Animation Instance for this asset id and
-- loop flag, which every controller on this machine loads its tracks from. It is never destroyed.
-- The definition carries it under `animation`, a field only the private type ClipDefinitionImpl
-- declares.
export type ClipDefinition = {
	read assetId: number,
	read looped: boolean,
}
clipDefinition.build(assetId: number, looped: boolean): ClipDefinition

export type LayerDefinition = {
	read name: string,
	read robloxPriority: Enum.AnimationPriority,
	read fadeIn: number?,          -- seconds; the fade `play` uses when it is given none
	read fadeOut: number?,         -- seconds; the fade `stop` uses when it is given none
}

export type LayerController = {
	-- Replaces what the layer plays. Returns the play's id, a number that counts up per controller.
	read play: (
		self: LayerController, layer: string, clip: ClipDefinition,
		speed: number?, fadeTime: number?
	) -> number,
	read stop: (self: LayerController, layer: string, fadeTime: number?) -> (),

	-- These address the clip playing on the layer and do nothing when the layer plays nothing.
	-- setClipSpeed returns the clip's speed after the call (see the tolerance below), or nil.
	read setClipSpeed: (self: LayerController, layer: string, speed: number) -> number?,
	read setClipTime: (self: LayerController, layer: string, seconds: number) -> (),
	read setClipNormalizedTime: (self: LayerController, layer: string, alpha: number) -> (),

	-- These set a value of the layer, with or without a clip playing; both values stay across
	-- plays and start at 1. A clip plays at the layer's weight, and the engine is given the clip's
	-- speed times the layer's time scale.
	read setLayerWeight: (self: LayerController, layer: string, weight: number, fadeTime: number?) -> (),
	read setLayerTimeScale: (self: LayerController, layer: string, rate: number) -> (),

	read onPlayCompleted: (
		self: LayerController,
		callback: (layer: string, playId: number) -> ()
	) -> Unsubscribe,
	read onMarker: (
		self: LayerController,
		markerName: string,
		callback: (layer: string, playId: number, clip: ClipDefinition, value: string) -> ()
	) -> Unsubscribe,
}

export type LayerControllerOwned = LayerController & {
	read update: (self: LayerControllerOwned) -> (),
	read clear: (self: LayerControllerOwned) -> (),
	read deconstruct: (self: LayerControllerOwned) -> (),
}

layerController.new(animator: Animator, layerDefinitions: { LayerDefinition }): LayerControllerOwned
```

The code that owns engine tracks is `trackManager`, a private object the controller constructs: it
loads tracks, keeps and drops them, holds the signal connections and makes every engine call. The
controller keeps the layers, the play ids, the speed tolerance and the completion reports. The entry
exports nothing of `trackManager`, and the tests drive the controller over a fake `Animator`.

**Tracks are kept** (changes 6 and 7).

- `clipDefinition.build` creates the definition's `Animation` Instance once. No controller creates
  or destroys an `Animation`.
- A controller keeps every `AnimationTrack` it loads, with its two signal connections, and plays it
  again the next time that clip definition is played while the track is idle. A track is idle from
  its `Ended` signal, or from `clear`, until it is played.
- While a clip's track is still fading out, a new play of that clip loads a second track for it.
- Tracks are destroyed at `deconstruct`, and when a load takes the count above the cap: then the
  idle track that was played longest ago is destroyed. A track that is playing or fading out is
  never destroyed for the cap, so the count can pass the cap by the number of busy tracks.
- **The cap** is 64 kept tracks per controller, a named constant in the controller. Roblox's limit does
  not set it: what I found limits the tracks playing at once on one `Animator`, not the tracks
  loaded. Roblox staff wrote on the DevForum in January 2026 that the limit is 64 tracks playing at
  once on one character, and in November 2025 (when it was 256) that only tracks playing on the
  animator count; a community test loaded 300 tracks without playing them and got no warning. The
  official `Animator` and `AnimationTrack` pages state no limit. Sources, read in this session by a
  subagent through a fetch tool: `https://devforum.roblox.com/t/4200275/46.json`,
  `https://devforum.roblox.com/t/4067247/2.json`, `https://devforum.roblox.com/t/2577096.json`.
  A controller plays at most one track per layer plus the tracks still fading out, so it stays far
  below 64 playing. The cap is therefore a memory bound of my choosing: 64 is more than the distinct
  clips I expect one body to cycle through, and a dropped track only costs a `LoadAnimation` the next
  time its clip plays. I could not find what a loaded, idle track costs in memory.

**Fades and differences** (point 5).

- The package never changes a weight over time itself. `play` passes its fade to `Play`, `stop` to
  `Stop`, and `setLayerWeight(layer, weight, fadeTime?)` to `AdjustWeight`; an absent fade leaves the
  argument out, so the engine's default applies, 0.1 s (`doc`, RB-AT).
- A `play` on a layer that already has a play stops the outgoing track with the new play's fade.
  A `stop(layer, fadeTime)` called before that `play`, in the same frame, gives the outgoing track
  its own fade instead.
- `update` calls the engine only for a field that differs from what it last gave the engine.
- **Speed tolerance.** `setClipSpeed(layer, speed)` replaces the clip's speed only when
  `math.abs(speed - current) > math.max(0.005, 0.01 * math.max(math.abs(speed), math.abs(current)))`,
  or when exactly one of the two is 0, or when their signs differ. Otherwise the clip keeps
  `current`. Either way it returns the clip's speed. These are the numbers VoxelMMO already uses in
  `stabilizePlaybackSpeed` (`characterProceduralAnimator` L33, L34, L103), which VoxelMMO can then
  delete; the return value is what its locomotion phase must use.
- `setLayerWeight`, `setLayerTimeScale` and the position setters apply on any difference. With

**What fires `onPlayCompleted`** (point 7, change 2).

| Event | Fires? |
| --- | --- |
| A natural end | Yes, once, from `update`. |
| `stop` | No. |
| Replacement by another `play` on the layer | No. |
| `clear`, `deconstruct` | No. |

- A natural end is: the play does not loop, and its track reaches the end its signed native speed
  points to. That happens when the engine fires `Stopped` or `Ended` on the track while the play is
  the layer's play and the package has not stopped it; or when `setClipTime`, `setClipNormalizedTime` or a
  change of speed leaves the track on that end. These are the package's current rules (`code`),
  which the changelog records as accepted in Studio.
- The engine's signal only records the end on the layer and sets `_changed`. The callbacks are
  called from `update`, after it has made its engine calls, and never from inside an engine signal.
  The layer is already empty when a callback runs. A command made inside a callback is applied by
  the next `update`.
- A recorded end fires only if its play is still the layer's play when `update` reaches it. If the
  caller stopped, replaced or cleared that play between the engine's report and the `update`,
  nothing fires.
- A looping play never completes. A play whose native speed is 0 does not complete while it is 0.
- The other three fire nothing because the caller made each of them happen in the same call and
  holds the id of the play it ended.
- If a looping play's track ends without the package having stopped it, the package plays it again
  at the next `update` and fires nothing (today's behaviour).

**Markers** (change 3). `onMarker(markerName, callback)` connects
`GetMarkerReachedSignal(markerName)` on every track the controller has loaded, and on every track
it loads later, for as long as that name has a subscriber. The connected function calls the
subscribers directly, inside the engine's signal, when its track is the current play of a layer; a
track that is fading out or idle delivers nothing. Nothing is queued. A command a subscriber makes
is applied by the next `update`.

**Two layers with the same Roblox priority** (point 8). The package accepts it and does nothing
special. Both layers' tracks get that `Priority`, and Roblox blends them in proportion to their
weights, normalised when the weights sum to more than 1 (`doc`, RB-AP): two full-weight plays share
a joint half and half. The order of `layerDefinitions` decides nothing. `new` rejects only a
repeated layer name.

- It does not imitate an override by lowering the other layer's weight. A real override is per
  joint: the lower layer still shows on the joints the upper clip does not move. A lowered weight
  would silence it on every joint.
- It does not reject equal priorities, because Roblox has seven values and VoxelMMO's body has
  eight layers.
- For VoxelMMO this means `block` with `action`, and `transition` with `lowAction`, keep blending
  as they do today (section 1.4).

Every VoxelMMO call site, rewritten:

```luau
-- At load, in the animator library: one definition per catalog clip and loop flag, shared by every
-- animator. VoxelMMO's requests carry `looped` per request and its catalog has no such field, so
-- the library builds both. Adding `looped` to the catalog instead is VoxelMMO's choice.
loopingClips[clip.id] = AnimLayers.utils.clipDefinition.build(clip.definition.assetId, true)
onceClips[clip.id] = AnimLayers.utils.clipDefinition.build(clip.definition.assetId, false)

-- 1, 2, 3: construction, once per animator. No backend, no time reader.
local controller = AnimLayers.controllers.layerController.new(animator, CharacterAnimationLayers.definitions)
self._unsubscribePlayCompleted = controller:onPlayCompleted(function(layer, playId)
	self._playbackArbitrator:handlePlayCompleted(layer, playId)
end)

-- 4, 5, 6: a layer's selected clip changes
if previous ~= nil then
	controller:stop(layer, previous.request.fadeOut)      -- only to give the outgoing play its own fade
end
local clips = if request.looped == true then loopingClips else onceClips
controller:setLayerWeight(layer, request.weight or 1)     -- the weight is the layer's: set it for each selection
if initialSeconds ~= nil then
	controller:setClipTime(layer, initialSeconds)
end

-- 7: stop
controller:stop(layer, fadeOut)
-- 8: speed, every frame while it changes; the returned speed is the one in effect
entry._speed = controller:setClipSpeed(layer, speed)
-- 9, 11: the three reader levels are gone. When a clock's rate changes:
controller:setLayerTimeScale(layer, rate)                 -- no call today: CharacterClock's rate is always 1
-- 10: position
controller:setClipTime(layer, seconds)
controller:setClipNormalizedTime(layer, alpha)
-- 12: there is no parameter and no blend; CharacterAnimator.setParameter has no caller and goes
-- 13: every frame
controller:update()
-- 14, 15
controller:clear()
controller:deconstruct()
```

`playWithTimeReader` and `setPlaybackTimeReader` have no equivalent; nothing in `src` calls them.
`handlePlayCompleted(layer, playId)` compares `playId` with the id stored on the layer's selected
entry, so `_entriesByTrackKey` is not needed.

What each call allocates, and which engine calls the next `update` makes because of it:

| Call | Luau allocation | Engine calls |
| --- | --- | --- |
| `update`, nothing changed | none | none; no Luau call either |
| `update`, a track waiting for `Length` | none | 1 `Length` read per waiting track |
| `clipDefinition.build` | 1 table, 1 string | `Instance.new("Animation")`, write `AnimationId` |
| `layerController.new` | a fixed set, and 1 record per layer | none |
| `play`, the clip has an idle track | none | write `Priority` when the layer's differs from the track's last one; `Play(fadeTime, weight, nativeSpeed)` |
| `play`, the clip has no idle track | at the update: 1 record, 2 closures, and 1 closure per subscribed marker name; they live as long as the track | `LoadAnimation(clip.animation)`, `Stopped:Connect`, `Ended:Connect`, 1 `GetMarkerReachedSignal(name):Connect` per subscribed marker name, write `Looped`, write `Priority`, `Play(fadeTime, weight, nativeSpeed)`; above the cap, 1 `Destroy` and its `Disconnect` calls on the idle track dropped |
| `play` on a layer that has a play | as the two rows above | the same, and `Stop(fadeTime)` on the outgoing track |
| `stop` | none | `Stop(fadeTime)` |
| `setClipSpeed` within the tolerance | none | none |
| `setClipSpeed` beyond it | none | `AdjustSpeed(nativeSpeed)`; for a play that does not loop, also 1 `Length` and 1 `TimePosition` read |
| `setLayerTimeScale`, rate differs | none | the same as `setClipSpeed` beyond the tolerance, for the layer's play |
| `setLayerWeight`, weight differs, a clip playing | none | `AdjustWeight(weight, fadeTime)` |
| `setClipTime`, `setClipNormalizedTime` | none | 1 `Length` read and 1 `TimePosition` write, once `Length` is positive |
| `onPlayCompleted` | 1 entry, 1 closure | none |
| `onMarker` | 1 entry, 1 closure; for the first subscriber of a name, that name's record with its list, and 1 closure per loaded track | for the first subscriber of a name, 1 `Connect` per loaded track; for the last one to leave, 1 `Disconnect` per loaded track |
| a natural end | none | none by the package |
| `clear` | none | `Stop(0)` on each track that is playing or fading out |
| `deconstruct` | none | per loaded track: `Stop(0)` when it is playing or fading out, its `Disconnect` calls and 1 `Destroy` |

Several commands on one layer before an `update` cost what their final state costs: `stop` then
`play` is one replacement, and two `setClipSpeed` calls are at most one `AdjustSpeed`.

What candidate C removes, beyond what candidate A removes:

- motion objects and every blend; the named parameter store (`setNumber`, `getNumber`);
- `TimeReader`, `setLayerTimeReader`, and the `sampleTime` argument of `update`;
- layer speed: speed is the clip's, and the layer has its weight and its time scale;
- the public backend: `GraphBackend`, `ClipBatch`, `robloxAnimatorBackend.new`;
- `offsetClipTime`, the getters and the debug snapshot.

#### Not built: blends

Kept as the record of how a blend would be added later. Nothing above changes when it is.

A blend along one number is a second frozen definition, and `play` takes either:

```luau
export type BlendDefinition = {
	read thresholds: { read [number]: number },    -- ascending
	read clips: { read [number]: ClipDefinition }, -- one per threshold; all with the same `looped`
	read looped: boolean,
}
blendDefinition.build(thresholds: { number }, clips: { ClipDefinition }): BlendDefinition
-- on LayerController:
setBlendValue: (self: LayerController, layer: string, value: number) -> ()
```

- A blend play has one track per clip. Every track starts with the play, and a clip whose weight is
  0 keeps its track at weight 0. Each track's weight is `layer.weight * blendWeight`.
- **Correction.** The first version of this text said the clips stay in phase because they play at
  one speed. That holds only when every clip has the same length. Clips of different lengths stay
  in phase only if each track's speed is scaled by its length:
  `nativeSpeed[i] = play.speed * layer.timeScale * length[i] / blendedLength`, with
  `blendedLength = sum(blendWeight[j] * length[j])`. So an applied change of the blend value calls
  `AdjustSpeed` on every track as well as `AdjustWeight` on the tracks whose weight changed, and a
  blend cannot be in phase until every track's `Length` has loaded.
- The blend tolerance proposed was: apply a new value only when some clip's weight differs from its
  applied weight by more than 0.01, or reaches exactly 0 or 1. It was not checked in Studio.
- Whether Roblox evaluates a weight-0 track cheaply is a Studio question.

A blend along two numbers would be a third definition:

```luau
export type Blend2DDefinition = {
	read xs: { read [number]: number }, read ys: { read [number]: number },
	read clips: { read [number]: ClipDefinition },
	read maxInfluences: number,
	read looped: boolean,
}
blend2DDefinition.build(xs: { number }, ys: { number }, clips: { ClipDefinition }, maxInfluences: number?): Blend2DDefinition
setBlendValue: (self: LayerController, layer: string, value: number, valueY: number?) -> ()
```

- Its weight rule would be the removed `blend2DNode`'s: inverse squared distance over the nearest
  `maxInfluences` samples, which sorts the samples on every applied change.
- Every clip of the definition has a track playing, so a 3 by 3 grid is 9 tracks per controller,
  and one applied change can call `AdjustWeight` on up to `2 * maxInfluences` tracks.

### 4.4 Side by side

| | A | B | C |
| --- | --- | --- | --- |
| Allocation on a per-frame path | none | none | none |
| Positional constructors, `on<Event>` subscriptions, no `task.delay`, names | met | met | met |
| Today's VoxelMMO call sites | all | all | all; the readers become `setLayerTimeScale` |
| A 1D blend with a number set every frame (plan section 5) | `blend1DMotion`, `setNumber` | `playBlend`, `setBlendValue` | not built; 4.3 records how it would be added |
| A blend whose samples are blends, 2D blends | yes | no | no |
| Markers | yes | no | yes |
| A clock | a reader called every update | a reader called every update | `setLayerTimeScale`, called when a rate changes |
| A quiet `update` | 1 call per reader in use | 1 call per reader in use | no call |
| Public objects a consumer constructs | controller, backend, motions | controller | controller; definitions once at load |
| Tables per change of clip, before the engine track's own record | 1 | 0 | 0 |
| What stage 2 rewrites | controller, layers, three motions, backend, playback | one controller and the playback | one controller and the playback |
| Current tests that still describe behaviour (case counts from the subagent's reading of `tests/`) | most of the 52 backend cases and 25 marker cases carry over with new identities; the 22 controller cases are rewritten | the backend cases carry over in substance; controller and marker cases go | the backend and marker cases carry over in substance, driven through the controller; the controller cases are rewritten |

## 5. Recommendation

**The general shape can meet every rule.** The allocations come from four choices: commands as
records, a new request table per clip per update, a time sample as a table, and scratch tables made
inside `update`. None of them is needed to have motions, blends, layers and parameters. Candidate A
has all four of those and allocates nothing on a per-frame path.

**I recommend candidate A**, as written in 4.1: motions, 1D and 2D blends, layers, number
parameters and markers, over `robloxAnimatorBackend`.

Why A and not B: you asked to stay general when general can meet the rules, and it can. B is enough
for everything VoxelMMO does today and for the one blend the plan names, so my reading of the needs
alone would not rule it out. What A costs over B is one small table per change of clip, a second
object for the consumer to construct, and more code to rewrite and test in stage 2. B's saving is in
code size, not in the rules. If you would rather have the smaller package, B loses nothing either
plan section asks for.

Where I am unsure:

- **The state machine.** I left it out of A. Nothing in VoxelMMO or in the plan uses it, the specs
  do not test transition conditions, priorities or triggers, and the engine now has its own
  (`defs`). The `dev` place uses it heavily, so removing it means rewriting that place's action
  layer. This is question 1.
- **`blend2DMotion`.** I kept it because you asked for blend nodes. It has no user either.
- **The engine's own animation graph.** If it is usable, a blend or a state machine could be an
  engine asset that this package plays as one clip, with masks and additive layers that this package
  can never offer. I found its API in the definitions file and one guide; I do not know its maturity.
- **The numbers.** Section 1.2 was measured in Lune. Whether Roblox's VM allocates the same, and
  whether the assert messages are built on each call, are for your Studio measurement.
- **The types.** `ClipMotion = Motion & { ... }` and the `Owned` views are untested against the
  pinned luau-lsp's new solver until stage 2 writes them.

### 5.1 After candidate C (2026-11-21)

Section 5 above was written before candidate C and is kept as it was.

**I would build candidate C in place of A.** It covers every need section 2 lists, and it is the
smallest of the three in what the engine and the package do per frame:

- a quiet `update` makes no call, where A and B call each reader in use;
- a change of clip allocates no table in the package, where A allocates a motion;
- a clock costs a call only when its rate changes, which matches how the other runtimes take a
  clock (section 3) and the fact that `CharacterClock`'s rate is 1 today.

What C gives up against A is a blend inside a blend, a named parameter shared by several blends,
and a 2D blend unless you add the second definition type. Nothing in VoxelMMO or in the two plan
sections uses any of them.

What C changes outside this package, for whoever edits VoxelMMO:

- `presentation.md` section 5 says the animator root is constructed with a `TimeReader` and has "the
  timing commands", and that `update` takes `sampleTime`. With C the root takes no reader, the
  timing command is a layer time scale, and `update` takes nothing.
- `setAnimationParameter(target, name, value)` in section 7 becomes a blend value on a layer; the
  name is no longer the package's. As decided the same day, the blend is not built at all, so the
  package has nothing for this operation until one is added; section 5's other way to get speed
  from velocity, the clip's `velocityToSpeed` through `setSpeed`, is what the package supports.
- Looping moves from the request to the clip definition (4.3, the call sites).

Where I am unsure about C:

- **Blend tracks at weight 0.** Whether keeping every clip of a blend playing is cheap, and whether
  the engine treats a weight of exactly 0 as documented, need Studio (question C6).
- **The tolerances.** The speed numbers are VoxelMMO's own. The blend's 0.01 is mine and unseen.
- **Deferred positions.** `setTime` is applied at the next `update` and not at the call, unlike
  today's `setTrackPosition`. I found no caller that needs it at the call, but the current Studio
  matrices were run with the synchronous form.

## 6. Open questions

Each has the answer I will build if you say nothing about it.

1. **State machine: keep or remove?** Default: remove. If kept, A gains:

   ```luau
   export type StateTransitionCondition = {
   	read parameter: string,
   	read op: "==" | "~=" | ">" | ">=" | "<" | "<=" | "truthy" | "falsy" | "trigger",
   	read value: (number | boolean)?,
   }
   export type StateTransitionDefinition = {
   	read from: string?, read to: string,
   	read duration: number?, read priority: number?,
   	read conditions: { StateTransitionCondition }?,
   }
   export type StateMachineMotionDefinition = {     -- authored once, frozen, shared
   	read initialState: string,
   	read transitions: { StateTransitionDefinition },
   }
   stateMachineMotion.new(definition: StateMachineMotionDefinition, motionsByState: { read [string]: Motion }): StateMachineMotion
   -- on GraphController:
   setBoolean(parameter: string, value: boolean), getBoolean(parameter: string): boolean?, fireTrigger(parameter: string)
   onStateChanged(callback: (stateMachine: StateMachineMotion, fromState: string, toState: string) -> ()): Unsubscribe
   onTransitionEnded(callback: (stateMachine: StateMachineMotion, fromState: string, toState: string) -> ()): Unsubscribe
   ```

   A transition in progress makes `update` evaluate every frame until it ends; that evaluation
   allocates nothing.
2. **`sampledPosition`: remove?** Default: remove. Nothing uses it, markers do not work in it, and
   `docs/todo/temporalAmendment.md` says its Studio gate was never passed. Without it and without the
   state machine, a reader's `position` has no consumer and only its `rate` is used; the reader keeps
   both return values as you already decided.
3. **Will a clock's `rate` ever differ from 1?** `CharacterClock` returns 1 today. If a rate changes
   only at events (hit-stop, a slow effect), a pushed `setLayerTimeScale(layer, rate)` would cost
   nothing per frame and no reader would be called at all. Default: keep `TimeReader`, as the plan
   names it.
4. **The per-play reader goes.** VoxelMMO sets the layer's reader when its selected play changes.
   Default: yes.
5. **Commands as state.** A getter returns what was just set, and calling a command from inside a
   time reader is an error. Default: yes.
6. **`stackModifier`: remove, keep, or move to luauUtils?** Default: remove. If kept, it takes its
   scheduler: `stackModifier.new(schedule: (delaySeconds: number, callback: () -> ()) -> Unsubscribe)`.
7. **Markers in A: keep?** Default: keep `onMarker(markerName, callback)`; the per-clip form
   `onTrackMarker` goes, since the callback receives the clip.
8. **The backend contract in A: keep `GraphBackend`, or have the controller take the `Animator`?**
   With `sampledPosition` gone it has one implementer. Default: keep it; it is what lets the
   controller's tests run without a fake `Animator`.
9. **Subscriptions through luauUtils' `callbackList`?** It would be this package's first
   dependency, and a private one: my shell cannot fetch it, so you would run the install. Default:
   yes.
10. **Reuse engine tracks?** Today every play creates an `Animation` and calls `LoadAnimation`, and
    Roblox's page warns against overusing that call (`doc`, RB-AN). A track per asset id per
    controller could be kept and replayed. It changes behaviour while a track fades out, and needs
    Studio. Default: not in this task.
11. **Names.** `graphController`; `clipMotion`, `blend1DMotion`, `blend2DMotion` in place of the
    `...Node` names; `robloxAnimatorBackend` unchanged, since it is named for the engine class it
    drives. Default: these.
12. **No type parameters.** The alternative keeps one, for layer names
    (`GraphController<"idle" | "base" | ...>`). Default: none.

### 6.1 Questions for candidate C (2026-11-21)

**Answered by the user, 2026-11-21.** C1: my reading. C2: no argument. C3: natural end only. C4:
the speed tolerance as written. C5 and C6: not built, since the blend is left out. C7: none. C8:
these names. Question 6: `stackModifier` is removed. Question 9: `callbackList`, yes. Question 10:
tracks are kept and replayed (4.3, "Tracks are kept"). The seven changes are in 4.3: `update`
raises when an engine call raises; a natural end is recorded at the engine's report and
`onPlayCompleted` is called from `update`; `onMarker` is called from the engine's signal with no
queue; `setWeight(layer, weight, fadeTime?)`, since made the layer's as `setLayerWeight`; no blend; one `Animation` per clip definition; tracks
kept up to a cap. The text below is the questions as they were asked.

If you choose C, your eight points already answer questions 1, 2, 3, 4, 5, 7, 8 and 12 above: no
state machine, no `sampledPosition`, a pushed time scale, no per-play reader, commands as state,
markers kept, a private backend, no type parameters. Questions 6 (`stackModifier`), 9
(`callbackList`) and 10 (reusing engine tracks) stay open with their defaults. Question 10 matters
more with C, because a shared `ClipDefinition` is a natural key for a track kept per controller, and
it would turn a repeated `play` from eight engine calls into one `Play`.

- **C1. "The engine's own fade time."** I read it as: the package never fades anything itself, `play`
  and `stop` still take a fade time and hand it to the engine, and a weight change on a running
  track uses the engine's default fade. The other reading is that no call takes a fade time and the
  engine's default applies everywhere; then `fadeTime`, `fadeIn` and `fadeOut` go, and VoxelMMO's
  per-layer fades (0.03 s to 0.2 s) and per-request fades stop having an effect. Default: my reading.
- **C2. `update()` takes no argument.** Nothing in C reads a sample time. Default: no argument.
- **C3. `onPlayCompleted` fires for a natural end only.** The alternative is one callback for every
  end, `onPlayEnded(callback: (layer: string, playId: number, reason: "completed" | "stopped" | "replaced" | "cleared") -> ())`,
  fired inside `stop`, `play` and `clear` for the last three. Default: natural end only.
- **C4. The tolerances.** Speed: 0.005 absolute or 1% relative, whichever is larger, with 0 and a
  change of sign always applied. Blend: 0.01 of weight, with 0 and 1 always applied. Default: these.
- **C5. A blend along two numbers.** Default: not built.
- **C6. Every clip of a blend plays from the start of the play, at weight 0 when it has none.** The
  alternative starts a clip's track when its weight first leaves 0, which loses phase with the
  others. Default: all play; needs a Studio look at cost.
- **C7. No debug snapshot.** The `dev` place would show what it commanded and what
  `Animator:GetPlayingAnimationTracks()` returns. Default: none.
- **C8. Names.** `layerController`, `clipDefinition.build`, `blendDefinition.build`,
  `setLayerTimeScale`, `onPlayCompleted`. Default: these.
