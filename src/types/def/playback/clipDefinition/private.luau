--!strict
--!optimize 2
local ClipDefinitionTypes = require("./public")

type ClipDefinition = ClipDefinitionTypes.ClipDefinition

-- What `clipDefinition.build` really returns. `animation` is the one Animation Instance of the
-- definition: `build` creates it, trackManager loads every track of the clip from it, and nothing
-- destroys it. Consumers see `ClipDefinition`, which does not declare it.
export type ClipDefinitionImpl = ClipDefinition & {
	read animation: Animation,
}

return {}
