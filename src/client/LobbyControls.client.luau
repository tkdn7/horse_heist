--!strict

-- Roblox normally installs PlayerModule for character and camera controls.
-- Some Studio sessions omit it. This fallback is active only in that case and
-- only while the player is walking around the lobby.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")

-- Give CoreScripts time to install PlayerModule. A normal installation always
-- wins so this file cannot compete with Roblox's built-in controls.
task.wait(2)
if playerScripts:FindFirstChild("PlayerModule") then
	return
end

local ACTION_MOVE = "HorseFarmFallbackMove"
local ACTION_JUMP = "HorseFarmFallbackJump"
local CAMERA_STEP = "HorseFarmFallbackCamera"
local MOUSE_SENSITIVITY = 0.003
local MIN_PITCH = math.rad(-75)
local MAX_PITCH = math.rad(70)
local MIN_ZOOM = 6
local MAX_ZOOM = 35

local held = {
	Forward = false,
	Backward = false,
	Left = false,
	Right = false,
}

local rotating = false
local zoom = 16
local yaw = 0
local pitch = math.rad(-18)
local wasActive = false
local lastJumpAt = -math.huge
local jumpReady = true

local function getCharacterParts(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid, root
	end

	return nil, nil
end

local function isLobby(): boolean
	-- HorseRunClient creates this local folder before taking over runner input.
	return Workspace:FindFirstChild("LocalHorseTrack") == nil
end

local function releaseMouse()
	rotating = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function setHeld(input: InputObject, value: boolean)
	local key = input.KeyCode
	if key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
		held.Forward = value
	elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
		held.Backward = value
	elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
		held.Left = value
	elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
		held.Right = value
	end
end

local function onMove(_actionName: string, inputState: Enum.UserInputState, input: InputObject)
	if UserInputService:GetFocusedTextBox() or not isLobby() then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		setHeld(input, true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setHeld(input, false)
	end

	return Enum.ContextActionResult.Sink
end

local function onJump(_actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or not isLobby() then
		return Enum.ContextActionResult.Pass
	end

	local humanoid = getCharacterParts()
	if humanoid then
		local now = os.clock()
		local humanoidState = humanoid:GetState()
		-- A jump is only valid from the ground. The previous fallback called
		-- ChangeState on every Space press, which allowed repeated mid-air jumps.
		if not jumpReady
			or humanoid.FloorMaterial == Enum.Material.Air
			or humanoidState == Enum.HumanoidStateType.Jumping
			or humanoidState == Enum.HumanoidStateType.Freefall
			or now - lastJumpAt < 0.2 then
			return Enum.ContextActionResult.Sink
		end
		-- Studio can have another ContextAction binding (for example Freecam)
		-- consuming Space before the fallback receives it. Explicitly enable the
		-- state and request the transition so the default character can jump.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.Jump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		lastJumpAt = now
		jumpReady = false
	end
	return Enum.ContextActionResult.Sink
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not isLobby() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UserInputService.MouseIconEnabled = false
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		releaseMouse()
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not isLobby() then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
		yaw += input.Delta.X * MOUSE_SENSITIVITY
		pitch = math.clamp(pitch - input.Delta.Y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom - input.Position.Z * 2, MIN_ZOOM, MAX_ZOOM)
	end
end)

ContextActionService:BindActionAtPriority(
	ACTION_MOVE,
	onMove,
	false,
	Enum.ContextActionPriority.Default.Value,
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right
)
ContextActionService:BindActionAtPriority(
	ACTION_JUMP,
	onJump,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.Space,
	Enum.KeyCode.Up,
	Enum.KeyCode.ButtonA
)

RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, function()
	local humanoid, root = getCharacterParts()
	local active = isLobby() and humanoid ~= nil and root ~= nil and humanoid.Health > 0
	if not active or not humanoid or not root then
		if wasActive then
			humanoid = humanoid :: Humanoid?
			if humanoid then
				humanoid:Move(Vector3.zero, false)
			end
			releaseMouse()
		end
		wasActive = false
		return
	end

	wasActive = true
	local humanoidState = humanoid:GetState()
	if humanoid.FloorMaterial ~= Enum.Material.Air
		and humanoidState ~= Enum.HumanoidStateType.Jumping
		and humanoidState ~= Enum.HumanoidStateType.Freefall then
		jumpReady = true
	end
	local move = Vector3.new(
		(held.Right and 1 or 0) - (held.Left and 1 or 0),
		0,
		(held.Backward and 1 or 0) - (held.Forward and 1 or 0)
	)
	if move.Magnitude > 1 then
		move = move.Unit
	end
	humanoid:Move(move, true)

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local target = root.Position + Vector3.new(0, 2.5, 0)
	local look = Vector3.new(
		math.sin(yaw) * math.cos(pitch),
		math.sin(pitch),
		-math.cos(yaw) * math.cos(pitch)
	)
	local desiredPosition = target - look * zoom

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character :: Model }
	local hit = Workspace:Raycast(target, desiredPosition - target, raycastParams)
	local cameraPosition = hit and (hit.Position + hit.Normal * 0.5) or desiredPosition

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = humanoid
	camera.CFrame = CFrame.lookAt(cameraPosition, target)
end)

print("[LobbyControls] PlayerModule missing; PC lobby movement and mouse camera fallback enabled.")
