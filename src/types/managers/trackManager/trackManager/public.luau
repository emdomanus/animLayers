--!strict
--!optimize 2
local ClipDefinitionTypes = require("../../../def/playback/clipDefinition/public")

type ClipDefinition = ClipDefinitionTypes.ClipDefinition

-- The engine side of a layerController, as the controller that constructs it holds it. The package's
-- entry hands out nothing of it.
--
-- It owns every AnimationTrack loaded on one Animator and makes every engine call. Its user names a
-- place a track plays in by a slot, a whole number above 0: a slot holds one playing track or none.
-- Every method that takes a slot except `play` does nothing, or returns 0, when the slot is empty.
export type TrackManagerOwned = {
	-- Plays `clip` in an empty slot: on an idle track of the clip, or on a newly loaded one. With
	-- `holdWithoutLength` true and the track's length not yet loaded, it plays at speed 0 and
	-- returns true; otherwise it plays at `speed` and returns false.
	read play: (
		self: TrackManagerOwned,
		slot: number,
		clip: ClipDefinition,
		robloxPriority: Enum.AnimationPriority,
		fadeTime: number?,
		weight: number,
		speed: number,
		holdWithoutLength: boolean
	) -> boolean,
	-- Empties the slot, then stops its track.
	read stop: (self: TrackManagerOwned, slot: number, fadeTime: number?) -> (),
	read adjustSpeed: (self: TrackManagerOwned, slot: number, speed: number) -> (),
	read adjustWeight: (self: TrackManagerOwned, slot: number, weight: number, fadeTime: number?) -> (),
	-- The track's length in seconds; 0 until the engine has loaded it.
	read getLength: (self: TrackManagerOwned, slot: number) -> number,
	read getTimePosition: (self: TrackManagerOwned, slot: number) -> number,
	read setTimePosition: (self: TrackManagerOwned, slot: number, seconds: number) -> (),

	-- Connects the marker's signal on every loaded track and on every track loaded later.
	-- `callback` is called inside the engine's signal with the slot the track is playing in; a
	-- track that is not playing in a slot calls nothing. One callback per marker name.
	read connectMarker: (
		self: TrackManagerOwned,
		markerName: string,
		callback: (slot: number, value: string) -> ()
	) -> (),
	read disconnectMarker: (self: TrackManagerOwned, markerName: string) -> (),

	-- Empties every slot and stops every track that is playing or fading out, with a fade of 0.
	-- Every track is idle afterwards.
	read stopAll: (self: TrackManagerOwned) -> (),
	-- Destroys every track.
	read deconstruct: (self: TrackManagerOwned) -> (),
}

return {}
