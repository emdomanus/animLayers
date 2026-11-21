# The dev place

`dev.project.json` is a Rojo place for exercising the package in Studio. It maps:

| Path | Instance |
| --- | --- |
| `src` | `ReplicatedStorage.packages.animLayers` |
| `luau_packages` | `ReplicatedStorage.packages.luau_packages` |
| `dev/client` | `StarterPlayer.StarterPlayerScripts.animLayersDev`, a LocalScript |

`luau_packages` sits beside `animLayers` because the package requires its dependency as
`../../../luau_packages/luauUtils`, relative to its own files.

## Open it

```powershell
pesde install --locked
rojo serve dev.project.json
```

Connect Studio's Rojo plugin and press Play.

## What it builds

`dev/client/init.client.luau` creates an R6 dummy with
`Players:CreateHumanoidModelFromDescriptionAsync`, parents it into `Workspace`, and constructs one
`layerController` on its `Animator` with three layers:

| Layer | Roblox priority |
| --- | --- |
| `base` | `Movement` |
| `action` | `Action` |
| `overlay` | `Action`, the same as `action` on purpose |

It builds five clip definitions from Roblox's own R6 animations (`idle` and `walk` looping; `wave`,
`cheer` and `jump` once), calls `controller:update()` on `RunService.PreAnimation`, and logs every
completion and every `Footstep` marker. None of the five clips has such a marker; to see `onMarker`,
add the asset id of a clip that has one to `CLIPS`.

## The panel

- Buttons, in groups: the base layer, the speed of its play, the layer time scale and weight, the
  action layer, positions, equal priority, tracks and lifecycle. Two buttons in the last group play
  70 separate definitions of the walk, spaced or in one frame, to load more tracks than the 64 a
  controller keeps.
- A status box, refreshed five times a second, with what
  `Animator:GetPlayingAnimationTracks()` returns: each track's content id, priority, weight, speed
  and position.
- A log of the commands sent, the completions reported, and the engine's `AnimationPlayed`.

[Studio verification](./studio-verification.md) lists what to check with it.
