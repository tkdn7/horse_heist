local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer
local remote=RS:WaitForChild('HorseRun'):WaitForChild('Event')
local gui=Instance.new('ScreenGui');gui.Name='PvPChaseUI';gui.ResetOnSpawn=false;gui.DisplayOrder=30;gui.Parent=player:WaitForChild('PlayerGui')
local function corner(parent)
    local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,12);c.Parent=parent
end
local invite=Instance.new('Frame');invite.Name='Invitation';invite.AnchorPoint=Vector2.new(.5,0)
invite.Position=UDim2.new(.5,0,0,28);invite.Size=UDim2.new(1,-24,0,210)
invite.BackgroundColor3=Color3.fromRGB(25,45,37);invite.BorderSizePixel=0;invite.Visible=false;invite.Parent=gui;corner(invite)
local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(460,210);limit.Parent=invite
local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(16,10);title.Size=UDim2.new(1,-32,0,70)
title.Font=Enum.Font.GothamBold;title.TextSize=17;title.TextWrapped=true;title.TextColor3=Color3.fromRGB(251,246,229);title.Parent=invite
local function button(parent,name,text,position,size,color)
    local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Position=position;b.Size=size
    b.BackgroundColor3=color;b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=15;b.TextWrapped=true
    b.BorderSizePixel=0;b.Parent=parent;corner(b);return b
end
local join=button(invite,'Join','추격 참가',UDim2.fromOffset(16,90),UDim2.new(.5,-22,0,44),Color3.fromRGB(54,135,79))
local decline=button(invite,'Delegate','NPC에게 맡기기',UDim2.new(.5,6,0,90),UDim2.new(.5,-22,0,44),Color3.fromRGB(112,91,75))
local invitationGiveUp=button(invite,'GiveUp','포기 · 말 넘기기',UDim2.fromOffset(16,150),UDim2.new(1,-32,0,44),Color3.fromRGB(150,66,53))
local runGiveUp=button(gui,'GiveUp','',UDim2.new(.5,0,1,-24),UDim2.fromOffset(248,44),Color3.fromRGB(150,66,53))
runGiveUp.AnchorPoint=Vector2.new(.5,1);runGiveUp.Visible=false
local eventId,role=nil,nil
local deadline=0
local busy=false
local function refresh()
    local text=busy and '포기 처리 중…' or (role=='Owner' and '포기 · 말 넘기기' or '포기 · 원래 주인에게 반환')
    invitationGiveUp.Text=text;runGiveUp.Text=text
    for _,b in {invitationGiveUp,runGiveUp,join,decline} do b.Active=not busy;b.AutoButtonColor=not busy end
    runGiveUp.Visible=eventId~=nil and not invite.Visible
end
local function clear()
    eventId=nil;role=nil;deadline=0;busy=false;invite.Visible=false;runGiveUp.Visible=false
end
local function giveUp()
    if not eventId or busy then return end
    busy=true;refresh()
    remote:FireServer('PvPGiveUp',{eventId=eventId})
    local requested=eventId
    task.delay(3,function()
        if eventId==requested and busy then busy=false;refresh() end
    end)
end
invitationGiveUp.Activated:Connect(giveUp);runGiveUp.Activated:Connect(giveUp)
local function answer(accept)
    if not eventId or role~='Owner' or busy then return end
    remote:FireServer('PvPRespond',{eventId=eventId,accept=accept})
    invite.Visible=false;refresh()
end
join.Activated:Connect(function() answer(true) end)
decline.Activated:Connect(function() answer(false) end)
remote.OnClientEvent:Connect(function(kind,data)
    if kind=='PvPInvitation' then
        eventId=data.eventId;role='Owner';deadline=data.deadline;busy=false
        title.Text=string.format('%s님이 %s 말을 훔칩니다!\n추격하거나, 포기하고 말을 넘길 수 있습니다.',data.thiefName,data.rarityId)
        join.Visible=true;decline.Visible=true;invite.Visible=true;refresh()
    elseif kind=='PvPWaiting' and data.eventId then
        eventId=data.eventId;role=data.role or 'Thief';deadline=data.deadline or 0;busy=false
        join.Visible=false;decline.Visible=false;invite.Visible=not data.delegated
        if not data.delegated then title.Text=string.format('%s님의 응답을 기다리는 중…\n응답이 없으면 NPC가 대신 추격합니다.',data.ownerName) end
        refresh()
    elseif kind=='Start' then
        invite.Visible=false;eventId=data.eventId;role=data.pvpRole;busy=false;refresh()
    elseif kind=='PvPResolved' then
        if data.eventId==eventId then clear() end
    elseif kind=='Lobby' or kind=='RunEnded' or kind=='Result' or kind=='PvPCancelled' then
        clear()
    end
end)
game:GetService('RunService').RenderStepped:Connect(function()
    if invite.Visible and join.Visible and deadline>0 then
        join.Text='추격 참가 ('..math.max(0,math.ceil(deadline-workspace:GetServerTimeNow()))..')'
    end
end)

