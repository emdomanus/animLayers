--!strict
--!optimize 2
-- layerController through the package entry, over a stand-in Animator: which engine calls an
-- `update` makes and in what order, which it does not make, when the subscribers are called, what a
-- raising engine call leaves behind, which tracks are kept, and what `update` allocates.
local FakeAnimatorFixture = require("../../../fakeAnimator.fixture")
local RobloxEnvironmentFixture = require("../../../robloxEnvironment.fixture")

RobloxEnvironmentFixture.install()

local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers/shared")

type ClipDefinition = AnimLayers.ClipDefinition
type FakeAnimator = FakeAnimatorFixture.FakeAnimator
type LayerControllerOwned = AnimLayers.LayerControllerOwned
type LayerDefinition = AnimLayers.LayerDefinition

local LAYERS: { LayerDefinition } = {
	{ name = "base", robloxPriority = Enum.AnimationPriority.Movement, fadeIn = 0.2, fadeOut = 0.3 },
	{ name = "action", robloxPriority = Enum.AnimationPriority.Action },
	{ name = "overlay", robloxPriority = Enum.AnimationPriority.Action },
}
local WALK = AnimLayers.utils.clipDefinition.build(101, true)
local IDLE = AnimLayers.utils.clipDefinition.build(102, true)
local WAVE = AnimLayers.utils.clipDefinition.build(201, false)
local CHEER = AnimLayers.utils.clipDefinition.build(202, false)

local function case(name: string, body: () -> ()): ()
	body()
	print("PASS " .. name)
end

-- A controller over a fake Animator whose tracks have this length; 0 is a length not yet loaded.
local function newController(trackLength: number?): (LayerControllerOwned, FakeAnimator)
	local animator = FakeAnimatorFixture.new(if trackLength ~= nil then trackLength else 2)
	-- The fake stands in for an engine Instance, which no Luau table has the type of.
	local controller = AnimLayers.controllers.layerController.new(animator.engine :: any, LAYERS)
	return controller, animator
end

local function expectLog(animator: FakeAnimator, expected: string): ()
	local actual = animator.takeLog()
	assert(actual == expected, `expected the engine calls\n  {expected}\ngot\n  {actual}`)
end

-- The calls a first play of a clip makes before its `Play`.
local function loadLog(track: string, assetId: number, looped: boolean, priority: string): string
	return `load(rbxassetid://{assetId})->{track},{track}.Looped={looped},{track}.Stopped:Connect,`
		.. `{track}.Ended:Connect,{track}.Priority={priority}`
end

-- Records every completion as "layer:playId".
local function recordCompletions(controller: LayerControllerOwned): { string }
	local completed: { string } = {}
	controller:onPlayCompleted(function(layer, playId)
		table.insert(completed, `{layer}:{playId}`)
	end)
	return completed
end

local function expectList(actual: { string }, expected: string): ()
	local joined = table.concat(actual, ",")
	assert(joined == expected, `expected '{expected}', got '{joined}'`)
	table.clear(actual)
end

local function expectRaise(body: () -> (), text: string): ()
	local ok, failure = pcall(body)
	assert(not ok, "expected a raise containing '" .. text .. "'")
	assert(string.find(tostring(failure), text, 1, true) ~= nil, `expected '{text}' in '{tostring(failure)}'`)
end

case("a command calls nothing; update makes the engine calls, in order, once", function()
	local controller, animator = newController()
	local first = controller:play("base", WALK)
	expectLog(animator, "")
	controller:update()
	expectLog(animator, loadLog("t1", 101, true, "Movement") .. ",t1.Play(0.2,1,1)")
	controller:update()
	controller:update()
	expectLog(animator, "")

	-- The speed and the fade are the play's and the weight is the layer's; a layer without fadeIn
	-- hands the engine no fade.
	controller:setLayerWeight("action", 0.5)
	local second = controller:play("action", WAVE, 2, 0.75)
	local third = controller:play("overlay", CHEER)
	controller:update()
	expectLog(
		animator,
		loadLog("t2", 201, false, "Action")
			.. ",t2.Play(0.75,0.5,2),"
			.. loadLog("t3", 202, false, "Action")
			.. ",t3.Play(nil,1,1)"
	)
	assert(first == 1 and second == 2 and third == 3, "play ids count up per controller")
end)

case("a track the engine has ended is played again, with no load and only the writes that differ", function()
	local controller, animator = newController()
	controller:play("base", WALK)
	controller:update()
	animator.takeLog()
	controller:stop("base")
	controller:update()
	expectLog(animator, "t1.Stop(0.3)")
	animator.tracks[1].finishFade()

	controller:play("base", WALK)
	controller:update()
	expectLog(animator, "t1.Play(0.2,1,1)")

	-- The same track on a layer with another priority: the priority is written again.
	controller:stop("base", 0)
	controller:update()
	animator.tracks[1].finishFade()
	animator.takeLog()
	controller:play("action", WALK)
	controller:update()
	expectLog(animator, "t1.Priority=Action,t1.Play(nil,1,1)")
end)

case("playing a clip again while its track fades out loads a second track", function()
	local controller, animator = newController()
	local first = controller:play("base", WALK)
	controller:update()
	animator.takeLog()
	local second = controller:play("base", WALK)
	controller:update()
	-- The outgoing track fades over the new play's fade, here the layer's fadeIn.
	expectLog(animator, "t1.Stop(0.2)," .. loadLog("t2", 101, true, "Movement") .. ",t2.Play(0.2,1,1)")
	assert(second == first + 1, "the second play has its own id")
end)

case("stop before play gives the outgoing track stop's fade; play alone gives it the new play's", function()
	local controller, animator = newController()
	controller:play("base", WALK)
	controller:update()
	animator.takeLog()

	controller:stop("base", 1)
	controller:play("base", IDLE, nil, 0.05)
	controller:update()
	expectLog(animator, "t1.Stop(1)," .. loadLog("t2", 102, true, "Movement") .. ",t2.Play(0.05,1,1)")

	controller:play("base", WALK, nil, 0.6)
	controller:update()
	expectLog(animator, "t2.Stop(0.6)," .. loadLog("t3", 101, true, "Movement") .. ",t3.Play(0.6,1,1)")
end)

case("several commands before one update cost what their final state costs", function()
	local controller, animator = newController()
	controller:play("action", WAVE)
	controller:play("action", CHEER)
	controller:setClipSpeed("action", 2)
	controller:setClipSpeed("action", 3)
	controller:setLayerWeight("action", 0.5)
	controller:update()
	expectLog(animator, loadLog("t1", 202, false, "Action") .. ",t1.Play(nil,0.5,3)")

	controller:setClipSpeed("action", 1)
	controller:setClipSpeed("action", 4)
	controller:update()
	-- A clip that does not loop is also checked for sitting on its end.
	expectLog(animator, "t1.AdjustSpeed(4),t1.Length?,t1.TimePosition?")

	-- A play that is stopped before any update never reaches the engine.
	controller:play("base", WALK)
	controller:stop("base")
	controller:update()
	expectLog(animator, "")
end)

case("setClipSpeed replaces the speed only beyond the tolerance, and returns the speed in effect", function()
	local controller, animator = newController()
	assert(controller:setClipSpeed("base", 2) == nil, "a layer that plays nothing has no speed")
	controller:play("base", WALK)
	controller:update()
	animator.takeLog()

	assert(controller:setClipSpeed("base", 1.005) == 1, "0.5% is inside the tolerance")
	controller:update()
	expectLog(animator, "")
	assert(controller:setClipSpeed("base", 1.02) == 1.02, "2% is beyond it")
	controller:update()
	expectLog(animator, "t1.AdjustSpeed(1.02)")

	-- To or from 0, and a change of sign, always apply.
	assert(controller:setClipSpeed("base", 0) == 0, "a pause applies")
	assert(controller:setClipSpeed("base", 0.001) == 0.001, "leaving 0 applies")
	assert(controller:setClipSpeed("base", -0.001) == -0.001, "a change of sign applies")
	controller:update()
	expectLog(animator, "t1.AdjustSpeed(-0.001)")

	-- Below 0.5 the absolute bound decides.
	controller:play("base", IDLE, 0.1)
	assert(controller:setClipSpeed("base", 0.104) == 0.1, "0.004 is inside the absolute bound")
	assert(controller:setClipSpeed("base", 0.106) == 0.106, "0.006 is beyond it")
end)

case("the layer's time scale multiplies the speed of what it plays, now and later", function()
	local controller, animator = newController()
	controller:setLayerTimeScale("base", 0.5)
	controller:update()
	expectLog(animator, "")
	controller:play("base", WALK, 2)
	controller:update()
	expectLog(animator, loadLog("t1", 101, true, "Movement") .. ",t1.Play(0.2,1,1)")

	controller:setLayerTimeScale("base", 0)
	controller:update()
	expectLog(animator, "t1.AdjustSpeed(0)")
	controller:setLayerTimeScale("base", 0)
	controller:update()
	expectLog(animator, "")
	controller:setLayerTimeScale("base", 1)
	controller:update()
	expectLog(animator, "t1.AdjustSpeed(2)")
end)

case("a layer's weight starts at 1, is set with or without a clip playing, and stays across plays", function()
	local controller, animator = newController()
	-- With nothing playing, setting the weight calls nothing; the next play starts at it.
	controller:setLayerWeight("action", 0.4, 3)
	controller:update()
	expectLog(animator, "")
	controller:play("action", WAVE)
	controller:update()
	expectLog(animator, loadLog("t1", 201, false, "Action") .. ",t1.Play(nil,0.4,1)")

	-- A change while a clip plays is one AdjustWeight with the fade given, only when it differs.
	controller:setLayerWeight("action", 0.7, 1.5)
	controller:update()
	expectLog(animator, "t1.AdjustWeight(0.7,1.5)")
	controller:setLayerWeight("action", 0.7, 3)
	controller:update()
	expectLog(animator, "")
	controller:setLayerWeight("action", 1)
	controller:update()
	expectLog(animator, "t1.AdjustWeight(1,nil)")

	-- A new weight and a new play in one update: the new clip starts at the weight, and the
	-- outgoing track is only stopped.
	controller:setLayerWeight("action", 0.25, 2)
	controller:play("action", CHEER)
	controller:update()
	expectLog(animator, "t1.Stop(nil)," .. loadLog("t2", 202, false, "Action") .. ",t2.Play(nil,0.25,1)")

	-- The weight outlives stop and clear; the other layers kept theirs, 1.
	controller:stop("action")
	controller:update()
	controller:clear()
	animator.takeLog()
	controller:play("action", CHEER)
	controller:play("base", WALK)
	controller:update()
	expectLog(animator, loadLog("t3", 101, true, "Movement") .. ",t3.Play(0.2,1,1),t2.Play(nil,0.25,1)")
end)

case("a position wraps on a looping clip and is a fraction of the length when normalized", function()
	local controller, animator = newController(2)
	controller:play("base", WALK)
	controller:update()
	animator.takeLog()

	controller:setClipTime("base", 5)
	controller:update()
	expectLog(animator, "t1.Length?,t1.TimePosition=1")
	controller:setClipNormalizedTime("base", 0.25)
	controller:update()
	expectLog(animator, "t1.Length?,t1.TimePosition=0.5")
	controller:setClipNormalizedTime("base", 1)
	controller:update()
	expectLog(animator, "t1.Length?,t1.TimePosition=0")
end)

case("a position waits for the track's length, reading it once per update, and is written once", function()
	local controller, animator = newController(0)
	controller:play("base", WALK)
	controller:setClipTime("base", 0.5)
	controller:update()
	expectLog(animator, loadLog("t1", 101, true, "Movement") .. ",t1.Play(0.2,1,1),t1.Length?")
	controller:update()
	controller:update()
	expectLog(animator, "t1.Length?,t1.Length?")

	animator.tracks[1].properties.Length = 2
	controller:update()
	expectLog(animator, "t1.Length?,t1.TimePosition=0.5")
	controller:update()
	expectLog(animator, "")
end)

case("a clip that runs backwards from a position is held at speed 0 until its length loads", function()
	local controller, animator = newController(0)
	local completed = recordCompletions(controller)
	controller:play("action", WAVE, -1)
	controller:setClipNormalizedTime("action", 1)
	controller:update()
	expectLog(animator, loadLog("t1", 201, false, "Action") .. ",t1.Length?,t1.Play(nil,1,0),t1.Length?")

	animator.tracks[1].properties.Length = 2
	controller:update()
	-- Placed on its upper end and then given its speed, which points away from that end.
	expectLog(animator, "t1.Length?,t1.TimePosition=2,t1.AdjustSpeed(-1),t1.Length?,t1.TimePosition?")
	expectList(completed, "")
end)

case("a natural end is recorded at the engine's report and its subscribers are called from update", function()
	local controller, animator = newController()
	local completed = recordCompletions(controller)
	local playId = controller:play("action", WAVE)
	controller:update()
	animator.takeLog()

	animator.tracks[1].endNaturally()
	expectList(completed, "")
	controller:update()
	expectList(completed, `action:{playId}`)
	-- The engine ended the track itself: the package stops nothing.
	expectLog(animator, "")
	assert(controller:setClipSpeed("action", 2) == nil, "the layer is empty after its play completed")
	controller:update()
	expectList(completed, "")

	-- Once the engine has ended the track, the next play of the clip uses it again.
	animator.tracks[1].finishFade()
	controller:play("action", WAVE)
	controller:update()
	expectLog(animator, "t1.Play(nil,1,1)")

	-- An Ended signal with no Stopped before it is a natural end too.
	animator.tracks[1].properties.IsPlaying = false
	animator.tracks[1].fireEnded()
	controller:update()
	expectList(completed, `action:{playId + 1}`)
end)

case("getPlayId is the id of the play on the layer now, and nil once the layer plays nothing", function()
	local controller, animator = newController()
	assert(controller:getPlayId("action") == nil, "a new layer plays nothing")
	local first = controller:play("action", WAVE)
	assert(controller:getPlayId("action") == first, "the id the first play returned")
	local second = controller:play("action", CHEER)
	assert(second ~= first and controller:getPlayId("action") == second, "the id the second play returned")
	controller:stop("action")
	assert(controller:getPlayId("action") == nil, "nil after stop")
	controller:play("action", WAVE)
	controller:clear()
	assert(controller:getPlayId("action") == nil, "nil after clear")

	local called = false
	local playIdInCallback: number? = -1
	controller:onPlayCompleted(function(layer)
		called = true
		playIdInCallback = controller:getPlayId(layer)
	end)
	local completing = controller:play("action", WAVE)
	controller:update()
	animator.tracks[1].endNaturally()
	assert(controller:getPlayId("action") == completing, "the play stays on the layer until update reports it")
	controller:update()
	assert(called, "the play completed")
	assert(playIdInCallback == nil, "nil inside the onPlayCompleted callback")

	expectRaise(function()
		controller:getPlayId("missing")
	end, 'has no layer "missing"')
end)

case("a clip placed on the end its speed points to completes, and the package stops its track", function()
	local controller, animator = newController(2)
	local completed = recordCompletions(controller)
	local playId = controller:play("action", WAVE)
	controller:update()
	animator.takeLog()

	controller:setClipTime("action", 9)
	controller:update()
	expectLog(animator, "t1.Length?,t1.TimePosition=2,t1.Stop(nil)")
	expectList(completed, `action:{playId}`)

	-- A speed whose sign turns towards the end the track sits on completes it as well.
	animator.tracks[1].finishFade()
	local second = controller:play("action", WAVE)
	controller:update()
	animator.takeLog()
	controller:setClipSpeed("action", -1)
	controller:update()
	expectLog(animator, "t1.AdjustSpeed(-1),t1.Length?,t1.TimePosition?,t1.Stop(nil)")
	expectList(completed, `action:{second}`)
end)

case("stop, a replacement, clear and deconstruct complete nothing", function()
	local controller, animator = newController()
	local completed = recordCompletions(controller)
	controller:play("action", WAVE)
	controller:update()
	controller:stop("action")
	controller:update()
	controller:play("action", WAVE)
	controller:update()
	controller:play("action", CHEER)
	controller:update()
	controller:clear()
	controller:update()
	controller:play("action", CHEER)
	controller:update()
	controller:deconstruct()
	expectList(completed, "")
	animator.takeLog()
end)

case("an end the engine reported is dropped when the caller replaces or stops the play first", function()
	local controller, animator = newController()
	local completed = recordCompletions(controller)
	controller:play("action", WAVE)
	controller:update()
	animator.takeLog()

	animator.tracks[1].endNaturally()
	controller:play("action", CHEER)
	controller:update()
	expectList(completed, "")
	-- The new play starts and is left playing.
	expectLog(animator, loadLog("t2", 202, false, "Action") .. ",t2.Play(nil,1,1)")
	assert(controller:setClipSpeed("action", 1) == 1, "the new play is the layer's play")

	animator.tracks[2].endNaturally()
	controller:stop("action")
	controller:update()
	expectList(completed, "")
	expectLog(animator, "")
end)

case("a looping track the engine ended is played again by the next update, with no completion", function()
	local controller, animator = newController()
	local completed = recordCompletions(controller)
	controller:play("base", WALK)
	controller:update()
	animator.takeLog()

	animator.tracks[1].endNaturally()
	controller:update()
	-- The ended track is not idle until the engine's Ended signal, so a second one is loaded.
	expectLog(animator, loadLog("t2", 101, true, "Movement") .. ",t2.Play(0.2,1,1)")
	expectList(completed, "")
end)

case("the package's own Stop, and a signal that arrives after a track was played again, end nothing", function()
	local controller, animator = newController()
	local completed = recordCompletions(controller)
	controller:play("action", WAVE)
	controller:update()
	-- The fake fires Stopped inside Stop, as the engine does with immediate signals.
	controller:stop("action")
	controller:update()
	controller:update()
	expectList(completed, "")

	controller:clear()
	animator.takeLog()
	local playId = controller:play("action", WAVE)
	controller:update()
	expectLog(animator, "t1.Play(nil,1,1)")
	-- Late signals from the stop above: the track is playing again, so they are not its end.
	animator.tracks[1].fireStopped()
	animator.tracks[1].fireEnded()
	controller:update()
	expectList(completed, "")
	expectLog(animator, "")

	animator.tracks[1].endNaturally()
	controller:update()
	expectList(completed, `action:{playId}`)
end)

case("an Ended that arrives inside the package's Stop returns the track to idle", function()
	local controller, animator = newController()
	animator.endedInsideStop = true
	controller:play("base", WALK)
	controller:update()
	controller:stop("base")
	controller:update()
	animator.takeLog()

	-- The track is idle, so the clip's next play uses it and loads nothing.
	controller:play("base", WALK)
	controller:update()
	expectLog(animator, "t1.Play(0.2,1,1)")
end)

case("a marker subscriber is called inside the engine's signal, for a layer's current play only", function()
	local controller, animator = newController()
	local markers: { string } = {}
	local unsubscribeFootstep = controller:onMarker("Footstep", function(layer, playId, clip, value)
		table.insert(markers, `{layer}:{playId}:{clip.assetId}:{value}`)
	end)
	local playId = controller:play("base", WALK)
	controller:update()
	-- A subscription made before the track was loaded is connected when it loads.
	expectLog(
		animator,
		"load(rbxassetid://101)->t1,t1.Looped=true,t1.Stopped:Connect,t1.Ended:Connect,"
			.. "t1.Marker(Footstep):Connect,t1.Priority=Movement,t1.Play(0.2,1,1)"
	)
	animator.tracks[1].fireMarker("Footstep", "left")
	expectList(markers, `base:{playId}:101:left`)

	-- A second subscriber of the name shares the connection; another name connects every loaded track.
	local unsubscribeSecond = controller:onMarker("Footstep", function(_layer, _playId, _clip, value)
		table.insert(markers, "second:" .. value)
	end)
	expectLog(animator, "")
	controller:onMarker("Hit", function(_layer, _playId, _clip, value)
		table.insert(markers, "hit:" .. value)
	end)
	expectLog(animator, "t1.Marker(Hit):Connect")
	animator.tracks[1].fireMarker("Footstep", "right")
	animator.tracks[1].fireMarker("Hit", "")
	expectList(markers, `base:{playId}:101:right,second:right,hit:`)

	-- The last subscriber of a name to leave disconnects it; leaving twice does nothing more.
	unsubscribeSecond()
	expectLog(animator, "")
	unsubscribeFootstep()
	unsubscribeFootstep()
	expectLog(animator, "t1.Marker(Footstep):Disconnect")

	-- A track that is fading out delivers nothing.
	controller:stop("base")
	controller:update()
	animator.tracks[1].fireMarker("Hit", "late")
	expectList(markers, "")
end)

case("a command made inside a marker or a completion subscriber is applied by the next update", function()
	local controller, animator = newController()
	controller:onMarker("Hit", function(layer)
		controller:stop(layer)
	end)
	controller:onPlayCompleted(function(layer)
		controller:play(layer, CHEER)
	end)
	controller:play("base", WALK)
	controller:play("action", WAVE)
	controller:update()
	animator.takeLog()

	animator.tracks[1].fireMarker("Hit", "")
	expectLog(animator, "")
	controller:update()
	expectLog(animator, "t1.Stop(0.3)")

	animator.tracks[2].endNaturally()
	controller:update()
	-- The subscriber played CHEER during this update; the engine hears of it in the next one.
	expectLog(animator, "")
	controller:update()
	expectLog(
		animator,
		"load(rbxassetid://202)->t3,t3.Looped=false,t3.Stopped:Connect,t3.Ended:Connect,"
			.. "t3.Marker(Hit):Connect,t3.Priority=Action,t3.Play(nil,1,1)"
	)
end)

case("an engine call that raises makes update raise, and the next update makes only the remaining calls", function()
	local controller, animator = newController()
	controller:play("base", WALK)
	animator.raiseOn = "Play"
	expectRaise(function()
		controller:update()
	end, "engine: Play raised")
	-- The load and the priority write returned and are not made again.
	expectLog(animator, loadLog("t1", 101, true, "Movement"))
	controller:update()
	expectLog(animator, "t1.Play(0.2,1,1)")

	controller:setClipSpeed("base", 2)
	controller:setLayerWeight("base", 0.5)
	animator.raiseOn = "AdjustSpeed"
	expectRaise(function()
		controller:update()
	end, "engine: AdjustSpeed raised")
	expectLog(animator, "t1.AdjustWeight(0.5,nil)")
	controller:update()
	expectLog(animator, "t1.AdjustSpeed(2)")

	-- A stop is the exception: the track is marked as stopped before the call, so a Stop that
	-- raised is not made again.
	controller:stop("base")
	animator.raiseOn = "Stop"
	expectRaise(function()
		controller:update()
	end, "engine: Stop raised")
	controller:update()
	expectLog(animator, "")

	controller:play("action", WAVE)
	animator.raiseOn = "LoadAnimation"
	expectRaise(function()
		controller:update()
	end, "engine: LoadAnimation raised")
	controller:update()
	expectLog(animator, loadLog("t2", 201, false, "Action") .. ",t2.Play(nil,1,1)")
end)

case("loaded tracks are kept up to 64; one more drops the idle track played longest ago", function()
	local controller, animator = newController()
	local clips: { ClipDefinition } = {}
	for index = 1, 66 do
		clips[index] = AnimLayers.utils.clipDefinition.build(1000 + index, true)
	end
	for index = 1, 64 do
		controller:play("action", clips[index])
		controller:update()
		if index > 1 then
			animator.tracks[index - 1].finishFade()
		end
	end
	animator.takeLog()
	assert(#animator.tracks == 64, "64 tracks are loaded")

	controller:play("action", clips[65])
	controller:update()
	expectLog(
		animator,
		"t64.Stop(nil),load(rbxassetid://1065)->t65,t65.Looped=true,t65.Stopped:Connect,t65.Ended:Connect,"
			.. "t1.Stopped:Disconnect,t1.Ended:Disconnect,t1.Destroy(),t65.Priority=Action,t65.Play(nil,1,1)"
	)
	assert(animator.tracks[1].destroyed, "the first track was destroyed")

	-- A kept track is played again without a load, and is then the most recently played.
	controller:play("action", clips[2])
	controller:update()
	expectLog(animator, "t65.Stop(nil),t2.Play(nil,1,1)")

	-- The dropped clip loads again. t64 and t65 are still fading out, so the track dropped is the
	-- idle one played longest ago, t3.
	controller:play("action", clips[1])
	controller:update()
	expectLog(
		animator,
		"t2.Stop(nil),load(rbxassetid://1001)->t66,t66.Looped=true,t66.Stopped:Connect,t66.Ended:Connect,"
			.. "t3.Stopped:Disconnect,t3.Ended:Disconnect,t3.Destroy(),t66.Priority=Action,t66.Play(nil,1,1)"
	)
end)

case("clear stops every track at once, empties every layer, and keeps tracks and time scales", function()
	local controller, animator = newController()
	controller:setLayerTimeScale("base", 0.5)
	controller:play("base", WALK)
	controller:play("action", WAVE)
	controller:update()
	controller:stop("base")
	controller:update()
	animator.takeLog()

	controller:clear()
	-- The track that was fading out and the one that was playing.
	expectLog(animator, "t1.Stop(0),t2.Stop(0)")
	assert(controller:setClipSpeed("action", 2) == nil, "the layers are empty")
	controller:update()
	expectLog(animator, "")

	controller:play("base", WALK)
	controller:update()
	expectLog(animator, "t1.Play(0.2,1,0.5)")
end)

case("deconstruct destroys every track; commands and subscriptions raise afterwards", function()
	local controller, animator = newController()
	controller:onMarker("Hit", function() end)
	controller:play("base", WALK)
	controller:update()
	animator.takeLog()

	controller:deconstruct()
	expectLog(animator, "t1.Stop(0),t1.Stopped:Disconnect,t1.Ended:Disconnect,t1.Marker(Hit):Disconnect,t1.Destroy()")
	controller:deconstruct()
	controller:clear()
	controller:update()
	expectLog(animator, "")
	expectRaise(function()
		controller:play("base", WALK)
	end, "LayerController is deconstructed")
	expectRaise(function()
		controller:onPlayCompleted(function() end)
	end, "LayerController is deconstructed")
end)

case("every controller loads a definition's tracks from the one Animation its build made", function()
	local first, firstAnimator = newController()
	local second, secondAnimator = newController()
	first:play("base", WALK)
	first:update()
	second:play("base", WALK)
	second:update()
	local animation = firstAnimator.loadedAnimations[1]
	assert(animation.ClassName == "Animation", "a track is loaded from an Animation")
	assert(animation.AnimationId == "rbxassetid://101", "got " .. animation.AnimationId)
	assert(secondAnimator.loadedAnimations[1] == animation, "both controllers load from the same Animation")

	-- It outlives a controller: deconstruct destroys tracks, not the definition's Animation.
	first:deconstruct()
	second:play("action", WALK)
	second:update()
	assert(secondAnimator.loadedAnimations[2] == animation, "the Animation is still the definition's")

	-- A second build of the asset is a second definition with its own Animation, and an asset id
	-- of fifteen digits is written in full.
	local again = AnimLayers.utils.clipDefinition.build(101, true)
	local long = AnimLayers.utils.clipDefinition.build(123456789012345, false)
	second:play("base", again)
	second:play("overlay", long)
	second:update()
	assert(secondAnimator.loadedAnimations[3] ~= animation, "another build has another Animation")
	assert(
		secondAnimator.loadedAnimations[4].AnimationId == "rbxassetid://123456789012345",
		"got " .. secondAnimator.loadedAnimations[4].AnimationId
	)
end)

case("two layers with the same Roblox priority are accepted and nothing is done about it", function()
	local controller, animator = newController()
	controller:play("action", WAVE)
	controller:play("overlay", CHEER)
	controller:update()
	expectLog(
		animator,
		loadLog("t1", 201, false, "Action")
			.. ",t1.Play(nil,1,1),"
			.. loadLog("t2", 202, false, "Action")
			.. ",t2.Play(nil,1,1)"
	)
	controller:update()
	expectLog(animator, "")
end)

case("misuse raises at the call", function()
	local controller = newController()
	expectRaise(function()
		controller:play("legs", WALK)
	end, 'no layer "legs"')
	expectRaise(function()
		controller:play("base", WALK, 0 / 0)
	end, "speed must be a finite number")
	expectRaise(function()
		controller:setLayerWeight("base", -1)
	end, "weight must be a finite number, 0 or more")
	expectRaise(function()
		controller:stop("base", -1)
	end, "fadeTime must be")
	expectRaise(function()
		controller:setClipNormalizedTime("base", 1.5)
	end, "alpha must be a number from 0 to 1")
	expectRaise(function()
		controller:setClipTime("base", -1)
	end, "seconds must be")
	expectRaise(function()
		controller:setLayerTimeScale("base", math.huge)
	end, "rate must be a finite number")
	expectRaise(function()
		AnimLayers.controllers.layerController.new(FakeAnimatorFixture.new(1).engine :: any, { LAYERS[1], LAYERS[1] })
	end, 'layer "base" is defined twice')
end)

-- The largest heap growth, in KB, over `repeats` runs of `iterations` steps. Lune's
-- `collectgarbage("count")` is in whole KB. 500 steps that each made one table, closure or string of
-- 40 bytes would grow the heap by 20 KB. A collection that ran inside a run could hide that run's
-- growth, but not every run's: ten runs allocate 200 KB, less than the growth that starts one
-- collection, and the largest run is the one reported.
local function largestHeapGrowth(iterations: number, repeats: number, step: () -> ()): number
	for _ = 1, 64 do
		step()
	end
	local largest = 0
	for _ = 1, repeats do
		local before = collectgarbage("count")
		for _ = 1, iterations do
			step()
		end
		largest = math.max(largest, collectgarbage("count") - before)
	end
	return largest
end

case("update allocates nothing when nothing changed, nor when a speed changes on every update", function()
	local controller, animator = newController()
	controller:onMarker("Footstep", function() end)
	controller:onPlayCompleted(function() end)
	controller:play("base", WALK)
	controller:play("action", WAVE)
	controller:play("overlay", CHEER)
	controller:update()
	animator.logging = false

	local callsBefore = animator.callCount
	local quietGrowth = largestHeapGrowth(500, 10, function()
		controller:update()
	end)
	assert(animator.callCount == callsBefore, "a quiet update called the engine")
	assert(quietGrowth < 2, `5,000 quiet updates grew the heap by {quietGrowth} KB`)

	-- A speed beyond the tolerance on every step: one AdjustSpeed per update and nothing else.
	local speed = 1
	callsBefore = animator.callCount
	local changingGrowth = largestHeapGrowth(500, 10, function()
		speed = if speed > 2.5 then 1 else speed * 1.03
		controller:setClipSpeed("base", speed)
		controller:update()
	end)
	assert(animator.callCount - callsBefore == 64 + 5000, "each update made one engine call")
	assert(changingGrowth < 2, `5,000 updates with a changing speed grew the heap by {changingGrowth} KB`)
end)
