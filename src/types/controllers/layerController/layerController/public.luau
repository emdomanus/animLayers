--!strict
--!optimize 2
local ClipDefinitionTypes = require("../../../def/playback/clipDefinition/public")

type ClipDefinition = ClipDefinitionTypes.ClipDefinition

-- What a subscription returns. Calling it removes that subscription; later calls do nothing.
export type Unsubscribe = () -> ()

-- One layer of a controller. Two layers may name the same `robloxPriority`: Roblox then blends
-- their tracks in proportion to their weights, and the order of the definitions decides nothing.
export type LayerDefinition = {
	read name: string,
	read robloxPriority: Enum.AnimationPriority,
	-- Seconds. The fade `play` hands the engine when it is given none; absent, the engine's own.
	read fadeIn: number?,
	-- Seconds. The fade `stop` hands the engine when it is given none; absent, the engine's own.
	read fadeOut: number?,
}

-- Layers over one Roblox Animator. A layer plays one clip or nothing. Every command writes the
-- controller's own state and returns; the engine is called by `update` alone.
--
-- Two values belong to the clip playing on a layer and end with it: its speed and its position.
-- Two belong to the layer and stay across plays: its weight and its time scale, both 1 at first.
-- The speed the engine is given is the clip's speed times the layer's time scale.
export type LayerController = {
	-- Replaces what the layer plays and returns the play's id, a number that counts up per
	-- controller. `speed` defaults to 1. The clip plays at the layer's weight. Playing a clip the
	-- layer already plays starts it again. The outgoing play fades out over this play's fade,
	-- unless `stop` was called on the layer since the last `update`.
	read play: (
		self: LayerController,
		layer: string,
		clip: ClipDefinition,
		speed: number?,
		fadeTime: number?
	) -> number,
	read stop: (self: LayerController, layer: string, fadeTime: number?) -> (),
	-- The id of the play on the layer now: the number the last `play` on it returned, or nil when
	-- the layer plays nothing. It is nil after `stop`, after `clear`, and from the moment a play
	-- that does not loop completes, so inside the `onPlayCompleted` callback too. It calls no engine
	-- and allocates nothing.
	read getPlayId: (self: LayerController, layer: string) -> number?,

	-- The next three address the clip playing on the layer and do nothing when it plays nothing.

	-- Replaces the clip's speed only when the new one differs from it by more than 0.005 and by more
	-- than 1% of the larger of the two, or one of them is 0, or their signs differ. Returns the
	-- clip's speed after the call, or nil when the layer plays nothing.
	read setClipSpeed: (self: LayerController, layer: string, speed: number) -> number?,
	-- The track's position, applied by the next `update`, or by the first `update` after the
	-- track's length has loaded. Past the end, a looping clip wraps and another clip stops at it.
	read setClipTime: (self: LayerController, layer: string, seconds: number) -> (),
	-- The same with the position as a fraction of the clip's length, 0 to 1.
	read setClipNormalizedTime: (self: LayerController, layer: string, alpha: number) -> (),

	-- The next two set a value of the layer, with or without a clip playing on it.

	-- The weight of whatever the layer plays, now and later. A change while a clip plays is one
	-- engine fade to the new weight, over `fadeTime` or the engine's own.
	read setLayerWeight: (self: LayerController, layer: string, weight: number, fadeTime: number?) -> (),
	-- The engine is given the clip's speed times `rate` for whatever the layer plays, now and
	-- later. 0 pauses the layer.
	read setLayerTimeScale: (self: LayerController, layer: string, rate: number) -> (),

	-- Called from `update` when a play that does not loop reached the end its speed points to, with
	-- the layer already empty. Not called for `stop`, for a replacement by another `play`, for
	-- `clear` or for `deconstruct`, nor for an end whose play was stopped or replaced before the
	-- `update` that would have reported it.
	read onPlayCompleted: (self: LayerController, callback: (layer: string, playId: number) -> ()) -> Unsubscribe,
	-- Called inside the engine's marker signal, with nothing queued, when a marker with this name
	-- is reached on the track of a layer's current play. `value` is the marker's value.
	read onMarker: (
		self: LayerController,
		markerName: string,
		callback: (layer: string, playId: number, clip: ClipDefinition, value: string) -> ()
	) -> Unsubscribe,
}

-- What `new` returns to the controller's owner.
export type LayerControllerOwned = LayerController & {
	-- Makes the engine calls the commands since the last `update` ask for, then calls the
	-- `onPlayCompleted` subscribers. It returns at once, calling nothing, when nothing changed. An
	-- engine call that raises makes `update` raise: the commands stay as the caller left them, the
	-- controller has recorded as applied exactly the engine calls that returned, and the next
	-- `update` makes the remaining ones again. A Stop that raised is the exception: its track was
	-- marked as stopped before the call, and it is not stopped again.
	read update: (self: LayerControllerOwned) -> (),
	-- Stops every track at once and empties every layer. Loaded tracks, layer weights and time
	-- scales are kept.
	read clear: (self: LayerControllerOwned) -> (),
	-- Destroys every track the controller loaded. Commands and subscriptions raise afterwards.
	read deconstruct: (self: LayerControllerOwned) -> (),
}

return {}
