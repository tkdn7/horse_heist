--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local PlayerFarm={}
local indices:{[Player]:number}={}
local Visual=require(ReplicatedStorage.HorseRun.FarmVisual)
local Rarity=require(ReplicatedStorage.Shared.HorseRarity)
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
function PlayerFarm.home(player:Player):CFrame
    return baseFor(player)*CFrame.new(0,4,43)
end
local function container():Folder
	local farms=Workspace:FindFirstChild("HorseFarms") or Instance.new("Folder")
	farms.Name="HorseFarms"; farms.Parent=Workspace
	local result=farms:FindFirstChild("PlayerFarms") or Instance.new("Folder")
	result.Name="PlayerFarms"; result.Parent=farms
	return result::Folder
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
    local old=farm:FindFirstChild("Displays");if old then old:Destroy() end
    local displays=Instance.new("Folder",farm);displays.Name="Displays"
    local placed={}
	for _,horse in data.Horses do if horse.Placed and #placed<12 then table.insert(placed,horse) end end
	local templates=ReplicatedStorage:WaitForChild("HorseRun"):WaitForChild("Horses")
	for index=1,12 do
		local cf=Visual.slot(base,index)
        local display=Instance.new("Folder",displays);display.Name="Stall"..index
		local pad=Instance.new("Part"); pad.Name="Slot"..index; pad.Anchored=true; pad.Size=Vector3.new(11,1,11)
		pad.CFrame=cf; pad.Material=Enum.Material.Grass; pad.Color=Color3.fromRGB(91,135,78); pad.Parent=display
		local horse=placed[index]
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
			prompt.ObjectText=player.DisplayName.."의 "..horse.RarityId.." 말"; prompt.HoldDuration=rarity.StealHoldSeconds
			prompt.MaxActivationDistance=10; prompt.RequiresLineOfSight=false; prompt.Enabled=not protected; prompt.Parent=pad
			prompt.Triggered:Connect(function(thief)
				if thief==player or prompt:GetAttribute("Busy")==true or not stealHandler then return end
				prompt:SetAttribute("Busy",true); prompt.Enabled=false
				if not stealHandler(thief,player,horse.Id,pad) then
					prompt:SetAttribute("Busy",false); prompt.Enabled=pad:GetAttribute("StealProtected")~=true
				end
			end)
			if protectionLeft>0 and not selectedProtection then
				task.delay(protectionLeft+.1,function()
					if pad.Parent and prompt.Parent and prompt:GetAttribute("Busy")~=true then
						pad:SetAttribute("StealProtected",false); prompt.Enabled=true; text.Text=rarity.DisplayName
					end
				end)
			end
		end
	end
	return farm
end
function PlayerFarm.remove(player:Player)
	indices[player]=nil; local farms=Workspace:FindFirstChild("HorseFarms"); local parent=farms and farms:FindFirstChild("PlayerFarms")
	local farm=parent and parent:FindFirstChild("Farm_"..player.UserId); if farm then farm:Destroy() end
end
return PlayerFarm
