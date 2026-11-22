--!strict
--!optimize 2
-- Why a play left its layer, as `onPlayEnded` reports it: "completed" when a clip that does not
-- loop reached the end its speed points to, "stopped" by `stop`, `clear` or `deconstruct`, and
-- "replaced" by another `play` on its layer.
export type PlayEndedReason = "completed" | "stopped" | "replaced"

return {}
