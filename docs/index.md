# AnimLayers

AnimLayers plays Roblox animation clips on named layers of one `Animator`. A layer plays one clip or
nothing. The package owns no clock, no RunService connection and no schedule: the caller issues
commands and calls `controller:update()` once per frame.

```luau
ClipDefinition = { assetId: number, looped: boolean }     -- built once, shared; carries its one Animation privately
LayerController = { layers: { [string]: Layer } }         -- with a private trackManager that owns the AnimationTracks
Layer = { robloxPriority: Enum.AnimationPriority, weight: number, timeScale: number, play: Play? }
Play = { id: number, clip: ClipDefinition, speed: number }
```

One example: `controller:play("base", walk, 1.2)` writes the layer's play and returns its id.
`controller:update()` then calls `Animator:LoadAnimation` with `walk`'s Animation if the controller
has no idle track of `walk`, and `track:Play(fadeIn, 1, 1.2 * layer.timeScale)`.

## Start here

- [Getting started](/guides/getting-started)
- [Architecture](/architecture)
- [API](/api/), and [which values belong to the clip and which to the layer](/api/layerController#the-clip-s-values-and-the-layer-s-values)
- [Migrating from the 0.1 graph API](/guides/migrating)
- [Verification](/guides/verification) and the [Studio checklist](/guides/studio-verification)

## What the package does

- Commands write the controller's state and return. `update` is the only place the engine is
  called, and it makes one engine call per difference between what was asked for and what the engine
  was last given. With nothing changed it returns at its first statement.
- Every play's end is reported once to the `onPlayEnded` subscribers, with its reason: a natural
  end from `update`, a stop or a replacement inside the call that made it.
- A marker subscriber is called inside the engine's marker signal.
- Every `AnimationTrack` a controller loads is kept and played again, up to 64 per controller.
- Nothing on a per-frame path creates a table, a closure or a string.

## What it leaves to the caller

- When to call `update`, and every clock: a clock reaches a layer as `setLayerTimeScale(layer, rate)`.
- Which clip plays on which layer, stacking several requests on one layer, and why a play ended
  when the caller ended it.
- Blends, state machines, additive layers and joint masks: the package has none. Roblox's own
  animation graph is the engine's answer to those.
