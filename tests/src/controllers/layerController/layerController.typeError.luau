--!strict
--!optimize 2
-- What the types refuse: the lifecycle on a commands-only handle, wrong arguments, a play's speed
-- read as never nil, writes to a definition or to a method, and anything but `new` on the module.
local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers/shared")

type ClipDefinition = AnimLayers.ClipDefinition
type LayerController = AnimLayers.LayerController
type LayerControllerOwned = AnimLayers.LayerControllerOwned
type PlayEndedReason = AnimLayers.PlayEndedReason

local animator = Instance.new("Animator")
local walk: ClipDefinition = AnimLayers.utils.clipDefinition.build(101, true)
local owned: LayerControllerOwned = AnimLayers.controllers.layerController.new(animator, {
	{ name = "base", robloxPriority = Enum.AnimationPriority.Movement },
})

local commandsOnly: LayerController = owned
commandsOnly:update() -- expect-error: Key 'update' not found in table 'LayerController'
owned:play("base", 101) -- expect-error: Expected this to be 'ClipDefinition', but got 'number'
owned:play("base", walk, "fast") -- expect-error: Expected this to be 'number?', but got 'string'
owned:play("base", walk, 1, 1, 0.2) -- expect-error: Argument count mismatch
owned:setLayerWeight("base") -- expect-error: Argument count mismatch
owned:update(1 / 60) -- expect-error: Argument count mismatch
local _speed: number = owned:setClipSpeed("base", 1) -- expect-error: Expected this to be 'number', but got 'number?'
owned:onPlayCompleted(function() end) -- expect-error: onPlayCompleted
owned:onPlayEnded(function(_layer: string, _playId: number, _reason: number) end) -- expect-error: Expected this to be
local _reason: PlayEndedReason = "finished" -- expect-error: finished
walk.assetId = 5 -- expect-error: Property assetId of table 'ClipDefinition' is read-only
local _animation = walk.animation -- expect-error: Key 'animation' not found in table 'ClipDefinition'
owned.update = function() end -- expect-error: is read-only
AnimLayers.controllers.layerController.new(animator) -- expect-error: Argument count mismatch
AnimLayers.controllers.layerController.new(animator, { { name = "base" } }) -- expect-error: missing field 'robloxPriority'
AnimLayers.controllers.layerController.update(owned) -- expect-error: Key 'update' not found in table 'LayerControllerModule'
AnimLayers.utils.clipDefinition.build("101", true) -- expect-error: Expected this to be 'number', but got 'string'
