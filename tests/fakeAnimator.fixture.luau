--!strict
--!optimize 2
-- A stand-in for the engine's Animator and its AnimationTracks, for tests of the controller under
-- Lune. It does only what a test tells it: nothing advances, no track ends and no signal fires until
-- a test calls one of a track's hooks. The one exception is `Stop`, which fires `Stopped` inside the
-- call, as the engine does when signals are immediate.
--
-- Every engine call and every write or read of a track's `Length` and `TimePosition` adds one to
-- `callCount`. While `logging` is true it is also written to the log, which `takeLog` returns as one
-- comma-separated string: `load(rbxassetid://101)->t1`, `t1.Play(0.2,1,1)`, `t1.Priority=Movement`,
-- `t1.Length?`. Track `tN` is the Nth track loaded. With `logging` false the fake allocates nothing.

export type FakeConnection = {
	Connected: boolean,
	Disconnect: (self: FakeConnection) -> (),
}

type FakeSignal = {
	label: string,
	callbacks: { [FakeConnection]: (...any) -> () },
	Connect: (self: FakeSignal, callback: (...any) -> ()) -> FakeConnection,
}

type TrackProperties = {
	Looped: boolean,
	Priority: any,
	Length: number,
	TimePosition: number,
	IsPlaying: boolean,
	Speed: number,
	Weight: number,
}

-- What a test holds for one loaded track.
export type FakeTrack = {
	read name: string,
	-- The values the engine would hold: what the controller wrote, and what a test set.
	read properties: TrackProperties,
	destroyed: boolean,
	-- The engine ends the track by itself: it stops playing and `Stopped` fires.
	read endNaturally: () -> (),
	-- The engine finishes the track's fade-out: `Ended` fires.
	read finishFade: () -> (),
	-- The signals alone, without changing what the track holds, for a signal that arrives late.
	read fireStopped: () -> (),
	read fireEnded: () -> (),
	read fireMarker: (markerName: string, value: string) -> (),
	read connectionCount: (signalName: string) -> number,
}

export type FakeAnimator = {
	logging: boolean,
	callCount: number,
	-- The name of an engine call (`LoadAnimation`, `Play`, `Stop`, `AdjustSpeed`, `AdjustWeight`,
	-- `TimePosition`) that raises the next time it is made, once.
	raiseOn: string?,
	-- When true, a `Stop` that stops a playing track also fires `Ended` before it returns, as the
	-- engine may for a fade of 0.
	endedInsideStop: boolean,
	-- The `Length` a newly loaded track has; 0 is a track whose length has not loaded.
	defaultLength: number,
	read tracks: { FakeTrack },
	-- The Animation each `LoadAnimation` was given: `loadedAnimations[N]` is track `tN`'s.
	read loadedAnimations: { any },
	read takeLog: () -> string,
	-- The object to pass where the controller takes an Animator.
	read engine: any,
}

type FakeAnimatorModule = {
	read new: (defaultLength: number) -> FakeAnimator,
}

local function describe(value: any): string
	if typeof(value) == "EnumItem" then
		return value.Name
	end
	return tostring(value)
end

local function new(defaultLength: number): FakeAnimator
	local log: { string } = {}
	local tracks: { FakeTrack } = {}
	local animator: FakeAnimator

	local function called(): ()
		animator.callCount += 1
	end

	local function raiseIfAsked(callName: string): ()
		if animator.raiseOn == callName then
			animator.raiseOn = nil
			error("engine: " .. callName .. " raised", 0)
		end
	end

	local function newSignal(label: string): FakeSignal
		local signal: FakeSignal
		signal = {
			label = label,
			callbacks = {},
			Connect = function(_self: FakeSignal, callback: (...any) -> ()): FakeConnection
				called()
				if animator.logging then
					table.insert(log, label .. ":Connect")
				end
				local connection: FakeConnection
				connection = {
					Connected = true,
					Disconnect = function(connectionSelf: FakeConnection): ()
						if connectionSelf.Connected then
							connectionSelf.Connected = false
							signal.callbacks[connectionSelf] = nil
							called()
							if animator.logging then
								table.insert(log, label .. ":Disconnect")
							end
						end
					end,
				}
				signal.callbacks[connection] = callback
				return connection
			end,
		}
		return signal
	end

	local function fire(signal: FakeSignal, ...: any): ()
		for _, callback in table.clone(signal.callbacks) do
			callback(...)
		end
	end

	local function countConnections(signal: FakeSignal): number
		local count = 0
		for _ in signal.callbacks do
			count += 1
		end
		return count
	end

	local function loadTrack(): any
		local name = "t" .. (#tracks + 1)
		local properties: TrackProperties = {
			Looped = false,
			Priority = nil,
			Length = animator.defaultLength,
			TimePosition = 0,
			IsPlaying = false,
			Speed = 1,
			Weight = 0,
		}
		local stopped = newSignal(name .. ".Stopped")
		local ended = newSignal(name .. ".Ended")
		local markers: { [string]: FakeSignal } = {}
		local fakeTrack: FakeTrack

		local members = {
			Stopped = stopped,
			Ended = ended,
			Play = function(_self: any, fadeTime: number?, weight: number?, speed: number?): ()
				raiseIfAsked("Play")
				called()
				if animator.logging then
					table.insert(log, `{name}.Play({describe(fadeTime)},{describe(weight)},{describe(speed)})`)
				end
				properties.IsPlaying = true
				properties.TimePosition = 0
				properties.Weight = weight or 1
				properties.Speed = speed or 1
			end,
			Stop = function(_self: any, fadeTime: number?): ()
				raiseIfAsked("Stop")
				called()
				if animator.logging then
					table.insert(log, `{name}.Stop({describe(fadeTime)})`)
				end
				local wasPlaying = properties.IsPlaying
				properties.IsPlaying = false
				if wasPlaying then
					fire(stopped)
					if animator.endedInsideStop then
						fire(ended)
					end
				end
			end,
			AdjustSpeed = function(_self: any, speed: number): ()
				raiseIfAsked("AdjustSpeed")
				called()
				if animator.logging then
					table.insert(log, `{name}.AdjustSpeed({describe(speed)})`)
				end
				properties.Speed = speed
			end,
			AdjustWeight = function(_self: any, weight: number, fadeTime: number?): ()
				raiseIfAsked("AdjustWeight")
				called()
				if animator.logging then
					table.insert(log, `{name}.AdjustWeight({describe(weight)},{describe(fadeTime)})`)
				end
				properties.Weight = weight
			end,
			GetMarkerReachedSignal = function(_self: any, markerName: string): FakeSignal
				local signal = markers[markerName]
				if signal == nil then
					signal = newSignal(`{name}.Marker({markerName})`)
					markers[markerName] = signal
				end
				return signal
			end,
			Destroy = function(_self: any): ()
				called()
				if animator.logging then
					table.insert(log, name .. ".Destroy()")
				end
				fakeTrack.destroyed = true
			end,
		}

		fakeTrack = {
			name = name,
			properties = properties,
			destroyed = false,
			endNaturally = function(): ()
				properties.IsPlaying = false
				fire(stopped)
			end,
			finishFade = function(): ()
				fire(ended)
			end,
			fireStopped = function(): ()
				fire(stopped)
			end,
			fireEnded = function(): ()
				fire(ended)
			end,
			fireMarker = function(markerName: string, value: string): ()
				local signal = markers[markerName]
				if signal ~= nil then
					fire(signal, value)
				end
			end,
			connectionCount = function(signalName: string): number
				if signalName == "Stopped" then
					return countConnections(stopped)
				elseif signalName == "Ended" then
					return countConnections(ended)
				end
				local signal = markers[signalName]
				return if signal ~= nil then countConnections(signal) else 0
			end,
		}
		table.insert(tracks, fakeTrack)

		return setmetatable({}, {
			__index = function(_proxy: any, key: string): any
				local member = (members :: { [string]: any })[key]
				if member ~= nil then
					return member
				end
				if key == "Length" or key == "TimePosition" then
					called()
					if animator.logging then
						table.insert(log, `{name}.{key}?`)
					end
				end
				return (properties :: { [string]: any })[key]
			end,
			__newindex = function(_proxy: any, key: string, value: any): ()
				raiseIfAsked(key)
				called()
				if animator.logging then
					table.insert(log, `{name}.{key}={describe(value)}`)
				end
				(properties :: { [string]: any })[key] = value
			end,
		})
	end

	animator = {
		logging = true,
		callCount = 0,
		raiseOn = nil,
		endedInsideStop = false,
		defaultLength = defaultLength,
		tracks = tracks,
		loadedAnimations = {},
		takeLog = function(): string
			local text = table.concat(log, ",")
			table.clear(log)
			return text
		end,
		engine = {
			LoadAnimation = function(_self: any, animation: any): any
				raiseIfAsked("LoadAnimation")
				called()
				local track = loadTrack()
				table.insert(animator.loadedAnimations, animation)
				if animator.logging then
					table.insert(log, `load({animation.AnimationId})->t{#tracks}`)
				end
				return track
			end,
		},
	}
	return animator
end

local module: FakeAnimatorModule = table.freeze({ new = new })
return module
