--!strict
--!optimize 2
-- The dev place's client: an R6 dummy, one layerController over its Animator, and a panel of buttons
-- that call every command. docs/guides/studio-verification.md lists what to check with it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers/shared")

type ClipDefinition = AnimLayers.ClipDefinition
type LayerControllerOwned = AnimLayers.LayerControllerOwned
type LayerDefinition = AnimLayers.LayerDefinition

type ButtonSpec = { text: string, run: () -> () }

local DEV_ROOT_NAME = "AnimLayersDev"
local GUI_NAME = "AnimLayersDevPanel"
local DUMMY_PIVOT = CFrame.new(0, 1000, 0) * CFrame.Angles(0, math.pi, 0)
local MARKER_NAME = "Footstep"
local STATUS_INTERVAL = 0.2
-- The controller keeps 64 tracks; this many definitions loads more than that on one Animator.
local OVER_CAP_COUNT = 70
local OVER_CAP_INTERVAL = 0.5
-- The status box lists this many tracks and counts the rest.
local STATUS_TRACKS = 6
local LOG_LINES = 14

-- Roblox's own R6 animations. None of them has a marker named MARKER_NAME: publish a clip with one
-- and add its id here to see `onMarker`.
local CLIPS: { [string]: ClipDefinition } = {
	idle = AnimLayers.utils.clipDefinition.build(180435571, true),
	walk = AnimLayers.utils.clipDefinition.build(180426354, true),
	wave = AnimLayers.utils.clipDefinition.build(128777973, false),
	cheer = AnimLayers.utils.clipDefinition.build(129423030, false),
	jump = AnimLayers.utils.clipDefinition.build(125750702, false),
}

-- `overlay` shares `action`'s priority on purpose: Roblox blends the two by weight.
local LAYER_DEFINITIONS: { LayerDefinition } = {
	{ name = "base", robloxPriority = Enum.AnimationPriority.Movement, fadeIn = 0.2, fadeOut = 0.2 },
	{ name = "action", robloxPriority = Enum.AnimationPriority.Action, fadeIn = 0.1, fadeOut = 0.15 },
	{ name = "overlay", robloxPriority = Enum.AnimationPriority.Action },
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldRoot = Workspace:FindFirstChild(DEV_ROOT_NAME)
if oldRoot ~= nil then
	oldRoot:Destroy()
end
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui ~= nil then
	oldGui:Destroy()
end

local devRoot = Instance.new("Folder")
devRoot.Name = DEV_ROOT_NAME
devRoot.Parent = Workspace

local function createDummy(): (Model, Animator)
	local description = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	description:Destroy()
	model.Name = "AnimLayersR6Dummy"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid ~= nil, "the dummy has no Humanoid")
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local existingAnimator = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator
	if existingAnimator ~= nil then
		animator = existingAnimator
	else
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	assert(rootPart ~= nil and rootPart:IsA("BasePart"), "the dummy has no HumanoidRootPart")
	model.PrimaryPart = rootPart
	-- The Animator is in Workspace before any track is loaded.
	model.Parent = devRoot
	model:PivotTo(DUMMY_PIVOT)
	rootPart.Anchored = true
	return model, animator
end

local dummy, animator = createDummy()

local camera = Workspace.CurrentCamera
if camera ~= nil then
	local target = dummy:GetPivot().Position + Vector3.new(0, 1.8, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 1.2, 11), target + Vector3.new(-3.5, 0, 0))
end

-- The panel: a column of buttons, a status line and a log.
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.Parent = playerGui

local buttonColumn = Instance.new("ScrollingFrame")
buttonColumn.Size = UDim2.new(0, 260, 1, -20)
buttonColumn.Position = UDim2.fromOffset(10, 10)
buttonColumn.BackgroundTransparency = 0.3
buttonColumn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
buttonColumn.AutomaticCanvasSize = Enum.AutomaticSize.Y
buttonColumn.CanvasSize = UDim2.new()
buttonColumn.ScrollBarThickness = 6
buttonColumn.Parent = gui
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 4)
buttonLayout.Parent = buttonColumn

local function newLabel(position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = gui
	return label
end

local statusLabel = newLabel(UDim2.fromOffset(280, 10), UDim2.new(0, 420, 0, 150))
local logLabel = newLabel(UDim2.new(0, 280, 1, -260), UDim2.new(0, 520, 0, 250))

local logLines: { string } = {}
local function log(text: string): ()
	table.insert(logLines, string.format("%7.2f  %s", os.clock() % 1000, text))
	if #logLines > LOG_LINES then
		table.remove(logLines, 1)
	end
	logLabel.Text = table.concat(logLines, "\n")
end

local function addHeading(text: string): ()
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, -8, 0, 22)
	heading.BackgroundTransparency = 1
	heading.TextColor3 = Color3.fromRGB(255, 210, 120)
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 14
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = text
	heading.Parent = buttonColumn
end

local function addButtons(heading: string, buttons: { ButtonSpec }): ()
	addHeading(heading)
	for _, spec in buttons do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -8, 0, 26)
		button.BackgroundColor3 = Color3.fromRGB(52, 58, 70)
		button.TextColor3 = Color3.fromRGB(240, 240, 240)
		button.Font = Enum.Font.Gotham
		button.TextSize = 13
		button.Text = spec.text
		button.Parent = buttonColumn
		button.Activated:Connect(function()
			local ok, failure = pcall(spec.run)
			if not ok then
				log("ERROR " .. tostring(failure))
			end
		end)
	end
end

local controller: LayerControllerOwned = AnimLayers.controllers.layerController.new(animator, LAYER_DEFINITIONS)
local commandedSpeed = 1

local function subscribe(target: LayerControllerOwned): ()
	target:onPlayCompleted(function(layer, playId)
		log(`completed  layer={layer} play={playId}`)
	end)
	target:onMarker(MARKER_NAME, function(layer, playId, clip, value)
		log(`marker {MARKER_NAME}  layer={layer} play={playId} asset={clip.assetId} value="{value}"`)
	end)
end
subscribe(controller)

local function play(layer: string, clipName: string, speed: number?, fadeTime: number?): ()
	local playId = controller:play(layer, CLIPS[clipName], speed, fadeTime)
	log(`play  layer={layer} clip={clipName} -> play={playId}`)
end

local function setBaseSpeed(speed: number): ()
	commandedSpeed = speed
	local inEffect = controller:setClipSpeed("base", speed)
	log(`setClipSpeed base {speed} -> {if inEffect ~= nil then tostring(inEffect) else "no play"}`)
end

addButtons("Base layer (looping)", {
	{
		text = "play idle",
		run = function()
			play("base", "idle")
		end,
	},
	{
		text = "play walk",
		run = function()
			play("base", "walk")
		end,
	},
	{
		text = "play walk again (restarts)",
		run = function()
			play("base", "walk", commandedSpeed)
		end,
	},
	{
		text = "stop base, fade 0.5",
		run = function()
			controller:stop("base", 0.5)
			log("stop base 0.5")
		end,
	},
})

addButtons("Speed of the base play", {
	{
		text = "speed 1",
		run = function()
			setBaseSpeed(1)
		end,
	},
	{
		text = "speed 2",
		run = function()
			setBaseSpeed(2)
		end,
	},
	{
		text = "speed 0 (pause)",
		run = function()
			setBaseSpeed(0)
		end,
	},
	{
		text = "speed -1 (reverse)",
		run = function()
			setBaseSpeed(-1)
		end,
	},
	{
		text = "speed +0.5% (inside the tolerance)",
		run = function()
			setBaseSpeed(commandedSpeed * 1.005)
		end,
	},
})

addButtons("Layer time scale and weight", {
	{
		text = "base time scale 0",
		run = function()
			controller:setLayerTimeScale("base", 0)
			log("setLayerTimeScale base 0")
		end,
	},
	{
		text = "base time scale 0.5",
		run = function()
			controller:setLayerTimeScale("base", 0.5)
			log("setLayerTimeScale base 0.5")
		end,
	},
	{
		text = "base time scale 1",
		run = function()
			controller:setLayerTimeScale("base", 1)
			log("setLayerTimeScale base 1")
		end,
	},
	{
		text = "base weight 0.3 over 1 s",
		run = function()
			controller:setLayerWeight("base", 0.3, 1)
			log("setLayerWeight base 0.3 fade 1")
		end,
	},
	{
		text = "base weight 1 (engine's fade)",
		run = function()
			controller:setLayerWeight("base", 1)
			log("setLayerWeight base 1")
		end,
	},
	-- The weight is the layer's: set with nothing playing on action, it is what the next clip there
	-- starts at.
	{
		text = "action weight 0.4 (for its next plays too)",
		run = function()
			controller:setLayerWeight("action", 0.4)
			log("setLayerWeight action 0.4")
		end,
	},
	{
		text = "action weight 1",
		run = function()
			controller:setLayerWeight("action", 1)
			log("setLayerWeight action 1")
		end,
	},
})

addButtons("Action layer (plays once)", {
	{
		text = "play wave",
		run = function()
			play("action", "wave")
		end,
	},
	{
		text = "play cheer, fade 0.4",
		run = function()
			play("action", "cheer", 1, 0.4)
		end,
	},
	{
		text = "wave, then cheer in the same frame",
		run = function()
			play("action", "wave")
			play("action", "cheer")
		end,
	},
	{
		text = "stop then play wave (stop's fade 1)",
		run = function()
			controller:stop("action", 1)
			play("action", "wave")
		end,
	},
	{
		text = "stop action",
		run = function()
			controller:stop("action")
			log("stop action")
		end,
	},
})

addButtons("Position", {
	{
		text = "wave from 50%",
		run = function()
			play("action", "wave")
			controller:setClipNormalizedTime("action", 0.5)
		end,
	},
	{
		text = "wave backwards from its end",
		run = function()
			play("action", "wave", -1)
			controller:setClipNormalizedTime("action", 1)
		end,
	},
	{
		text = "jump placed on its end (completes)",
		run = function()
			play("action", "jump")
			controller:setClipNormalizedTime("action", 1)
		end,
	},
	{
		text = "base to 0.2 s",
		run = function()
			controller:setClipTime("base", 0.2)
			log("setClipTime base 0.2")
		end,
	},
})

addButtons("Equal priority", {
	{
		text = "overlay: cheer at weight 1",
		run = function()
			play("overlay", "cheer")
		end,
	},
	{
		text = "stop overlay",
		run = function()
			controller:stop("overlay")
			log("stop overlay")
		end,
	},
})

-- More definitions than the controller keeps tracks for. Each build is its own definition, so each
-- loads its own track, even though all of them are the walk.
local overCapClips: { ClipDefinition } = {}
local overCapNext = 0
local sinceOverCapPlay = 0

local function getOverCapClip(index: number): ClipDefinition
	local clip = overCapClips[index]
	if clip == nil then
		clip = AnimLayers.utils.clipDefinition.build(180426354, true)
		overCapClips[index] = clip
	end
	return clip
end

addButtons("Tracks and lifecycle", {
	{
		text = `{OVER_CAP_COUNT} definitions on action, one per {OVER_CAP_INTERVAL} s`,
		run = function()
			overCapNext = 1
			sinceOverCapPlay = OVER_CAP_INTERVAL
			log(`loading {OVER_CAP_COUNT} definitions, spaced`)
		end,
	},
	{
		text = `{OVER_CAP_COUNT} definitions on action, in one frame`,
		run = function()
			for index = 1, OVER_CAP_COUNT do
				controller:play("action", getOverCapClip(index))
				controller:update()
			end
			log(`loaded {OVER_CAP_COUNT} definitions in one frame`)
		end,
	},
	{
		text = "cycle every clip on action (loads tracks)",
		run = function()
			for clipName in CLIPS do
				play("action", clipName)
				controller:update()
			end
		end,
	},
	{
		text = "clear",
		run = function()
			controller:clear()
			log("clear")
		end,
	},
	{
		text = "deconstruct and build again",
		run = function()
			controller:deconstruct()
			controller = AnimLayers.controllers.layerController.new(animator, LAYER_DEFINITIONS)
			subscribe(controller)
			log("deconstruct, new")
		end,
	},
})

-- The engine's own view, for comparing with what was commanded.
animator.AnimationPlayed:Connect(function(track)
	log(`engine AnimationPlayed  {track.Animation and track.Animation.AnimationId} priority={track.Priority.Name}`)
end)

local sinceStatus = 0
RunService.PreAnimation:Connect(function(deltaTime: number)
	if overCapNext > 0 then
		sinceOverCapPlay += deltaTime
		if sinceOverCapPlay >= OVER_CAP_INTERVAL then
			sinceOverCapPlay = 0
			controller:play("action", getOverCapClip(overCapNext))
			overCapNext = if overCapNext < OVER_CAP_COUNT then overCapNext + 1 else 0
			if overCapNext == 0 then
				log(`loaded {OVER_CAP_COUNT} definitions, spaced`)
			end
		end
	end
	controller:update()
	sinceStatus += deltaTime
	if sinceStatus < STATUS_INTERVAL then
		return
	end
	sinceStatus = 0
	local playingTracks = animator:GetPlayingAnimationTracks()
	local lines: { string } = { `engine: {#playingTracks} track(s) playing or fading out` }
	for index, track in playingTracks do
		if index > STATUS_TRACKS then
			break
		end
		table.insert(
			lines,
			string.format(
				"  %-28s %-9s w=%.2f->%.2f speed=%.2f t=%.2f/%.2f",
				if track.Animation ~= nil then track.Animation.AnimationId else "?",
				track.Priority.Name,
				track.WeightCurrent,
				track.WeightTarget,
				track.Speed,
				track.TimePosition,
				track.Length
			)
		)
	end
	statusLabel.Text = table.concat(lines, "\n")
end)

log("ready: the controller is updated on RunService.PreAnimation")
