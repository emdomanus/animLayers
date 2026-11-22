# animLayers

animLayers plays Roblox animation clips on named layers of one `Animator`. A layer plays one clip
or nothing; commands write the controller's state, and `update()` is the only place the engine is
called.

Docs: https://emdomanus.github.io/animLayers/

## Install

Add the package to your `pesde.toml` and run `pesde install`. Its entry is `src/shared.luau`. It
depends on `emdomanus/luau_utils`.

## Example

```luau
local RunService = game:GetService("RunService")
local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers")

-- Once, when your code loads: one definition per clip, shared by every controller.
local WALK = AnimLayers.utils.clipDefinition.build(180426354, true)
local WAVE = AnimLayers.utils.clipDefinition.build(128777973, false)

-- One controller per Animator.
local controller = AnimLayers.controllers.layerController.new(animator, {
	{ name = "base", robloxPriority = Enum.AnimationPriority.Movement, fadeIn = 0.2, fadeOut = 0.2 },
	{ name = "action", robloxPriority = Enum.AnimationPriority.Action },
})

controller:onPlayEnded(function(layer, playId, reason)
	print(layer, playId, reason)   -- "completed", "stopped" or "replaced"
end)

controller:play("base", WALK)
local wavePlay = controller:play("action", WAVE, 1, 0.1)

RunService.PreAnimation:Connect(function()
	controller:setClipSpeed("base", walkSpeed)   -- free to call every frame
	controller:update()                      -- returns at once when nothing changed
end)
```

## The API in one table

| Call | Does |
| --- | --- |
| `clipDefinition.build(assetId, looped)` | a frozen definition with its one `Animation` |
| `layerController.new(animator, layerDefinitions)` | a controller; the layers are fixed |
| `play(layer, clip, speed?, fadeTime?)` | replaces the layer's clip; returns the play's id |
| `stop(layer, fadeTime?)` | empties the layer |
| `setClipSpeed(layer, speed)` | returns the speed in effect, after a tolerance |
| `setLayerWeight(layer, weight, fadeTime?)` | the layer's weight, for this clip and the next; the engine fades to it |
| `setClipTime(layer, seconds)`, `setClipNormalizedTime(layer, alpha)` | places the clip playing on the layer |
| `setLayerTimeScale(layer, rate)` | multiplies the speed of whatever the layer plays |
| `onPlayEnded(callback)` | every play's end, once, with its reason: completed, stopped or replaced |
| `onMarker(markerName, callback)` | called inside the engine's marker signal |
| `update()`, `clear()`, `deconstruct()` | the owner's methods |

Nothing on a per-frame path allocates. A loaded track is kept and played again.

## Development

The repository follows workflowCompass; `AGENTS.md` has the map and the commands.

```powershell
rokit install
pesde install --locked
compass roblox gameMirror -ProjectRoot .
compass checks run -ProjectRoot . -Kind code
```

`dev.project.json` is a Studio place that calls every command; see `docs/guides/dev-place.md`.
Engine behaviour is checked by hand with `docs/guides/studio-verification.md`.

Coming from the 0.1 graph API: `docs/guides/migrating.md`.
