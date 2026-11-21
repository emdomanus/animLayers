--!native
--!strict
--!optimize 2
-- The engine side of a layerController: every AnimationTrack loaded on one Animator, and every
-- engine call. The controller that constructs it decides what plays; this object loads the tracks,
-- keeps them, plays and stops them, and reads the engine's signals.
--
-- A loaded track is kept and played again the next time its clip is played while the track is idle.
-- Tracks are destroyed by `deconstruct`, and by a load that takes the count above TRACK_CAPACITY,
-- which drops the idle track played longest ago.
--
-- A track's state is changed before the engine call that causes it, so a signal the engine fires
-- inside that call finds the state it belongs to: `stop` marks the track as fading and empties its
-- slot, then calls Stop, and an Ended fired inside Stop returns the track to idle.
local ClipDefinitionPrivateTypes = require("../../types/def/playback/clipDefinition/private")
local ClipDefinitionTypes = require("../../types/def/playback/clipDefinition/public")
local TrackManagerPrivateTypes = require("../../types/managers/trackManager/trackManager/private")
local TrackManagerTypes = require("../../types/managers/trackManager/trackManager/public")

type ClipDefinition = ClipDefinitionTypes.ClipDefinition
type ClipDefinitionImpl = ClipDefinitionPrivateTypes.ClipDefinitionImpl
type TrackManagerOwned = TrackManagerTypes.TrackManagerOwned
type TrackManagerImpl = TrackManagerPrivateTypes.TrackManagerImpl
type TrackManagerMarker = TrackManagerPrivateTypes.TrackManagerMarker
type TrackManagerTrack = TrackManagerPrivateTypes.TrackManagerTrack
export type TrackManagerModule = {
	read new: (animator: Animator, onSlotEnded: (slot: number) -> ()) -> TrackManagerOwned,
}

-- Kept tracks per manager. Roblox limits the tracks playing at once on an Animator, not the tracks
-- loaded, so this is a memory bound: more than the distinct clips one body cycles through.
local TRACK_CAPACITY = 64

-- The engine ended `track` while it played in a slot, and the manager had not stopped it.
local function trackEndedInEngine(self: TrackManagerImpl, track: TrackManagerTrack): ()
	local slot = track.slot
	track.state = "fading"
	track.slot = 0
	self._playingBySlot[slot] = nil
	self._onSlotEnded(slot)
end

local function connectMarker(track: TrackManagerTrack, markerName: string, marker: TrackManagerMarker): ()
	local callback = marker.callback
	marker.connections[track] = track.track:GetMarkerReachedSignal(markerName):Connect(function(value: string): ()
		if track.state == "playing" then
			callback(track.slot, value)
		end
	end)
end

local function destroyTrack(self: TrackManagerImpl, track: TrackManagerTrack): ()
	local stoppedConnection = track.stoppedConnection
	if stoppedConnection ~= nil then
		stoppedConnection:Disconnect()
	end
	local endedConnection = track.endedConnection
	if endedConnection ~= nil then
		endedConnection:Disconnect()
	end
	for _, marker in self._markers do
		local connection = marker.connections[track]
		if connection ~= nil then
			connection:Disconnect()
			marker.connections[track] = nil
		end
	end
	track.track:Destroy()
end

-- Destroys the idle track that was played longest ago, other than `kept`. Does nothing when every
-- other track is playing or fading out.
local function dropLeastRecentIdleTrack(self: TrackManagerImpl, kept: TrackManagerTrack): ()
	local tracks = self._tracks
	local dropIndex: number? = nil
	local dropLastPlayed = math.huge
	for index, track in tracks do
		if track ~= kept and track.state == "idle" and track.lastPlayed < dropLastPlayed then
			dropIndex = index
			dropLastPlayed = track.lastPlayed
		end
	end
	if dropIndex ~= nil then
		local dropped = tracks[dropIndex]
		local last = #tracks
		tracks[dropIndex] = tracks[last]
		tracks[last] = nil
		destroyTrack(self, dropped)
	end
end

-- An idle track of this clip, or a newly loaded one.
local function acquireTrack(self: TrackManagerImpl, clip: ClipDefinition): TrackManagerTrack
	local tracks = self._tracks
	for _, track in tracks do
		if track.clip == clip and track.state == "idle" then
			return track
		end
	end

	local animation = (clip :: ClipDefinitionImpl).animation
	if animation == nil then
		error("the clip was not made by clipDefinition.build", 0)
	end
	local engineTrack = self._animator:LoadAnimation(animation)
	engineTrack.Looped = clip.looped
	local track: TrackManagerTrack = {
		clip = clip,
		track = engineTrack,
		state = "idle",
		slot = 0,
		lastPlayed = 0,
		robloxPriority = nil,
		stoppedConnection = nil,
		endedConnection = nil,
	}
	-- A signal is read as the engine ending the track only while the track is in a slot and the
	-- engine says it is not playing. The manager's own Stop leaves "playing" before the call, and
	-- the second test discards a signal that arrives after the track was played again.
	track.stoppedConnection = engineTrack.Stopped:Connect(function(): ()
		if track.state == "playing" and not engineTrack.IsPlaying then
			trackEndedInEngine(self, track)
		end
	end)
	track.endedConnection = engineTrack.Ended:Connect(function(): ()
		if track.state == "fading" then
			track.state = "idle"
		elseif track.state == "playing" and not engineTrack.IsPlaying then
			trackEndedInEngine(self, track)
			track.state = "idle"
		end
	end)
	for markerName, marker in self._markers do
		connectMarker(track, markerName, marker)
	end
	table.insert(tracks, track)
	if #tracks > TRACK_CAPACITY then
		dropLeastRecentIdleTrack(self, track)
	end
	return track
end

local TrackManager = {}
TrackManager.__index = TrackManager

function TrackManager.new(animator: Animator, onSlotEnded: (slot: number) -> ()): TrackManagerOwned
	local self: TrackManagerImpl = (
		setmetatable({
			_animator = animator,
			_onSlotEnded = onSlotEnded,
			_tracks = {},
			_playingBySlot = {},
			_markers = {},
			_playCount = 0,
		}, TrackManager) :: unknown
	) :: TrackManagerImpl
	return self
end

function TrackManager.play(
	self: TrackManagerImpl,
	slot: number,
	clip: ClipDefinition,
	robloxPriority: Enum.AnimationPriority,
	fadeTime: number?,
	weight: number,
	speed: number,
	holdWithoutLength: boolean
): boolean
	local track = acquireTrack(self, clip)
	local engineTrack = track.track
	if track.robloxPriority ~= robloxPriority then
		engineTrack.Priority = robloxPriority
		track.robloxPriority = robloxPriority
	end
	local held = holdWithoutLength and engineTrack.Length <= 0
	engineTrack:Play(fadeTime, weight, if held then 0 else speed)
	local playCount = self._playCount + 1
	self._playCount = playCount
	track.state = "playing"
	track.slot = slot
	track.lastPlayed = playCount
	self._playingBySlot[slot] = track
	return held
end

function TrackManager.stop(self: TrackManagerImpl, slot: number, fadeTime: number?): ()
	local track = self._playingBySlot[slot]
	if track == nil then
		return
	end
	track.state = "fading"
	track.slot = 0
	self._playingBySlot[slot] = nil
	track.track:Stop(fadeTime)
end

function TrackManager.adjustSpeed(self: TrackManagerImpl, slot: number, speed: number): ()
	local track = self._playingBySlot[slot]
	if track ~= nil then
		track.track:AdjustSpeed(speed)
	end
end

function TrackManager.adjustWeight(self: TrackManagerImpl, slot: number, weight: number, fadeTime: number?): ()
	local track = self._playingBySlot[slot]
	if track ~= nil then
		track.track:AdjustWeight(weight, fadeTime)
	end
end

function TrackManager.getLength(self: TrackManagerImpl, slot: number): number
	local track = self._playingBySlot[slot]
	return if track ~= nil then track.track.Length else 0
end

function TrackManager.getTimePosition(self: TrackManagerImpl, slot: number): number
	local track = self._playingBySlot[slot]
	return if track ~= nil then track.track.TimePosition else 0
end

function TrackManager.setTimePosition(self: TrackManagerImpl, slot: number, seconds: number): ()
	local track = self._playingBySlot[slot]
	if track ~= nil then
		track.track.TimePosition = seconds
	end
end

function TrackManager.connectMarker(
	self: TrackManagerImpl,
	markerName: string,
	callback: (slot: number, value: string) -> ()
): ()
	local marker: TrackManagerMarker = { callback = callback, connections = {} }
	self._markers[markerName] = marker
	for _, track in self._tracks do
		connectMarker(track, markerName, marker)
	end
end

function TrackManager.disconnectMarker(self: TrackManagerImpl, markerName: string): ()
	local marker = self._markers[markerName]
	if marker == nil then
		return
	end
	self._markers[markerName] = nil
	for _, connection in marker.connections do
		connection:Disconnect()
	end
	table.clear(marker.connections)
end

function TrackManager.stopAll(self: TrackManagerImpl): ()
	table.clear(self._playingBySlot)
	for _, track in self._tracks do
		if track.state ~= "idle" then
			track.state = "idle"
			track.slot = 0
			track.track:Stop(0)
		end
	end
end

function TrackManager.deconstruct(self: TrackManagerImpl): ()
	table.clear(self._playingBySlot)
	local tracks = self._tracks
	for _, track in tracks do
		if track.state ~= "idle" then
			track.state = "idle"
			track.slot = 0
			track.track:Stop(0)
		end
		destroyTrack(self, track)
	end
	table.clear(tracks)
	table.clear(self._markers)
end

table.freeze(TrackManager)

local module: TrackManagerModule = table.freeze({ new = TrackManager.new })
return module
