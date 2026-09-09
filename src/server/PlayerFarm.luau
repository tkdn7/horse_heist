--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local PlayerFarm={}
local indices:{[Player]:number}={}
local Visual=require(ReplicatedStorage.HorseRun.FarmVisual)
local Rarity=require(ReplicatedStorage.Shared.HorseRarity)
local Guards=require(script.Parent.GuardService)
local Placement=require(script.Parent.CharacterPlacement)
local CollectionService=game:GetService('CollectionService')
local ChaseConfig=require(ReplicatedStorage.Shared.ChaseConfig)
local stealHandler:((Player,Player,string,BasePart)->boolean)?=nil
function PlayerFarm.setStealHandler(handler:(Player,Player,string,BasePart)->boolean)
	stealHandler=handler
end
local function baseFor(player:Player):CFrame
    if not indices[player] then
        local occupied={};for _,index in indices do occupied[index]=true end
        local index=1;while occupied[index] do index+=1 end
        indices[player]=index
    end
    return Visual.playerBase(indices[player])
end
function PlayerFarm.home(player:Player,character:Model?):CFrame
    local base=baseFor(player)
    local point=base:PointToWorldSpace(Vector3.new(0,0,43))
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    local excluded={}
    for _,other in game:GetService('Players'):GetPlayers() do
        if other.Character then table.insert(excluded,other.Character) end
    end
    local spawns=Workspace:FindFirstChild('FarmSpawns');if spawns then table.insert(excluded,spawns) end
    params.FilterDescendantsInstances=excluded;params.RespectCanCollide=true
    local hit=Workspace:Raycast(point+Vector3.new(0,20,0),Vector3.new(0,-50,0),params)
    local ground=hit and hit.Position.Y or point.Y+.365
    return CFrame.new(point.X,Placement.groundRootY(character,ground),point.Z)*base.Rotation
end
function PlayerFarm.prepareSpawn(player:Player)
    local folder=Workspace:FindFirstChild('FarmSpawns')
    if not folder then folder=Instance.new('Folder');folder.Name='FarmSpawns';folder.Parent=Workspace end
    local name='Home_'..player.UserId
    local spawn=folder:FindFirstChild(name)
    if not spawn then
        spawn=Instance.new('SpawnLocation');spawn.Name=name
        spawn.Size=Vector3.new(6,1,6);spawn.Anchored=true;spawn.Transparency=1
        spawn.CanCollide=false;spawn.CanTouch=false;spawn.CanQuery=false
        spawn.Neutral=true;spawn.Duration=0;spawn.Parent=folder
    end
    spawn.CFrame=PlayerFarm.home(player)*CFrame.new(0,-3,0)
    player.RespawnLocation=spawn
end
local function container():Folder
	local farms=Workspace:FindFirstChild("HorseFarms") or Instance.new("Folder")
	farms.Name="HorseFarms"; farms.Parent=Workspace
	local result=farms:FindFirstChild("PlayerFarms") or Instance.new("Folder")
	result.Name="PlayerFarms"; result.Parent=farms
	return result::Folder
end
local function updatePrompt(pad,prompt,locked)
    pad:SetAttribute('FarmTheftProtected',locked)
    prompt.Enabled=not locked and pad:GetAttribute('StealProtected')~=true and prompt:GetAttribute('Busy')~=true
    prompt.ActionText=locked and '추격 중 · 보호됨' or '훔치기'
    local tag=pad:FindFirstChildWhichIsA('BillboardGui')
    local label=tag and tag:FindFirstChildWhichIsA('TextLabel')
    if label then
        label.Text=Rarity.get(pad:GetAttribute('RarityId')).DisplayName..((locked or pad:GetAttribute('StealProtected')) and '  🔒' or '')
    end
end
function PlayerFarm.protectForTheft(player,eventId)
    local current=player:GetAttribute('FarmTheftEvent')
    if eventId and current and current~=eventId then return false end
    player:SetAttribute('FarmTheftEvent',eventId)
    local farm=container():FindFirstChild('Farm_'..player.UserId)
    if farm then
        farm:SetAttribute('FarmTheftProtected',eventId~=nil)
        for _,prompt in farm:GetDescendants() do
            if prompt:IsA('ProximityPrompt') and prompt.Name=='PlayerStealPrompt' then updatePrompt(prompt.Parent,prompt,eventId~=nil) end
        end
    end
    return true
end
function PlayerFarm.releaseTheftProtection(player,eventId)
    if player:GetAttribute('FarmTheftEvent')==eventId then PlayerFarm.protectForTheft(player,nil) end
end
function PlayerFarm.render(player:Player,data)
	local parent=container(); local name="Farm_"..player.UserId
	local farm=parent:FindFirstChild(name)
    local base=baseFor(player)
    if not farm then
        farm=Instance.new("Model");farm.Name=name;farm:SetAttribute("OwnerUserId",player.UserId);farm.Parent=parent
        Visual.player(farm,base,player.DisplayName)
    end
    Visual.alignPlayer(farm,base)
    farm:SetAttribute('FarmTheftProtected',player:GetAttribute('FarmTheftEvent')~=nil)
    local displays=farm:FindFirstChild('Displays')
    if not displays then displays=Instance.new('Folder');displays.Name='Displays';displays.Parent=farm end
    local placed={}
	for _,horse in data.Horses do if horse.Placed and #placed<12 then table.insert(placed,horse) end end
	local templates=ReplicatedStorage:WaitForChild("HorseRun"):WaitForChild("Horses")
    for index=1,12 do
        local cf=Visual.slot(base,index)
        local horse=placed[index]
        local key=horse and table.concat({horse.Id,horse.TemplateId,horse.RarityId,tostring(horse.ProtectedUntil),tostring(data.ProtectedHorseId==horse.Id)},'|') or 'Empty'
        local previous=displays:FindFirstChild('Stall'..index)
        if previous and previous:GetAttribute('HorseRenderKey')==key then
            local pad=previous:FindFirstChild('Slot'..index)
            local prompt=pad and pad:FindFirstChild('PlayerStealPrompt')
            if prompt then updatePrompt(pad,prompt,player:GetAttribute('FarmTheftEvent')~=nil) end
            continue
        end
        -- Only the changed stall is rebuilt; the other horses keep their instances.
        if previous then previous:Destroy() end
        local display=Instance.new("Folder",displays);display.Name="Stall"..index
        display:SetAttribute('HorseRenderKey',key)
		local pad=Instance.new("Part"); pad.Name="Slot"..index; pad.Anchored=true; pad.Size=Vector3.new(11,1,11)
		pad.CFrame=cf; pad.Material=Enum.Material.Grass; pad.Color=Color3.fromRGB(91,135,78); pad.Parent=display
		if horse then
			pad:SetAttribute("HorseId",horse.Id); pad:SetAttribute("RarityId",horse.RarityId)
			local rarity=Rarity.get(horse.RarityId)
            local model=Visual.display(display,"Horse_"..horse.Id,horse.TemplateId,cf)
            Visual.rarity(display,model,pad,rarity)
			local tag=Instance.new("BillboardGui"); tag.Size=UDim2.fromOffset(180,42); tag.StudsOffset=Vector3.new(0,9,0); tag.MaxDistance=70; tag.AlwaysOnTop=false; tag.Adornee=pad; tag.Parent=pad
			local text=Instance.new("TextLabel"); text.Size=UDim2.fromScale(1,1); text.BackgroundTransparency=1; text.TextScaled=true; text.Font=Enum.Font.GothamBold
			local selectedProtection=data.ProtectedHorseId==horse.Id
			local protectionLeft=math.max(0,horse.ProtectedUntil-os.time())
			local protected=selectedProtection or protectionLeft>0
			text.Text=rarity.DisplayName..(protected and "  🔒" or ""); text.TextColor3=rarity.Color; text.Parent=tag
			pad:SetAttribute("StealProtected",protected)
			local prompt=Instance.new("ProximityPrompt"); prompt.Name="PlayerStealPrompt"; prompt.ActionText="훔치기"
			prompt.ObjectText=player.DisplayName.."의 "..horse.RarityId.." 말"; prompt.HoldDuration=ChaseConfig.StealHoldSeconds
			prompt:SetAttribute('OwnerUserId',player.UserId)
			CollectionService:AddTag(prompt,'PlayerHorseStealPrompt')
			prompt.MaxActivationDistance=10; prompt.RequiresLineOfSight=false; prompt.Enabled=not protected; prompt.Parent=pad
			updatePrompt(pad,prompt,player:GetAttribute('FarmTheftEvent')~=nil)
			prompt.Triggered:Connect(function(thief)
				if thief==player or player:GetAttribute('FarmTheftEvent') or thief:GetAttribute('FarmTheftEvent') or prompt:GetAttribute("Busy")==true or not stealHandler then return end
				prompt:SetAttribute("Busy",true); prompt.Enabled=false
				if not stealHandler(thief,player,horse.Id,pad) then
					prompt:SetAttribute("Busy",false); updatePrompt(pad,prompt,player:GetAttribute('FarmTheftEvent')~=nil)
				end
			end)
			if protectionLeft>0 and not selectedProtection then
				task.delay(protectionLeft+.1,function()
					if pad.Parent and prompt.Parent and prompt:GetAttribute("Busy")~=true then
						pad:SetAttribute("StealProtected",false); updatePrompt(pad,prompt,player:GetAttribute('FarmTheftEvent')~=nil)
					end
				end)
			end
		end
	end
	return farm
end
function PlayerFarm.hireDog(player,data)
    local farm=container():FindFirstChild('Farm_'..player.UserId) or PlayerFarm.render(player,data)
    Guards.dog(player,farm,baseFor(player))
end
function PlayerFarm.remove(player:Player)
	player.RespawnLocation=nil
	local spawns=Workspace:FindFirstChild('FarmSpawns');local spawn=spawns and spawns:FindFirstChild('Home_'..player.UserId)
	if spawn then spawn:Destroy() end
	indices[player]=nil; local farms=Workspace:FindFirstChild("HorseFarms"); local parent=farms and farms:FindFirstChild("PlayerFarms")
	local farm=parent and parent:FindFirstChild("Farm_"..player.UserId); if farm then Guards.remove(farm);farm:Destroy() end
end
return PlayerFarm
