--!strict
--!optimize 2
-- The calls a consumer writes are accepted, callback parameters are inferred from the subscription,
-- and the owner's handle passes where only the commands are wanted.
local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers/shared")

type ClipDefinition = AnimLayers.ClipDefinition
type LayerController = AnimLayers.LayerController
type LayerControllerOwned = AnimLayers.LayerControllerOwned
type LayerDefinition = AnimLayers.LayerDefinition
type PlayEndedReason = AnimLayers.PlayEndedReason
type Unsubscribe = AnimLayers.Unsubscribe

local animator = Instance.new("Animator")
local layers: { LayerDefinition } = {
	{ name = "base", robloxPriority = Enum.AnimationPriority.Movement, fadeIn = 0.2, fadeOut = 0.3 },
	{ name = "action", robloxPriority = Enum.AnimationPriority.Action },
}
local walk: ClipDefinition = AnimLayers.utils.clipDefinition.build(101, true)
local _assetId: number = walk.assetId

local owned: LayerControllerOwned = AnimLayers.controllers.layerController.new(animator, layers)
local _playId: number = owned:play("base", walk)
local _secondPlayId: number = owned:play("base", walk, 1.5, 0.2)
owned:stop("base")
owned:stop("base", 0.1)
local _speed: number? = owned:setClipSpeed("base", 2)
owned:setLayerWeight("base", 0.5)
owned:setLayerWeight("base", 0.5, 1)
owned:setClipTime("base", 0.25)
owned:setClipNormalizedTime("base", 0.5)
owned:setLayerTimeScale("base", 0)

-- The parameters of a subscriber are inferred from the subscription.
local unsubscribe: Unsubscribe = owned:onPlayEnded(function(layer, playId, reason)
	local _layer: string = layer
	local _id: number = playId
	local _reason: PlayEndedReason = reason
	local _completed: boolean = reason == AnimLayers.common.playEndedReason.completed
	if reason == "replaced" then
		local _current: number? = owned:getPlayId(layer)
	end
end)
local _unsubscribeMarker: Unsubscribe = owned:onMarker("Footstep", function(layer, playId, clip, value)
	local _layer: string = layer
	local _id: number = playId
	local _clip: ClipDefinition = clip
	local _value: string = value
end)
unsubscribe()

owned:update()
owned:clear()
owned:deconstruct()

-- A holder that only commands takes the controller without its lifecycle.
local function command(controller: LayerController): ()
	controller:play("action", walk)
end
command(owned)
