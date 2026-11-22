--!strict
--!optimize 2
-- The three reasons `onPlayEnded` reports, each under its own name.
local PlayEndedReasonTypes = require("../../types/def/playback/playEndedReason/public")

type PlayEndedReason = PlayEndedReasonTypes.PlayEndedReason
export type PlayEndedReasonModule = {
	read completed: PlayEndedReason,
	read stopped: PlayEndedReason,
	read replaced: PlayEndedReason,
}

local module: PlayEndedReasonModule = table.freeze({
	completed = "completed" :: PlayEndedReason,
	stopped = "stopped" :: PlayEndedReason,
	replaced = "replaced" :: PlayEndedReason,
})
return module
