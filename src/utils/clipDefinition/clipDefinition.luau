--!strict
--!optimize 2
-- Builds a clip definition: an asset id and its loop flag, with the one Animation Instance every
-- controller loads that clip's tracks from. A consumer builds each definition once, when it loads,
-- and plays the same one on every controller.
local ClipDefinitionPrivateTypes = require("../../types/def/playback/clipDefinition/private")
local ClipDefinitionTypes = require("../../types/def/playback/clipDefinition/public")

type ClipDefinition = ClipDefinitionTypes.ClipDefinition
type ClipDefinitionImpl = ClipDefinitionPrivateTypes.ClipDefinitionImpl
export type ClipDefinitionModule = {
	read build: (assetId: number, looped: boolean) -> ClipDefinition,
}

local function build(assetId: number, looped: boolean): ClipDefinition
	if typeof(assetId) ~= "number" or assetId <= 0 or assetId % 1 ~= 0 or assetId == math.huge then
		error("assetId must be a whole number above 0", 2)
	end
	if typeof(looped) ~= "boolean" then
		error("looped must be a boolean", 2)
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = string.format("rbxassetid://%d", assetId)
	local definition: ClipDefinitionImpl = table.freeze({ assetId = assetId, looped = looped, animation = animation })
	return definition
end

local module: ClipDefinitionModule = table.freeze({ build = build })
return module
