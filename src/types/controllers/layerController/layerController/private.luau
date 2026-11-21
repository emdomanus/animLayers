--!strict
--!optimize 2
local LuauUtils = require("../../../../../luau_packages/luauUtils")
local ClipDefinitionTypes = require("../../../def/playback/clipDefinition/public")
local TrackManagerTypes = require("../../../managers/trackManager/trackManager/public")
local LayerControllerTypes = require("./public")

type CallbackList<Args...> = LuauUtils.CallbackList<Args...>
type ClipDefinition = ClipDefinitionTypes.ClipDefinition
type LayerControllerOwned = LayerControllerTypes.LayerControllerOwned
type TrackManagerOwned = TrackManagerTypes.TrackManagerOwned

-- One layer: what the caller asked for, and what the track manager was last given.
export type LayerControllerLayer = {
	read name: string,
	-- The layer's slot in the track manager: its index in the layer definitions.
	read slot: number,
	read robloxPriority: Enum.AnimationPriority,
	read fadeIn: number?,
	read fadeOut: number?,
	-- The layer's own values. They stay across plays and across `clear`; both start at 1.
	timeScale: number,
	weight: number,
	-- The fade the last `setLayerWeight` gave, for the weight change not yet given to the engine.
	weightFadeTime: number?,
	-- True when the next `update` has something to do for this layer.
	changed: boolean,

	-- Asked for. `playId` and `clip` are nil together: the layer plays nothing. `speed` is the
	-- clip's and is set by each `play`.
	playId: number?,
	clip: ClipDefinition?,
	speed: number,
	playFadeTime: number?,
	-- A position not yet written to the track.
	positionKind: ("seconds" | "normalized")?,
	positionValue: number,
	-- `stop` was called since the last `update`: the outgoing track fades over `outgoingFadeTime`.
	outgoingFadeSet: boolean,
	outgoingFadeTime: number?,
	-- The applied play reached its end and its subscribers have not been called yet.
	completed: boolean,

	-- Given to the track manager. `appliedPlayId` and `appliedClip` are the play it was last given.
	appliedPlayId: number?,
	appliedClip: ClipDefinition?,
	-- The layer's slot holds the track of the applied play.
	playing: boolean,
	appliedSpeed: number,
	appliedWeight: number,
	-- The track plays at speed 0 until its length loads, because it starts at a position and runs
	-- backwards.
	reverseHold: boolean,
}

-- The subscribers of one marker name.
export type LayerControllerMarker = {
	read list: CallbackList<string, number, ClipDefinition, string>,
	subscriberCount: number,
}

export type LayerControllerImpl = LayerControllerOwned & {
	_trackManager: TrackManagerOwned,
	_layers: { [string]: LayerControllerLayer },
	-- `_layerOrder[slot]` is the layer with that slot.
	_layerOrder: { LayerControllerLayer },
	_markers: { [string]: LayerControllerMarker },
	_playCompleted: CallbackList<string, number>,
	-- The id the last `play` returned.
	_lastPlayId: number,
	-- False when `update` has nothing to do.
	_changed: boolean,
	_deconstructed: boolean,
}

return {}
