local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("HorseRun"):WaitForChild("Event")

local gui=Instance.new("ScreenGui"); gui.Name="PvPChaseUI"; gui.ResetOnSpawn=false; gui.DisplayOrder=30; gui.Parent=player:WaitForChild("PlayerGui")
local function corner(parent,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 12); c.Parent=parent end
local invite=Instance.new("Frame"); invite.Name="Invitation"; invite.AnchorPoint=Vector2.new(.5,0); invite.Position=UDim2.new(.5,0,0,28)
invite.Size=UDim2.fromOffset(440,150); invite.BackgroundColor3=Color3.fromRGB(25,45,37); invite.BorderSizePixel=0; invite.Visible=false; invite.Parent=gui; corner(invite,16)
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(18,12); title.Size=UDim2.new(1,-36,0,62)
title.Font=Enum.Font.GothamBold; title.TextSize=19; title.TextWrapped=true; title.TextColor3=Color3.fromRGB(251,246,229); title.Parent=invite
local function button(text,x,color)
	local b=Instance.new("TextButton"); b.Text=text; b.Position=UDim2.fromOffset(x,90); b.Size=UDim2.fromOffset(188,44)
	b.BackgroundColor3=color; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=16; b.BorderSizePixel=0; b.Parent=invite; corner(b,10); return b
end
local join=button("추격 참가",18,Color3.fromRGB(54,135,79)); local decline=button("NPC에게 맡기기",234,Color3.fromRGB(112,91,75))
local boost=Instance.new("TextButton"); boost.Name="OwnerBoost"; boost.AnchorPoint=Vector2.new(1,1); boost.Position=UDim2.new(1,-26,1,-28)
boost.Size=UDim2.fromOffset(170,58); boost.Text="가속  [F]"; boost.BackgroundColor3=Color3.fromRGB(195,151,49); boost.TextColor3=Color3.new(1,1,1)
boost.Font=Enum.Font.GothamBlack; boost.TextSize=20; boost.BorderSizePixel=0; boost.Visible=false; boost.Parent=gui; corner(boost,14)
local eventId=nil
local deadline=0
local function answer(accept)
	if not eventId then return end
	remote:FireServer("PvPRespond",{eventId=eventId,accept=accept}); invite.Visible=false; eventId=nil
end
join.Activated:Connect(function() answer(true) end); decline.Activated:Connect(function() answer(false) end)
boost.Activated:Connect(function() remote:FireServer("Boost") end)
game:GetService("UserInputService").InputBegan:Connect(function(input,processed)
	if not processed and input.KeyCode==Enum.KeyCode.F and boost.Visible then remote:FireServer("Boost") end
end)
remote.OnClientEvent:Connect(function(kind,data)
	if kind=="PvPInvitation" then
		eventId=data.eventId; deadline=data.deadline
		title.Text=string.format("%s님이 %s 말을 훔칩니다!\n10초 안에 직접 추격할 수 있습니다.",data.thiefName,data.rarityId)
		join.Visible=true; decline.Visible=true
		invite.Visible=true
	elseif kind=="PvPWaiting" then
		eventId=nil; join.Visible=false; decline.Visible=false
		if data.eventId then
			deadline=data.deadline; title.Text=string.format("%s님의 응답을 기다리는 중…\n응답이 없으면 NPC가 대신 추격합니다.",data.ownerName)
			invite.Visible=true
		else
			invite.Visible=false
		end
	elseif kind=="PvPBoostReady" then
		boost.Visible=data.visible==true; boost.Text=data.ready==false and string.format("가속 %.1f초",data.cooldown or 0) or "가속  [F]"
	elseif kind=="Start" or kind=="Lobby" or kind=="Result" then
		invite.Visible=false; boost.Visible=false; eventId=nil
	end
end)
game:GetService("RunService").RenderStepped:Connect(function()
	if invite.Visible and deadline>0 then
		local left=math.max(0,math.ceil(deadline-workspace:GetServerTimeNow()))
		join.Text="추격 참가  ("..left..")"
	end
end)

