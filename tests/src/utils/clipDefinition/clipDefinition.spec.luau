--!strict
--!optimize 2
-- clipDefinition.build through the package entry: what a definition holds, and what it rejects.
-- What a controller loads from a definition is in layerController.spec.luau.
local RobloxEnvironmentFixture = require("../../../robloxEnvironment.fixture")

RobloxEnvironmentFixture.install()

local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers/shared")

local function case(name: string, body: () -> ()): ()
	body()
	print("PASS " .. name)
end

case("a definition holds its asset id and its loop flag, and is frozen", function()
	local clip = AnimLayers.utils.clipDefinition.build(180426354, true)
	assert(clip.assetId == 180426354 and clip.looped == true, "the definition keeps what it was given")
	assert(table.isfrozen(clip), "the definition is frozen")
end)

case("an asset id that is not a whole number above 0 is refused", function()
	for _, assetId in { 0, -5, 1.5, math.huge, 0 / 0 } do
		local built = pcall(AnimLayers.utils.clipDefinition.build, assetId, true)
		assert(not built, "accepted the asset id " .. tostring(assetId))
	end
end)
