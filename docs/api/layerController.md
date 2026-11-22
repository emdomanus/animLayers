# layerController

```luau
AnimLayers.controllers.layerController.new(
	animator: Animator,
	layerDefinitions: { LayerDefinition }
): LayerControllerOwned

LayerDefinition = {
	read name: string,
	read robloxPriority: Enum.AnimationPriority,
	read fadeIn: number?,     -- seconds
	read fadeOut: number?,    -- seconds
}
```

`new` raises for an empty or repeated layer name, a missing `robloxPriority`, or a fade that is not
a finite number of seconds, 0 or more. Two layers may share a `robloxPriority`
([Architecture](../architecture.md#equal-roblox-priorities)).

The `Animator` must be in the DataModel before the first `update` that loads a track.

Every command below writes the controller's state and returns. The engine hears of it in the next
`update`. A layer name the controller does not have raises.

## The clip's values and the layer's values

This is the one place that says which value belongs to what.

| Value | Belongs to | Set by | Lasts |
| --- | --- | --- | --- |
| speed | the clip playing on the layer | `play`'s `speed`, `setClipSpeed` | until that play ends; the next `play` starts at its own speed, 1 by default |
| position | the clip playing on the layer | `setClipTime`, `setClipNormalizedTime` | until that play ends; the next `play` starts at the beginning |
| weight | the layer | `setLayerWeight` | across plays, `stop` and `clear`; 1 at first |
| time scale | the layer | `setLayerTimeScale` | across plays, `stop` and `clear`; 1 at first |

The speed the engine is given is the clip's speed times the layer's time scale. The weight the
engine is given is the layer's weight.

A clip's setter does nothing while the layer plays nothing. A layer's setter works with or without
a clip playing.

## Commands

| Method | Does |
| --- | --- |
| `play(layer, clip, speed?, fadeTime?): number` | Replaces what the layer plays and returns the play's id. `speed` defaults to 1. The clip starts at the layer's weight. `fadeTime` defaults to the layer's `fadeIn`, and without that to the engine's own fade. Playing the clip the layer already plays starts it again. |
| `stop(layer, fadeTime?)` | Empties the layer. `fadeTime` defaults to the layer's `fadeOut`. |
| `setClipSpeed(layer, speed): number?` | Sets the speed of the clip playing on the layer and returns the speed in effect, or nil when the layer plays nothing. |
| `setClipTime(layer, seconds)` | Places the clip playing on the layer at a position in seconds. |
| `setClipNormalizedTime(layer, alpha)` | The same, as a fraction of the clip's length from 0 to 1. |
| `setLayerWeight(layer, weight, fadeTime?)` | Sets the layer's weight. With nothing playing it calls nothing, and the next `play` starts at it. While a clip plays it is one engine fade to the new weight, over `fadeTime` or the engine's own default. |
| `setLayerTimeScale(layer, rate)` | Sets the layer's time scale; 0 pauses whatever the layer plays. |

`getPlayId(layer): number?` returns the id of the play on the layer now, the number the last `play`
returned, or nil when the layer plays nothing; it writes nothing, calls no engine and allocates nothing.

### The fade of an outgoing play

A `play` on a layer that already has a play stops the outgoing track with the new play's fade. If
`stop(layer, fadeTime)` was called on the layer since the last `update`, the outgoing track gets
that fade instead.

### The speed tolerance

`setClipSpeed` replaces the clip's speed only when the new speed differs from it by more than 0.005 and
by more than 1% of the larger of the two, or when exactly one of them is 0, or when their signs
differ. Otherwise the clip keeps its speed and `setClipSpeed` returns that. Use the returned value, not
the one you passed, where the exact speed matters.

### Positions

- A position is written by the next `update`, or by the first `update` after the track's `Length`
  has loaded.
- On a looping clip a position past the end wraps, and a normalized 1 is 0.
- On a clip that does not loop a position past the end is the end. A clip placed on the end its
  speed points to completes.
- A clip that does not loop, runs backwards and is given a position before its length has loaded is
  held at speed 0 until the position can be written.

## Subscriptions

Each returns a function that removes the subscription; calling it again does nothing.

| Method | The callback is called |
| --- | --- |
| `onPlayCompleted(callback: (layer: string, playId: number) -> ())` | from `update`, when a play that does not loop reached the end its speed points to. The layer is already empty. |
| `onMarker(markerName, callback: (layer: string, playId: number, clip: ClipDefinition, value: string) -> ())` | inside the engine's marker signal, when a marker with that name is reached on the track of a layer's current play. |

- `onPlayCompleted` is not called for `stop`, for a replacement, for `clear` or for `deconstruct`,
  nor for an end whose play was stopped or replaced before the `update` that would have reported it.
- A track that is fading out delivers no marker.
- A command made inside either callback is applied by the next `update`.

## The owner's methods

`new` returns `LayerControllerOwned`, which adds:

| Method | Does |
| --- | --- |
| `update()` | Makes the engine calls the commands since the last `update` ask for, then calls the completion subscribers. With nothing changed it returns at once and calls nothing. |
| `clear()` | Stops every track with a fade of 0 and empties every layer. Loaded tracks, layer weights and time scales are kept. |
| `deconstruct()` | Destroys every track the controller loaded. Commands and subscriptions raise afterwards; `update` and `clear` do nothing. |

`update` does not catch. When an engine call raises, `update` raises with that error; the commands
are as you left them, and the next `update` makes the calls that had not returned. A `Stop` that
raised is the exception: its track was marked as stopped before the call and is not stopped again.

## What allocates

Nothing on a path that can run every frame: `update`, `setClipSpeed`, `setLayerWeight`, `setClipTime`,
`setClipNormalizedTime` and `setLayerTimeScale` create no table, closure or string. `play` and `stop`
create none either. A track's record and its two signal closures are created when the track is
loaded and live as long as the track.
