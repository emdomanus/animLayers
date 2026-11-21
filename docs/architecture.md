# Architecture

## Source layout

The package root is `src/`. Everything in it runs on the server and on the client, so no module
sits in a `shared`, `server` or `client` folder.

```text
src/shared.luau                                              the entry pesde.toml names as lib
src/controllers/layerController/layerController.luau         the controller: layers, play ids, the speed tolerance, completion reports
src/managers/trackManager/trackManager.luau                  the engine side: tracks, signal connections, every engine call
src/utils/clipDefinition/clipDefinition.luau                 build(assetId, looped)
src/types/controllers/layerController/layerController/
  public.luau                                                LayerController, LayerControllerOwned, LayerDefinition, Unsubscribe
  private.luau                                               LayerControllerImpl and its layer and marker records
src/types/managers/trackManager/trackManager/
  public.luau                                                TrackManagerOwned, the view the controller holds
  private.luau                                               TrackManagerImpl and its track and marker records
src/types/def/playback/clipDefinition/
  public.luau                                                ClipDefinition
  private.luau                                               ClipDefinitionImpl, which adds the Animation
```

The entry hands out `layerController` and `clipDefinition`. `trackManager` is constructed by the
controller and reached by nothing else; its `public.luau` leaf is the view its one holder reads, and
no type of it is exported.

The controller requires `callbackList` from the `emdomanus/luau_utils` package, its one dependency,
for its two kinds of subscriber list.

## Two objects

```luau
LayerController = { layers, play ids, _trackManager }        -- decides what plays
TrackManager    = { tracks, _playingBySlot }                 -- calls the engine
```

A layer's index in the layer definitions is its slot in the track manager, and a slot holds one
playing track or none. The controller calls `trackManager:play(slot, clip, ...)`,
`trackManager:stop(slot, fadeTime)`, `trackManager:adjustSpeed(slot, speed)` and so on; no
`AnimationTrack` crosses to the controller. When the engine ends a slot's track by itself, the
manager calls the function the controller gave it at construction, `slotEnded(slot)`, which records
the end on the layer.

A clip definition is `ClipDefinitionImpl` inside the package: `clipDefinition.build` writes its
`animation` field and `trackManager` reads it for `LoadAnimation`. The public `ClipDefinition` does
not declare the field.

## Commands are state

```luau
Layer = {
	-- asked for
	weight: number, timeScale: number,                           -- the layer's own; they stay across plays
	playId: number?, clip: ClipDefinition?, speed: number,       -- the clip's; set by each play
	-- given to the track manager
	appliedPlayId: number?, appliedClip: ClipDefinition?, playing: boolean,
	appliedSpeed: number, appliedWeight: number,
	changed: boolean,
}
```

`play`, `stop`, `setClipSpeed`, `setClipTime`, `setClipNormalizedTime`, `setLayerWeight` and `setLayerTimeScale`
write the "asked for" fields of one layer, set `layer.changed` and the controller's `_changed`, and
return. None of them calls the engine.

## update

`LayerController.update` does three things, in this order:

1. Returns if `_changed` is false.
2. For each layer with `changed` set, `reconcileLayer` compares the two halves of the layer and has
   the track manager make one engine call per difference: `Stop` on the outgoing track,
   `LoadAnimation` when the clip has no idle track, the `Priority` write when the track's last one
   differs, `Play`, `AdjustWeight`, the `TimePosition` write, `AdjustSpeed`. Each "given to the
   track manager" field is written after its call returned.
3. For each layer whose play was recorded as completed, empties the layer and calls the
   `onPlayCompleted` subscribers.

An engine call that raises makes `update` raise at that call. The commands are as the caller left
them, the applied fields describe exactly the calls that returned, and `_changed` is still set, so
the next `update` makes the remaining calls. A `Stop` that raised is the exception: its track was
marked as stopped before the call (see Tracks), so it is not stopped again.

A layer stays `changed` while a position waits for its track's `Length` to load; each `update` then
reads `Length` once for that track.

## Tracks

```luau
Track = { clip: ClipDefinition, track: AnimationTrack, state: "idle" | "playing" | "fading", slot: number, lastPlayed: number }
```

| State | Meaning | Leaves it when |
| --- | --- | --- |
| `idle` | free to be played | `trackManager:play` plays it |
| `playing` | in a slot | `trackManager:stop`, or the engine reports its end |
| `fading` | stopped or ended, waiting for the engine | the engine fires `Ended`; `stopAll` |

A track's state is changed before the engine call that causes it. `trackManager:stop` marks the
track `fading` and empties its slot, and then calls `Stop`. So a `Stopped` the engine fires inside
that call is not read as the track ending by itself, and an `Ended` fired inside it returns the
track to `idle`.

A play takes an idle track of its clip, or loads one. A clip whose only track is `fading` gets a
second track. Tracks are destroyed by `deconstruct`, and when a load takes the count above 64: the
idle track with the smallest `lastPlayed` is then destroyed. A `playing` or `fading` track is never
destroyed for the cap.

Roblox limits the tracks playing at once on one `Animator` (64, per Roblox staff on the DevForum in
January 2026), not the tracks loaded, so the cap is a memory bound and not an engine one.

## Engine signals

Each track has one `Stopped` and one `Ended` connection for its whole life.

- `Stopped`, while the track is `playing` and `track.IsPlaying` is false: the engine ended the
  track. The manager empties the slot and calls the controller's `slotEnded`. A clip that does not
  loop is recorded as completed on its layer; a looping clip is played again by the next `update`.
  The `IsPlaying` test discards a signal that arrives after the track was played again.
- `Ended`, while the track is `fading`: the track becomes `idle`.
- A marker signal calls that marker's subscribers directly, when its track is `playing`.

The first two only write fields and set `_changed`. `update` is where the completion subscribers
are called.

## What ends a play

| Event | `onPlayCompleted` |
| --- | --- |
| A clip that does not loop reaches the end its speed points to | called once, from `update` |
| `stop`, a replacement by another `play`, `clear`, `deconstruct` | not called |
| An end the engine reported, whose play the caller stopped or replaced before the next `update` | not called |

A clip is also on its end when `setClipTime`, `setClipNormalizedTime` or a change of speed leaves it there:
at the upper end with a positive speed, or at 0 with a negative one. The package then stops that
track itself, with the layer's `fadeOut`.

## Equal Roblox priorities

Two layers may have the same `robloxPriority`. The package does nothing about it: Roblox blends
their tracks in proportion to their weights, and the order of the layer definitions decides nothing.
