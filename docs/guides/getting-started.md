# Getting started

## 1. Build clip definitions once

A definition is an asset id, a loop flag and the one `Animation` Instance its tracks are loaded
from. Build each when your code loads and keep it; every controller plays the same definitions.

```luau
local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers")

local WALK = AnimLayers.utils.clipDefinition.build(180426354, true)
local WAVE = AnimLayers.utils.clipDefinition.build(128777973, false)
```

## 2. Construct a controller

One controller per `Animator`. The layer list is fixed for the controller's life.

```luau
local controller = AnimLayers.controllers.layerController.new(animator, {
	{ name = "base", robloxPriority = Enum.AnimationPriority.Movement, fadeIn = 0.2, fadeOut = 0.2 },
	{ name = "action", robloxPriority = Enum.AnimationPriority.Action },
})
```

## 3. Call update once per frame

The package schedules nothing. Call `update` from the step that owns your frame order; it returns
at its first statement when no command was made since the last call.

```luau
RunService.PreAnimation:Connect(function()
	controller:update()
end)
```

## 4. Command it

```luau
local walkPlay = controller:play("base", WALK)             -- returns the play's id
local speedInEffect = controller:setClipSpeed("base", 1.3)     -- every frame is fine
controller:play("action", WAVE, 1, 0.1)                    -- speed, fade
controller:setLayerWeight("action", 0.5, 0.3)             -- the layer's weight: this clip and the next ones
controller:setLayerTimeScale("action", 0)                  -- pause whatever "action" plays
controller:stop("base", 0.5)
```

## 5. Hear about ends and markers

```luau
local unsubscribe = controller:onPlayEnded(function(layer, playId, reason)
	-- "completed" from update; "stopped" and "replaced" inside the call that ended the play
end)
controller:onMarker("Footstep", function(layer, playId, clip, value)
	-- called inside the engine's marker signal
end)
```

`onPlayEnded` reports every play once, when it leaves its layer: `"completed"` for an end the
engine reached by itself, from `update`; `"stopped"` inside your `stop`, `clear` or
`deconstruct`; `"replaced"` inside the `play` that displaced it.

## 6. Tear down

```luau
controller:deconstruct()    -- destroys the controller's tracks; the definitions stay
```
