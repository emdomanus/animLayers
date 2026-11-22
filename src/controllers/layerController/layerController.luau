--!native
--!strict
--!optimize 2
-- Layers over one Roblox Animator. A layer plays one clip or nothing.
--
-- The controller owns the layers, the play ids, the speed tolerance and the completion reports. It
-- constructs a trackManager, which owns the engine's tracks and makes every engine call; a layer's
-- index is its slot there.
--
-- Every command writes fields of its layer and returns. `update` is the only place the track manager
-- is told to call the engine: for each layer a command touched, it compares what was asked for with
-- what the manager was last given and makes one call per difference, recording each as given only
-- after the call returned. So a call that raises leaves the difference in place for the next
-- `update`. The one exception is a stop: the layer is recorded as not playing before the call, as
-- the manager records its track.
--
-- When the engine ends a track by itself, the manager calls `slotEnded` inside the engine's signal,
-- which only records the end on the layer; `update` reports it to the `onPlayEnded` subscribers.
-- Every other end is reported inside the call that makes it (`play`, `stop`, `clear`,
-- `deconstruct`), after the layer shows its new state. A play is reported when its id leaves
-- `layer.playId`, the one field that holds it, so each play is reported exactly once. A marker
-- subscriber is called inside the engine's marker signal.
local LuauUtils = require("../../../luau_packages/luauUtils")
local PlayEndedReason = require("../../common/playEndedReason/playEndedReason")
local TrackManager = require("../../managers/trackManager/trackManager")
local LayerControllerPrivateTypes = require("../../types/controllers/layerController/layerController/private")
local LayerControllerTypes = require("../../types/controllers/layerController/layerController/public")
local ClipDefinitionTypes = require("../../types/def/playback/clipDefinition/public")
local PlayEndedReasonTypes = require("../../types/def/playback/playEndedReason/public")

type CallbackList<Args...> = LuauUtils.CallbackList<Args...>
type ClipDefinition = ClipDefinitionTypes.ClipDefinition
type LayerDefinition = LayerControllerTypes.LayerDefinition
type LayerControllerOwned = LayerControllerTypes.LayerControllerOwned
type PlayEndedReason = PlayEndedReasonTypes.PlayEndedReason
type Unsubscribe = LayerControllerTypes.Unsubscribe
type LayerControllerImpl = LayerControllerPrivateTypes.LayerControllerImpl
type LayerControllerLayer = LayerControllerPrivateTypes.LayerControllerLayer
type LayerControllerMarker = LayerControllerPrivateTypes.LayerControllerMarker
export type LayerControllerModule = {
	read new: (animator: Animator, layerDefinitions: { LayerDefinition }) -> LayerControllerOwned,
}

-- A new speed replaces a play's speed only beyond both of these; a change to or from 0, or of sign,
-- always does.
local SPEED_ABSOLUTE_TOLERANCE = 0.005
local SPEED_RELATIVE_TOLERANCE = 0.01

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function checkFadeTime(fadeTime: number?): ()
	if fadeTime ~= nil and not (isFinite(fadeTime) and fadeTime >= 0) then
		error("fadeTime must be a finite number of seconds, 0 or more", 3)
	end
end

local function requireLayer(self: LayerControllerImpl, name: string): LayerControllerLayer
	if self._deconstructed then
		error("LayerController is deconstructed", 3)
	end
	local layer = self._layers[name]
	if layer == nil then
		error(`LayerController has no layer "{name}"`, 3)
	end
	return layer
end

local function markChanged(self: LayerControllerImpl, layer: LayerControllerLayer): ()
	layer.changed = true
	self._changed = true
end

-- True when a track that does not loop sits on the end its signed speed points to.
local function isOnOutwardEnd(seconds: number, length: number, nativeSpeed: number): boolean
	if seconds >= length then
		return nativeSpeed > 0
	end
	return seconds <= 0 and nativeSpeed < 0
end

-- The seconds a position names on a track of this length, and whether a track that does not loop
-- is thereby on the end its speed points to.
local function resolvePosition(
	kind: "seconds" | "normalized",
	value: number,
	length: number,
	looped: boolean,
	nativeSpeed: number
): (number, boolean)
	if looped then
		if kind == "normalized" then
			return (if value == 1 then 0 else value) * length, false
		end
		return value % length, false
	end
	local seconds = if kind == "normalized" then value * length else math.min(value, length)
	return seconds, isOnOutwardEnd(seconds, length, nativeSpeed)
end

-- The layer plays nothing and the track manager holds nothing for it.
local function emptyLayer(layer: LayerControllerLayer): ()
	layer.playId = nil
	layer.clip = nil
	layer.positionKind = nil
	layer.outgoingFadeSet = false
	layer.completed = false
	layer.appliedPlayId = nil
	layer.appliedClip = nil
	layer.playing = false
	layer.reverseHold = false
end

-- The engine ended the track in this slot and the manager had not stopped it. Called inside the
-- engine's signal: it records and calls no subscriber.
local function slotEnded(self: LayerControllerImpl, slot: number): ()
	local layer = self._layerOrder[slot]
	local clip = layer.appliedClip
	layer.playing = false
	if clip ~= nil and not clip.looped and layer.appliedPlayId == layer.playId then
		layer.completed = true
	else
		-- A looping clip is played again by the next update. A play the caller has already stopped
		-- or replaced was reported when that happened.
		layer.appliedPlayId = nil
		layer.appliedClip = nil
	end
	markChanged(self, layer)
end

-- Forgets what the track manager was given for every layer, keeping what was asked for. The caller
-- has stopped every track, or destroys them after.
local function forgetAppliedPlays(self: LayerControllerImpl): ()
	for _, layer in self._layerOrder do
		layer.outgoingFadeSet = false
		layer.appliedPlayId = nil
		layer.appliedClip = nil
		layer.playing = false
		layer.reverseHold = false
		layer.changed = false
	end
	self._changed = false
end

-- Empties, in layer order, every layer whose play has an id up to `lastPlayId`, and reports that
-- play once its layer is empty: "completed" when the engine had already ended it, else "stopped".
-- A play a callback starts has a larger id and is left alone. Returns true when it reported one.
local function reportPlaysEnded(self: LayerControllerImpl, lastPlayId: number): boolean
	local reported = false
	for _, layer in self._layerOrder do
		local playId = layer.playId
		if playId ~= nil and playId <= lastPlayId then
			reported = true
			local reason = if layer.completed then PlayEndedReason.completed else PlayEndedReason.stopped
			-- Only a callback earlier in this pass that called `update` can have given this play to the
			-- track manager again.
			if layer.playing then
				layer.playing = false
				self._trackManager:stop(layer.slot, 0)
			end
			emptyLayer(layer)
			layer.changed = false
			self._playEnded:fire(layer.name, playId, reason)
		end
	end
	return reported
end

-- Gives the track manager what this layer's commands ask for. Returns true while the layer still
-- waits for its track's length to load.
local function reconcileLayer(self: LayerControllerImpl, layer: LayerControllerLayer): boolean
	local trackManager = self._trackManager
	local slot = layer.slot
	local playId = layer.playId
	if layer.appliedPlayId ~= playId then
		if layer.playing then
			local fadeTime: number?
			if layer.outgoingFadeSet then
				fadeTime = layer.outgoingFadeTime
			elseif playId ~= nil then
				fadeTime = if layer.playFadeTime ~= nil then layer.playFadeTime else layer.fadeIn
			else
				fadeTime = layer.fadeOut
			end
			layer.playing = false
			trackManager:stop(slot, fadeTime)
		end
		layer.appliedPlayId = nil
		layer.appliedClip = nil
		layer.reverseHold = false

		local clip = layer.clip
		if playId ~= nil and clip ~= nil then
			local nativeSpeed = layer.speed * layer.timeScale
			-- A clip that does not loop, runs backwards and starts at a position cannot be placed
			-- until its length has loaded; it is held at speed 0 until then.
			local holdWithoutLength = layer.positionKind ~= nil and not clip.looped and nativeSpeed < 0
			local fadeTime = if layer.playFadeTime ~= nil then layer.playFadeTime else layer.fadeIn
			local held = trackManager:play(
				slot,
				clip,
				layer.robloxPriority,
				fadeTime,
				layer.weight,
				nativeSpeed,
				holdWithoutLength
			)
			layer.playing = true
			layer.appliedPlayId = playId
			layer.appliedClip = clip
			layer.appliedSpeed = if held then 0 else nativeSpeed
			layer.appliedWeight = layer.weight
			layer.reverseHold = held
		end
	end
	layer.outgoingFadeSet = false

	local appliedClip = layer.appliedClip
	if not layer.playing or appliedClip == nil or layer.completed then
		return false
	end
	local looped = appliedClip.looped
	local waiting = false

	if layer.appliedWeight ~= layer.weight then
		trackManager:adjustWeight(slot, layer.weight, layer.weightFadeTime)
		layer.appliedWeight = layer.weight
	end

	local nativeSpeed = layer.speed * layer.timeScale
	local positionKind = layer.positionKind
	if positionKind ~= nil then
		local length = trackManager:getLength(slot)
		if length > 0 then
			local seconds, onOutwardEnd =
				resolvePosition(positionKind, layer.positionValue, length, looped, nativeSpeed)
			trackManager:setTimePosition(slot, seconds)
			layer.positionKind = nil
			layer.reverseHold = false
			if onOutwardEnd then
				layer.completed = true
			end
		else
			waiting = true
			if not looped and nativeSpeed < 0 and not layer.reverseHold then
				trackManager:adjustSpeed(slot, 0)
				layer.appliedSpeed = 0
				layer.reverseHold = true
			end
		end
	end

	if not layer.completed and not layer.reverseHold and layer.appliedSpeed ~= nativeSpeed then
		trackManager:adjustSpeed(slot, nativeSpeed)
		layer.appliedSpeed = nativeSpeed
		if not looped then
			local length = trackManager:getLength(slot)
			if length > 0 and isOnOutwardEnd(trackManager:getTimePosition(slot), length, nativeSpeed) then
				layer.completed = true
			end
		end
	end
	return waiting
end

local LayerController = {}
LayerController.__index = LayerController

function LayerController.new(animator: Animator, layerDefinitions: { LayerDefinition }): LayerControllerOwned
	local layers: { [string]: LayerControllerLayer } = {}
	local layerOrder: { LayerControllerLayer } = table.create(#layerDefinitions) :: { LayerControllerLayer }
	for slot, definition in layerDefinitions do
		local name = definition.name
		if typeof(name) ~= "string" or name == "" then
			error("a layer's name must be a non-empty string", 2)
		end
		if layers[name] ~= nil then
			error(`layer "{name}" is defined twice`, 2)
		end
		if definition.robloxPriority == nil then
			error(`layer "{name}" has no robloxPriority`, 2)
		end
		local fadeIn = definition.fadeIn
		local fadeOut = definition.fadeOut
		if
			(fadeIn ~= nil and not (isFinite(fadeIn) and fadeIn >= 0))
			or (fadeOut ~= nil and not (isFinite(fadeOut) and fadeOut >= 0))
		then
			error(`layer "{name}": fadeIn and fadeOut must be finite numbers of seconds, 0 or more`, 2)
		end
		local layer: LayerControllerLayer = {
			name = name,
			slot = slot,
			robloxPriority = definition.robloxPriority,
			fadeIn = fadeIn,
			fadeOut = fadeOut,
			timeScale = 1,
			changed = false,
			playId = nil,
			clip = nil,
			speed = 1,
			weight = 1,
			playFadeTime = nil,
			weightFadeTime = nil,
			positionKind = nil,
			positionValue = 0,
			outgoingFadeSet = false,
			outgoingFadeTime = nil,
			completed = false,
			appliedPlayId = nil,
			appliedClip = nil,
			playing = false,
			appliedSpeed = 1,
			appliedWeight = 1,
			reverseHold = false,
		}
		layers[name] = layer
		layerOrder[slot] = layer
	end

	local playEnded: CallbackList<string, number, PlayEndedReason> = LuauUtils.callbackList.new()
	local self: LayerControllerImpl
	local trackManager = TrackManager.new(animator, function(slot: number): ()
		slotEnded(self, slot)
	end)
	self = (
		setmetatable({
			_trackManager = trackManager,
			_layers = layers,
			_layerOrder = layerOrder,
			_markers = {},
			_playEnded = playEnded,
			_lastPlayId = 0,
			_changed = false,
			_deconstructed = false,
		}, LayerController) :: unknown
	) :: LayerControllerImpl
	return self
end

function LayerController.play(
	self: LayerControllerImpl,
	layerName: string,
	clip: ClipDefinition,
	speed: number?,
	fadeTime: number?
): number
	local layer = requireLayer(self, layerName)
	local playSpeed = if speed ~= nil then speed else 1
	if not isFinite(playSpeed) then
		error("speed must be a finite number", 2)
	end
	checkFadeTime(fadeTime)

	local endedPlayId = layer.playId
	local endedReason = if layer.completed then PlayEndedReason.completed else PlayEndedReason.replaced
	local playId = self._lastPlayId + 1
	self._lastPlayId = playId
	layer.playId = playId
	layer.clip = clip
	layer.speed = playSpeed
	layer.playFadeTime = fadeTime
	layer.positionKind = nil
	layer.completed = false
	markChanged(self, layer)
	if endedPlayId ~= nil then
		self._playEnded:fire(layer.name, endedPlayId, endedReason)
	end
	return playId
end

function LayerController.stop(self: LayerControllerImpl, layerName: string, fadeTime: number?): ()
	local layer = requireLayer(self, layerName)
	checkFadeTime(fadeTime)
	local endedPlayId = layer.playId
	if endedPlayId == nil and not layer.playing then
		return
	end
	local endedReason = if layer.completed then PlayEndedReason.completed else PlayEndedReason.stopped
	layer.playId = nil
	layer.clip = nil
	layer.positionKind = nil
	layer.completed = false
	layer.outgoingFadeSet = true
	layer.outgoingFadeTime = if fadeTime ~= nil then fadeTime else layer.fadeOut
	markChanged(self, layer)
	if endedPlayId ~= nil then
		self._playEnded:fire(layer.name, endedPlayId, endedReason)
	end
end

function LayerController.getPlayId(self: LayerControllerImpl, layerName: string): number?
	return requireLayer(self, layerName).playId
end

function LayerController.setClipSpeed(self: LayerControllerImpl, layerName: string, speed: number): number?
	local layer = requireLayer(self, layerName)
	if not isFinite(speed) then
		error("speed must be a finite number", 2)
	end
	if layer.playId == nil then
		return nil
	end
	local current = layer.speed
	if speed ~= current then
		local replaces: boolean
		if (speed == 0) ~= (current == 0) or (speed < 0) ~= (current < 0) then
			replaces = true
		else
			local difference = math.abs(speed - current)
			local larger = math.max(math.abs(speed), math.abs(current))
			replaces = difference > math.max(SPEED_ABSOLUTE_TOLERANCE, SPEED_RELATIVE_TOLERANCE * larger)
		end
		if replaces then
			layer.speed = speed
			markChanged(self, layer)
		end
	end
	return layer.speed
end

function LayerController.setClipTime(self: LayerControllerImpl, layerName: string, seconds: number): ()
	local layer = requireLayer(self, layerName)
	if not (isFinite(seconds) and seconds >= 0) then
		error("seconds must be a finite number, 0 or more", 2)
	end
	if layer.playId == nil then
		return
	end
	layer.positionKind = "seconds"
	layer.positionValue = seconds
	markChanged(self, layer)
end

function LayerController.setClipNormalizedTime(self: LayerControllerImpl, layerName: string, alpha: number): ()
	local layer = requireLayer(self, layerName)
	if not (alpha >= 0 and alpha <= 1) then
		error("alpha must be a number from 0 to 1", 2)
	end
	if layer.playId == nil then
		return
	end
	layer.positionKind = "normalized"
	layer.positionValue = alpha
	markChanged(self, layer)
end

function LayerController.setLayerWeight(
	self: LayerControllerImpl,
	layerName: string,
	weight: number,
	fadeTime: number?
): ()
	local layer = requireLayer(self, layerName)
	if not (isFinite(weight) and weight >= 0) then
		error("weight must be a finite number, 0 or more", 2)
	end
	checkFadeTime(fadeTime)
	if layer.weight == weight then
		return
	end
	layer.weight = weight
	layer.weightFadeTime = fadeTime
	-- With nothing playing there is nothing to tell the engine: the next play uses the weight.
	if layer.playId ~= nil then
		markChanged(self, layer)
	end
end

function LayerController.setLayerTimeScale(self: LayerControllerImpl, layerName: string, rate: number): ()
	local layer = requireLayer(self, layerName)
	if not isFinite(rate) then
		error("rate must be a finite number", 2)
	end
	if layer.timeScale == rate then
		return
	end
	layer.timeScale = rate
	if layer.playId ~= nil then
		markChanged(self, layer)
	end
end

function LayerController.onPlayEnded(
	self: LayerControllerImpl,
	callback: (layer: string, playId: number, reason: PlayEndedReason) -> ()
): Unsubscribe
	if self._deconstructed then
		error("LayerController is deconstructed", 2)
	end
	return self._playEnded:add(callback)
end

function LayerController.onMarker(
	self: LayerControllerImpl,
	markerName: string,
	callback: (layer: string, playId: number, clip: ClipDefinition, value: string) -> ()
): Unsubscribe
	if self._deconstructed then
		error("LayerController is deconstructed", 2)
	end
	if typeof(markerName) ~= "string" or markerName == "" then
		error("markerName must be a non-empty string", 2)
	end
	local markers = self._markers
	local trackManager = self._trackManager
	local existing = markers[markerName]
	local marker: LayerControllerMarker
	if existing ~= nil then
		marker = existing
	else
		local list: CallbackList<string, number, ClipDefinition, string> = LuauUtils.callbackList.new()
		local layerOrder = self._layerOrder
		marker = { list = list, subscriberCount = 0 }
		markers[markerName] = marker
		-- Called inside the engine's marker signal, for a track that is playing in a slot.
		trackManager:connectMarker(markerName, function(slot: number, value: string): ()
			local layer = layerOrder[slot]
			local playId = layer.appliedPlayId
			local clip = layer.appliedClip
			if playId ~= nil and clip ~= nil and not layer.completed then
				list:fire(layer.name, playId, clip, value)
			end
		end)
	end
	marker.subscriberCount += 1
	local release = marker.list:add(callback)
	local subscribed = true
	return function(): ()
		if not subscribed then
			return
		end
		subscribed = false
		release()
		marker.subscriberCount -= 1
		if marker.subscriberCount == 0 and markers[markerName] == marker then
			markers[markerName] = nil
			trackManager:disconnectMarker(markerName)
		end
	end
end

function LayerController.update(self: LayerControllerImpl): ()
	if not self._changed then
		return
	end
	local layerOrder = self._layerOrder
	for _, layer in layerOrder do
		if layer.changed then
			layer.changed = reconcileLayer(self, layer)
		end
	end
	for _, layer in layerOrder do
		local playId = layer.playId
		if layer.completed and playId ~= nil then
			-- A track that was placed on its end is still playing in the engine; one the engine ended
			-- has already left its slot.
			if layer.playing then
				layer.playing = false
				self._trackManager:stop(layer.slot, layer.fadeOut)
			end
			emptyLayer(layer)
			self._playEnded:fire(layer.name, playId, PlayEndedReason.completed)
		end
	end
	-- A callback above, or an engine signal during the calls, may have asked for more.
	local changed = false
	for _, layer in layerOrder do
		if layer.changed or layer.completed then
			changed = true
			break
		end
	end
	self._changed = changed
end

function LayerController.clear(self: LayerControllerImpl): ()
	if self._deconstructed then
		return
	end
	-- Every track is stopped before the first report, so a callback sees the engine idle.
	forgetAppliedPlays(self)
	self._trackManager:stopAll()
	reportPlaysEnded(self, self._lastPlayId)
end

function LayerController.deconstruct(self: LayerControllerImpl): ()
	if self._deconstructed then
		return
	end
	-- The reports come first, while every method still works. A play a callback starts is reported
	-- on the next pass, so no play outlives the controller.
	forgetAppliedPlays(self)
	local reported: boolean
	repeat
		reported = reportPlaysEnded(self, self._lastPlayId)
	until not reported
	-- A callback may have called `deconstruct`, which then did the rest.
	if self._deconstructed then
		return
	end
	self._deconstructed = true
	table.clear(self._markers)
	self._playEnded:clear()
	self._trackManager:deconstruct()
end

table.freeze(LayerController)

local module: LayerControllerModule = table.freeze({ new = LayerController.new })
return module
