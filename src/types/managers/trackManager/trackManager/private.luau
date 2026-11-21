--!strict
--!optimize 2
local ClipDefinitionTypes = require("../../../def/playback/clipDefinition/public")
local TrackManagerTypes = require("./public")

type ClipDefinition = ClipDefinitionTypes.ClipDefinition
type TrackManagerOwned = TrackManagerTypes.TrackManagerOwned

-- "playing": in a slot. "fading": stopped by the manager or ended in the engine, and waiting for
-- the engine's Ended signal. "idle": free to be played again.
export type TrackManagerTrackState = "idle" | "playing" | "fading"

-- One AnimationTrack the manager loaded. It is kept until `deconstruct`, or until the cap drops it
-- while idle.
export type TrackManagerTrack = {
	read clip: ClipDefinition,
	read track: AnimationTrack,
	state: TrackManagerTrackState,
	-- The slot the track plays in while `state` is "playing"; 0 otherwise.
	slot: number,
	-- The manager's play count when this track was last played; the cap drops the smallest.
	lastPlayed: number,
	-- The Priority last written to the track.
	robloxPriority: Enum.AnimationPriority?,
	stoppedConnection: RBXScriptConnection?,
	endedConnection: RBXScriptConnection?,
}

-- One connected marker name: its callback, and its signal connection on each loaded track.
export type TrackManagerMarker = {
	read callback: (slot: number, value: string) -> (),
	read connections: { [TrackManagerTrack]: RBXScriptConnection },
}

export type TrackManagerImpl = TrackManagerOwned & {
	_animator: Animator,
	-- Called inside the engine's signal when the engine ended the track playing in a slot; the slot
	-- is already empty.
	_onSlotEnded: (slot: number) -> (),
	_tracks: { TrackManagerTrack },
	_playingBySlot: { [number]: TrackManagerTrack },
	_markers: { [string]: TrackManagerMarker },
	-- The number of plays given to the engine; a track's `lastPlayed` is this at its last play.
	_playCount: number,
}

return {}
