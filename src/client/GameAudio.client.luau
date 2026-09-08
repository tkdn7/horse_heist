local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local GuardConfig=require(ReplicatedStorage.Shared.GuardConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFINITIONS = {
    FarmerAngry = {id=GuardConfig.AngrySound,volume=GuardConfig.VoiceVolume},
	Click = {id = "rbxassetid://88442833509532", volume = 0.28},
	Footsteps = {id = "rbxassetid://18438190442", volume = 0.3, looped = true},
	Gallop = {id = "rbxassetid://118636555040923", volume = 0.2, looped = true},
	Jump = {id = "rbxassetid://132163823091536", volume = 0.38},
	Land = {id = "rbxassetid://9119321317", volume = 0.28},
	Slide = {id = "rbxassetid://9114658416", volume = 0.42},
	Hit = {id = "rbxassetid://9120888980", volume = 0.52},
	Pickup = {id = "rbxassetid://93529351909119", volume = 0.36},
	Success = {id = "rbxassetid://103516326607012", volume = 0.42},
}

local oldFolder = SoundService:FindFirstChild("GameAudio")
if oldFolder then oldFolder:Destroy() end

local folder = Instance.new("Folder")
folder.Name = "GameAudio"
folder.Parent = SoundService

local sounds = {}
for name, definition in DEFINITIONS do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = definition.id
	sound.Volume = definition.volume
	sound.Looped = definition.looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = folder
	sounds[name] = sound
end

local function markPlayed(name)
	folder:SetAttribute("LastSound", name)
	folder:SetAttribute("LastPlayedAt", os.clock())
end

local function play(name, playbackSpeed)
	local sound = sounds[name]
	if not sound then return end
	sound.PlaybackSpeed = playbackSpeed or 1
	sound.TimePosition = 0
	sound:Play()
	markPlayed(name)
end

local loopTweens = {}
local function setLoop(name, enabled, playbackSpeed)
	local sound = sounds[name]
	local definition = DEFINITIONS[name]
	if not sound or not definition then return end
	if loopTweens[name] then loopTweens[name]:Cancel() end
	sound.PlaybackSpeed = playbackSpeed or sound.PlaybackSpeed
	if enabled then
		if not sound.Playing then
			sound.Volume = 0
			sound:Play()
			markPlayed(name)
		end
		loopTweens[name] = TweenService:Create(sound, TweenInfo.new(0.12), {Volume = definition.volume})
	else
		loopTweens[name] = TweenService:Create(sound, TweenInfo.new(0.12), {Volume = 0})
		loopTweens[name].Completed:Once(function()
			if sound.Volume <= 0.01 then sound:Stop() end
		end)
	end
	loopTweens[name]:Play()
end

local horseGui
local phase = "Lobby"
local lastMotion = "Idle"
local farmerChase=false
local lastAngry=-10

local function updatePhase()
	phase = horseGui and horseGui:GetAttribute("Phase") or "Lobby"
	setLoop("Gallop", phase == "Running", 1)
	if phase ~= "Lobby" then setLoop("Footsteps", false) end
end

local function updateMotion()
	if not horseGui then return end
	local motion = horseGui:GetAttribute("MotionState") or "Idle"
	if motion == lastMotion then return end
	if motion == "Jump" then
		play("Jump", 1.03)
	elseif motion == "Land" then
		play("Land", 0.9)
	elseif motion == "Slide" then
		play("Slide", 1)
	end
	lastMotion = motion
end

local function hookHorseGui(gui)
	if horseGui == gui then return end
	horseGui = gui
	phase = gui:GetAttribute("Phase") or "Lobby"
	lastMotion = gui:GetAttribute("MotionState") or "Idle"
	gui:GetAttributeChangedSignal("Phase"):Connect(updatePhase)
	gui:GetAttributeChangedSignal("MotionState"):Connect(updateMotion)
	updatePhase()
end

local hookedButtons = setmetatable({}, {__mode = "k"})
local function hookButton(instance)
	if not instance:IsA("TextButton") or hookedButtons[instance] then return end
	hookedButtons[instance] = true
	instance.Activated:Connect(function()
		play("Click", 0.98 + math.random() * 0.04)
	end)
end

for _, descendant in playerGui:GetDescendants() do hookButton(descendant) end
playerGui.DescendantAdded:Connect(hookButton)

local function hookCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.Running:Connect(function(speed)
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local shouldPlay = phase == "Lobby" and speed > 1.5 and grounded
		setLoop("Footsteps", shouldPlay, math.clamp(speed / 12, 0.75, 1.45))
	end)
	humanoid.StateChanged:Connect(function(_, newState)
		if phase ~= "Lobby" then return end
		if newState == Enum.HumanoidStateType.Jumping then
			setLoop("Footsteps", false)
			play("Jump", 1.08)
		elseif newState == Enum.HumanoidStateType.Landed then
			play("Land", 1)
		end
	end)
end

if player.Character then task.spawn(hookCharacter, player.Character) end
player.CharacterAdded:Connect(hookCharacter)

local existingGui = playerGui:FindFirstChild("HorseRunUI")
if existingGui then hookHorseGui(existingGui) end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "HorseRunUI" then hookHorseGui(child) end
end)

local horseRun = ReplicatedStorage:WaitForChild("HorseRun", 10)
local remote = horseRun and horseRun:FindFirstChild("Event")
if remote then
	remote.OnClientEvent:Connect(function(kind, data)
		if kind=='Start' then farmerChase=data.chase==true and data.pvpRole~='Owner';lastAngry=-10 end
		if kind == "Effect" and data then
			if data.kind == "Carrot" then play("Pickup", 1.04)
			elseif data.kind == "Hit" then play("Hit", 0.94) end
		elseif kind == "Result" then
			sounds.FarmerAngry:Stop();farmerChase=false
			setLoop("Gallop", false)
			if data and data.chase and not data.success then play("Hit", 0.8) else play("Success", 1) end
		elseif kind == "Lobby" then
			sounds.FarmerAngry:Stop();farmerChase=false
			setLoop("Gallop", false)
		end
	end)
end

task.spawn(function()
    while folder.Parent do
        if farmerChase and phase=='Running' and os.clock()-lastAngry>=GuardConfig.VoiceInterval then
            play('FarmerAngry',.94+math.random()*.1);lastAngry=os.clock()
        end
        task.wait(.25)
    end
end)

task.spawn(function()
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(folder:GetChildren())
	end)
	folder:SetAttribute("Ready", ok)
	if not ok then folder:SetAttribute("LoadError", tostring(err)) end
end)

folder:SetAttribute("Installed", true)
print("[GameAudio] Basic character and HorseRun sounds ready")

