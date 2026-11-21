--!strict
--!optimize 2
-- One Roblox animation asset with its loop flag. `clipDefinition.build` makes it once, frozen, and
-- every controller on the machine plays the same one.
export type ClipDefinition = {
	read assetId: number,
	read looped: boolean,
}

return {}
