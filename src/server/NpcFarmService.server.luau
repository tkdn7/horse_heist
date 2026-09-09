--!strict
local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local Workspace=game:GetService("Workspace")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local HorseRarity=require(Shared:WaitForChild("HorseRarity"))
local ChaseConfig=require(Shared:WaitForChild("ChaseConfig"))
local Visual=require(ReplicatedStorage.HorseRun.FarmVisual)
local Traits=require(Shared.HorseTraits)
local Guards=require(script.Parent.GuardService)
local random=Random.new()
local SLOT_COUNT=6
local function folder(parent:Instance,name:string):Folder
	local found=parent:FindFirstChild(name)
	if found then assert(found:IsA("Folder")); return found end
	local made=Instance.new("Folder"); made.Name=name; made.Parent=parent; return made
end
local function signal(name:string,className:string):Instance
	local found=ServerScriptService:FindFirstChild(name)
	if found then return found end
	local made=Instance.new(className); made.Name=name; made.Parent=ServerScriptService; return made
end
local request=signal("NpcHorseChaseRequest","BindableFunction")::BindableFunction
local resolved=signal("NpcHorseChaseResolved","BindableEvent")::BindableEvent
local farms=folder(Workspace,"HorseFarms")
local npcFarm=farms:FindFirstChild("NpcFarm")
if not npcFarm then npcFarm=Instance.new("Folder"); npcFarm.Name="NpcFarm"; npcFarm.Parent=farms end
assert(npcFarm:IsA("Folder"))
npcFarm:SetAttribute("SlotCount",SLOT_COUNT)
npcFarm:SetAttribute("ManagedBy","NpcFarmService")
Visual.npc(npcFarm)
Guards.farmer(npcFarm)
local function position(index:number):CFrame return Visual.npcSlot(index) end
local function ensureSlot(index:number):Model
	local found=npcFarm:FindFirstChild("Slot"..index)
	if found and found:IsA("Model") then
        local pad=found:FindFirstChild("DisplayPad")
        if pad then pad.CFrame=position(index) end
        return found
    end
	local slot=Instance.new("Model"); slot.Name="Slot"..index; slot:SetAttribute("SlotIndex",index); slot.Parent=npcFarm
	local pad=Instance.new("Part"); pad.Name="DisplayPad"; pad.Anchored=true; pad.CanCollide=true
	pad.Size=Vector3.new(12,1,12); pad.CFrame=position(index); pad.Material=Enum.Material.Slate
	pad.Color=Color3.fromRGB(47,54,62); pad.Parent=slot
	local label=Instance.new("BillboardGui"); label.Name="RarityLabel"; label.Size=UDim2.fromOffset(190,54)
	label.StudsOffset=Vector3.new(0,9,0); label.MaxDistance=85; label.AlwaysOnTop=false; label.Adornee=pad; label.Parent=slot
	local text=Instance.new("TextLabel"); text.Name="Label"; text.Size=UDim2.fromScale(1,1)
	text.BackgroundTransparency=1; text.Font=Enum.Font.GothamBold; text.TextScaled=true
	text.TextStrokeTransparency=.35; text.Parent=label
	return slot
end
local function setLabel(slot:Model,value:string,color:Color3)
	local label=slot:FindFirstChild("RarityLabel")
	local text=label and label:FindFirstChildWhichIsA("TextLabel")
	if text then text.Text=value; text.TextColor3=color end
end
local function clearManaged(slot:Model)
	for _,name in {"DisplayHorse","RarityHighlight","RarityEffects"} do local item=slot:FindFirstChild(name); if item then item:Destroy() end end
	local pad=slot:FindFirstChild("DisplayPad")
	if pad then
		for _,name in {"RarityGlow","StealPrompt"} do local item=pad:FindFirstChild(name); if item then item:Destroy() end end
	end
end
local function connect(slot:Model,prompt:ProximityPrompt)
	prompt.Triggered:Connect(function(player)
		if slot:GetAttribute("Occupied")~=true or slot:GetAttribute("LockedBy") then return end
		slot:SetAttribute("LockedBy",player.UserId); prompt.Enabled=false
		local ok,accepted=pcall(function()
			return request:Invoke(player,{slot=slot,horseId=slot:GetAttribute("HorseId"),
				horseName=slot:GetAttribute("TemplateId"),rarityId=slot:GetAttribute("RarityId")})
		end)
		if not ok or accepted~=true then slot:SetAttribute("LockedBy",nil); prompt.Enabled=true end
	end)
end
local function addPrompt(slot:Model,rarity)
	local pad=slot:FindFirstChild("DisplayPad")
	if not pad or not pad:IsA("BasePart") then return end
	local old=pad:FindFirstChild("StealPrompt"); if old then old:Destroy() end
	local prompt=Instance.new("ProximityPrompt"); prompt.Name="StealPrompt"; prompt.ActionText="훔치기"
	prompt.ObjectText=rarity.DisplayName.." 말 · 2초간 눌러 훔치기"; prompt.HoldDuration=ChaseConfig.StealHoldSeconds
	prompt.MaxActivationDistance=10; prompt.RequiresLineOfSight=false
	prompt.Enabled=slot:GetAttribute("Occupied")==true; prompt.Parent=pad; connect(slot,prompt)
end
local function populate(slot:Model)
	clearManaged(slot)
	local index=slot:GetAttribute("SlotIndex") or tonumber(slot.Name:match("%d+")) or 1
	local rarity=HorseRarity.choose(random); local templateName="Horse"..(((index-1)%3)+1)
	slot:SetAttribute("Occupied",true); slot:SetAttribute("LockedBy",nil)
	slot:SetAttribute("HorseId",HttpService:GenerateGUID(false)); slot:SetAttribute("TemplateId",templateName)
	slot:SetAttribute("RarityId",rarity.Id); slot:SetAttribute("StealHoldSeconds",rarity.StealHoldSeconds)
	local traits=Traits.roll(rarity.Id,random)
	slot:SetAttribute('Speed',traits.Speed);slot:SetAttribute('Stamina',traits.Stamina);slot:SetAttribute('Ability',traits.Ability)
	slot:SetAttribute("EscapeSeconds",rarity.EscapeSeconds)
	slot:SetAttribute("MinimumObstacleGapSeconds",rarity.MinimumObstacleGapSeconds)
	setLabel(slot,rarity.DisplayName..' · 속도 '..traits.Speed..' / 체력 '..traits.Stamina..'\n능력: '..Traits.AbilityNames[traits.Ability],rarity.Color)
	local pad=slot:FindFirstChild("DisplayPad")
	if pad and pad:IsA("BasePart") then
		local horse=Visual.display(slot,"DisplayHorse",templateName,pad.CFrame)
        horse:SetAttribute("TemplateId",templateName);horse:SetAttribute("RarityId",rarity.Id)
        Visual.rarity(slot,horse,pad,rarity)
	end
	addPrompt(slot,rarity)
end
local function reconnect(slot:Model)
	local rarity=HorseRarity.get(slot:GetAttribute("RarityId"))
	slot:SetAttribute("Occupied",slot:GetAttribute("Occupied")~=false); slot:SetAttribute("LockedBy",nil)
	slot:SetAttribute("HorseId",slot:GetAttribute("HorseId") or HttpService:GenerateGUID(false))
	local horse=slot:FindFirstChild("DisplayHorse")
	slot:SetAttribute("TemplateId",slot:GetAttribute("TemplateId") or (horse and horse:GetAttribute("TemplateId")) or "Horse1")
	slot:SetAttribute("StealHoldSeconds",rarity.StealHoldSeconds)
	slot:SetAttribute("EscapeSeconds",rarity.EscapeSeconds)
	slot:SetAttribute("MinimumObstacleGapSeconds",rarity.MinimumObstacleGapSeconds)
	if horse then horse:Destroy() end
    local pad=slot:FindFirstChild("DisplayPad")
    local display=Visual.display(slot,"DisplayHorse",slot:GetAttribute("TemplateId"),pad.CFrame)
    Visual.rarity(slot,display,pad,rarity)
    local label=slot:FindFirstChild("RarityLabel")
    if label then label.StudsOffset=Vector3.new(0,9,0);label.MaxDistance=85;label.AlwaysOnTop=false end
    local oldHighlight=slot:FindFirstChild("RarityHighlight");if oldHighlight then oldHighlight:Destroy() end
    local oldGlow=pad:FindFirstChild("RarityGlow");if oldGlow then oldGlow:Destroy() end
    setLabel(slot,rarity.DisplayName,rarity.Color); addPrompt(slot,rarity)
end
-- Each server rolls its own NPC stock; player-owned collections are separate.
for i=1,SLOT_COUNT do populate(ensureSlot(i)) end
resolved.Event:Connect(function(slot,success)
	if typeof(slot)~="Instance" or not slot:IsDescendantOf(npcFarm) then return end
	slot:SetAttribute("LockedBy",nil); local prompt=slot:FindFirstChild("StealPrompt",true)
	if success then
		slot:SetAttribute("Occupied",false); if prompt then prompt.Enabled=false end
		local horse=slot:FindFirstChild("DisplayHorse"); if horse then horse:Destroy() end
        local effects=slot:FindFirstChild("RarityEffects");if effects then effects:Destroy() end
		setLabel(slot,"60초 후 보충",Color3.fromRGB(220,220,220))
		task.delay(ChaseConfig.SlotRefillSeconds,function()
			if slot.Parent and slot:GetAttribute("Occupied")==false then populate(slot) end
		end)
	elseif prompt then prompt.Enabled=true end
end)
Players.PlayerRemoving:Connect(function(player)
	for _,slot in npcFarm:GetChildren() do
		if slot:IsA("Model") and slot:GetAttribute("LockedBy")==player.UserId then
			slot:SetAttribute("LockedBy",nil); local prompt=slot:FindFirstChild("StealPrompt",true)
			if prompt then prompt.Enabled=true end
		end
	end
end)
print("[NpcFarmService] Six stealable NPC horse slots ready")
