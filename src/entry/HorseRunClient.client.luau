local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local ContextActionService=game:GetService('ContextActionService')
local Shared=game:GetService('ReplicatedStorage'):WaitForChild('HorseRun')
local Config=require(Shared.Config)
local Course=require(Shared.Course)
local Horse=require(Shared.Horse)
local Traits=require(game:GetService('ReplicatedStorage').Shared.HorseTraits)
local World=require(Shared.World)
local Characters=require(Shared.Characters)
local Remote=Shared:WaitForChild('Event')
local player=Players.LocalPlayer
local camera=workspace.CurrentCamera
local GuiService=game:GetService('GuiService')
-- Normal third-person controls in the village; runner controls only during a run.
GuiService.TouchControlsEnabled=true
-- Some Studio sessions omit Roblox's optional PlayerModule. Never block the UI on it.
local controls={Enable=function() end,Disable=function() end}
local playerModule=player:WaitForChild('PlayerScripts'):FindFirstChild('PlayerModule')
if playerModule then
    local ok,module=pcall(require,playerModule)
    if ok and module.GetControls then controls=module:GetControls() end
end
local phase='Lobby'
local state={distance=0,elapsed=0,health=60,maxHealth=60,speed=16,carrots=0,lane=0,jumpAt=-10,slideAt=-10,serverTime=0,chase=false}
local profileData={money=100,level=1,exp=0,nextExp=100,best=0,upgrades={Speed=1,Stamina=1},speed=16,maxHealth=60}
local lane=0; local visualX=0; local visualDistance=0; local jumpAt=-10; local slideAt=-10
local startAt=0; local hitFlash=0; local feedbackUntil=0
local wasAirborne=false; local landUntil=0
local track,horse,farmer
local farmerX=0;local farmerGap=24
local chunks,rows,carrotModels={},{},{}
local collectedCarrots={}
local brokenObstacles={}
local jumpFrom=0;local jumpCount=0
local laneSequence=0; local pendingLanes={}; local lastLaneInput=-math.huge
local courseSettings=nil
local chaseRarityName=nil
local selectedHorse='Horse1'
local horseNames=Horse.getNames()
if #horseNames>0 then selectedHorse=horseNames[1] end
local ORIGIN=Vector3.new(5000,0,0)
local GREEN=Color3.fromRGB(29,76,58)
local PAPER=Color3.fromRGB(251,246,229)
local GOLD=Color3.fromRGB(241,194,83)
local MUTED=Color3.fromRGB(100,119,100)

local gui=Instance.new('ScreenGui'); gui.Name='HorseRunUI'; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player:WaitForChild('PlayerGui')
local function rounded(obj,radius)
    local c=Instance.new('UICorner'); c.CornerRadius=UDim.new(0,radius or 16); c.Parent=obj
end
local function frame(name,parent,pos,size,color)
    local f=Instance.new('Frame'); f.Name=name; f.Position=pos; f.Size=size; f.BackgroundColor3=color or PAPER
    f.BorderSizePixel=0; f.Parent=parent; rounded(f); return f
end
local function text(name,parent,value,pos,size,font,color)
    local t=Instance.new('TextLabel'); t.Name=name; t.Text=value; t.Position=pos; t.Size=size
    t.BackgroundTransparency=1; t.TextColor3=color or GREEN; t.Font=font or Enum.Font.GothamMedium
    t.TextScaled=true; t.TextWrapped=true; t.Parent=parent
    local constraint=Instance.new('UITextSizeConstraint'); constraint.MaxTextSize=32; constraint.MinTextSize=10; constraint.Parent=t
    return t
end
local function button(name,parent,value,pos,size,callback,color)
    local b=Instance.new('TextButton'); b.Name=name; b.Text=value; b.Position=pos; b.Size=size
    b.BackgroundColor3=color or GREEN; b.TextColor3=(color==GOLD) and GREEN or PAPER
    b.Font=Enum.Font.GothamBold; b.TextSize=18; b.AutoButtonColor=true; b.BorderSizePixel=0
    b.Parent=parent; rounded(b,14); b.Activated:Connect(callback); return b
end
local brand=frame('Brand',gui,UDim2.new(0,20,0,16),UDim2.fromOffset(215,72),GREEN)
text('Title',brand,'HORSE HEIST',UDim2.fromOffset(14,9),UDim2.new(1,-28,0,30),Enum.Font.GothamBlack,PAPER)
text('Subtitle',brand,'훔치고 · 달리고 · 내 농장에',UDim2.fromOffset(14,44),UDim2.new(1,-28,0,16),nil,Color3.fromRGB(187,214,176))
local visitNpc=button('VisitNpcFarm',gui,'농장주 목장 →',UDim2.fromOffset(20,98),UDim2.fromOffset(154,36),function() Remote:FireServer('Travel','Npc') end)
local visitHome=button('VisitHome',gui,'내 농장 →',UDim2.fromOffset(20,140),UDim2.fromOffset(154,36),function() Remote:FireServer('Travel','Home') end)
local wallet=frame('Wallet',gui,UDim2.new(1,-230,0,16),UDim2.fromOffset(210,72))
local moneyText=text('Money',wallet,'100원',UDim2.fromOffset(15,10),UDim2.new(1,-30,0,30),Enum.Font.GothamBold)
local bestText=text('Best',wallet,'최고 기록  0 m',UDim2.fromOffset(15,46),UDim2.new(1,-30,0,15),nil,MUTED)
local levelCard=frame('LevelCard',gui,UDim2.new(.5,-135,0,16),UDim2.fromOffset(270,72))
local levelText=text('Level',levelCard,'LV. 1',UDim2.fromOffset(14,9),UDim2.fromOffset(74,26),Enum.Font.GothamBlack)
local expText=text('Exp',levelCard,'0 / 100 EXP',UDim2.fromOffset(91,11),UDim2.new(1,-105,0,22),Enum.Font.GothamBold,MUTED)
local expTrack=frame('ExpTrack',levelCard,UDim2.fromOffset(14,45),UDim2.new(1,-28,0,13),Color3.fromRGB(222,229,207))
local expFill=frame('ExpFill',expTrack,UDim2.new(),UDim2.fromScale(0,1),GOLD)

local hint=text('LobbyHint',gui,'W A S D 이동  ·  마우스로 시점 회전\nNPC 말 앞에서 E키 → 안전 대기 후 탈출',UDim2.new(.5,-200,1,-74),UDim2.fromOffset(400,46),nil,PAPER)
local sessionNote=text('SessionNote',gui,'STUDIO TEST · 실제 운영 저장 데이터와 분리됨',UDim2.new(.5,-260,1,-22),UDim2.fromOffset(520,17),nil,GREEN)
local trainingShortcut=button('TrainingShortcut',gui,'훈련  ↑',UDim2.new(1,-144,1,-74),UDim2.fromOffset(124,48),function() Remote:FireServer('OpenTraining') end,GOLD)

local hud=frame('RunHUD',gui,UDim2.new(.5,-170,0,16),UDim2.fromOffset(340,125))
local distanceText=text('Distance',hud,'0 m',UDim2.fromOffset(12,8),UDim2.new(1,-24,0,41),Enum.Font.GothamBlack)
local healthText=text('HealthLabel',hud,'체력  60 / 60',UDim2.fromOffset(18,55),UDim2.new(.58,-18,0,18),Enum.Font.GothamBold)
local carrotText=text('Carrots',hud,'당근  0',UDim2.new(.58,0,0,55),UDim2.new(.42,-18,0,18),Enum.Font.GothamBold)
local healthTrack=frame('HealthTrack',hud,UDim2.fromOffset(18,84),UDim2.new(1,-36,0,18),Color3.fromRGB(222,229,207))
local healthFill=frame('HealthFill',healthTrack,UDim2.new(),UDim2.fromScale(1,1),Color3.fromRGB(98,163,96))
local courseLabel=text('CourseLabel',hud,'초원 코스  ·  체력 0이 되면 런 종료',UDim2.fromOffset(18,107),UDim2.new(1,-36,0,12),nil,MUTED)
local countdown=text('Countdown',gui,'3',UDim2.new(.5,-120,.35,-40),UDim2.fromOffset(240,100),Enum.Font.GothamBlack,PAPER)
countdown.UITextSizeConstraint.MaxTextSize=80
local feedback=text('Feedback',gui,'',UDim2.new(.5,-180,.28,0),UDim2.fromOffset(360,34),Enum.Font.GothamBold,PAPER)
local runControls=Instance.new('Frame'); runControls.Name='RunControls'; runControls.Size=UDim2.fromScale(1,1)
runControls.BackgroundTransparency=1; runControls.Parent=gui
local function action(which)
    if phase~='Running' then return end
    local elapsed=state.elapsed+math.clamp(workspace:GetServerTimeNow()-state.serverTime,0,.2)
    local sliding=elapsed-slideAt>=0 and elapsed-slideAt<Config.SlideDuration
    local airborne=elapsed-jumpAt>=0 and elapsed-jumpAt<Config.JumpDuration
    if which=='Left' or which=='Right' then
        local now=os.clock()
        if now-lastLaneInput<.08 then return end
        local delta=which=='Left' and -1 or 1
        local target=math.clamp(lane+delta,-1,1)
        if target==lane then return end
        lastLaneInput=now
        laneSequence+=1
        table.insert(pendingLanes,{sequence=laneSequence,delta=delta})
        lane=target
        Remote:FireServer(which,laneSequence)
        return
    elseif which=='Jump' then
        if sliding then return end
        if state.ability=='DoubleJump' and airborne and jumpCount==1 and elapsed-jumpAt>=.16 then
            local progress=(elapsed-jumpAt)/Config.JumpDuration
            jumpFrom=jumpFrom*(1-progress)+math.sin(progress*math.pi)*Config.JumpHeight
            jumpAt=elapsed;jumpCount=2
        elseif elapsed-jumpAt>=Config.JumpCooldown then jumpAt=elapsed;jumpFrom=0;jumpCount=1
        else return end
    elseif which=='Slide' then
        if not airborne and elapsed-slideAt>=Config.SlideCooldown then slideAt=elapsed else return end
    end
    Remote:FireServer(which)
end
-- Roblox CoreGui or an accessibility layer can mark Space as processed before
-- InputBegan reaches this script. Bind the runner jump at high priority so the
-- player's jump is reliable while a run is active; the cooldown makes a second
-- delivery harmless.
local RUNNER_JUMP_ACTION='HorseHeistRunnerJump'
ContextActionService:BindActionAtPriority(RUNNER_JUMP_ACTION,function(_,inputState)
    if inputState==Enum.UserInputState.Begin and phase=='Running' then
        action('Jump')
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end,false,Enum.ContextActionPriority.High.Value,Enum.KeyCode.Space,Enum.KeyCode.Up,Enum.KeyCode.ButtonA)
button('LeftButton',runControls,'◀',UDim2.new(0,25,1,-102),UDim2.fromOffset(78,70),function() action('Left') end)
button('RightButton',runControls,'▶',UDim2.new(0,115,1,-102),UDim2.fromOffset(78,70),function() action('Right') end)
button('SlideButton',runControls,'슬라이드 ↓',UDim2.new(1,-248,1,-102),UDim2.fromOffset(106,70),function() action('Slide') end)
button('JumpButton',runControls,'점프 ↑',UDim2.new(1,-132,1,-102),UDim2.fromOffset(106,70),function() action('Jump') end,GOLD)
button('EndButton',runControls,'런 마치기',UDim2.new(1,-132,0,104),UDim2.fromOffset(108,34),function() Remote:FireServer('End') end)
local abilityButton=button('AbilityButton',runControls,'능력 · Q',UDim2.new(1,-190,1,-165),UDim2.fromOffset(165,44),function() action('Ability') end,GOLD)
abilityButton.TextSize=14
local safetyNotice=text('SafetyNotice',gui,'안전 구역에서 말을 데려오는 중',UDim2.new(.5,-220,.35,70),UDim2.fromOffset(440,30),Enum.Font.GothamBold,PAPER)
local runHint=text('RunHint',runControls,'A / D  ·  SPACE  ·  S',UDim2.new(.5,-120,1,-67),UDim2.fromOffset(240,20),nil,PAPER)

local shade=frame('ResultShade',gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(10,30,22)); shade.BackgroundTransparency=.25
local result=frame('ResultCard',shade,UDim2.new(.5,-180,.5,-210),UDim2.fromOffset(360,420))
local resultTitle=text('ResultTitle',result,'잘 달렸어요!',UDim2.fromOffset(24,25),UDim2.new(1,-48,0,28),Enum.Font.GothamBold)
local resultDistance=text('ResultDistance',result,'0 m',UDim2.fromOffset(24,64),UDim2.new(1,-48,0,65),Enum.Font.GothamBlack)
resultDistance.UITextSizeConstraint.MaxTextSize=54
local resultStats=text('ResultStats',result,'',UDim2.fromOffset(28,142),UDim2.new(1,-56,0,88),Enum.Font.GothamMedium)
text('Tip',result,'울타리는 점프! 높게 쌓인 통나무는\n빈 레인으로 이동해서 피하세요.',UDim2.fromOffset(24,240),UDim2.new(1,-48,0,40),nil,MUTED)
local replayButton=button('ReplayButton',result,'한 번 더 달리기',UDim2.fromOffset(24,298),UDim2.new(1,-48,0,45),function() Remote:FireServer('Start') end)
local lobbyButton=button('LobbyButton',result,'마을로 돌아가기',UDim2.fromOffset(24,353),UDim2.new(1,-48,0,43),function() Remote:FireServer('Lobby') end,GOLD)

local trainingShade=frame('TrainingShade',gui,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(10,30,22)); trainingShade.BackgroundTransparency=.25
local training=frame('TrainingCard',trainingShade,UDim2.fromScale(.5,.5),UDim2.fromOffset(430,500)); training.AnchorPoint=Vector2.new(.5,.5)
text('TrainingEyebrow',training,'MEADOW TRAINING YARD',UDim2.fromOffset(26,22),UDim2.new(1,-52,0,18),Enum.Font.GothamBold,MUTED)
text('TrainingTitle',training,'말 훈련',UDim2.fromOffset(26,48),UDim2.new(1,-52,0,38),Enum.Font.GothamBlack)
local trainingMoney=text('TrainingMoney',training,'보유 100원',UDim2.fromOffset(26,92),UDim2.new(1,-52,0,22),Enum.Font.GothamBold)
local speedCard=frame('SpeedCard',training,UDim2.fromOffset(24,132),UDim2.new(1,-48,0,124),Color3.fromRGB(234,239,218))
local speedTitle=text('SpeedTitle',speedCard,'속도 훈련  LV. 1',UDim2.fromOffset(16,12),UDim2.new(1,-32,0,24),Enum.Font.GothamBold)
local speedValue=text('SpeedValue',speedCard,'달리기 속도 16.0',UDim2.fromOffset(16,42),UDim2.new(1,-32,0,20),nil,MUTED)
local speedButton=button('SpeedUpgrade',speedCard,'100원으로 강화',UDim2.fromOffset(16,76),UDim2.new(1,-32,0,36),function() Remote:FireServer('Upgrade','Speed') end)
local staminaCard=frame('StaminaCard',training,UDim2.fromOffset(24,270),UDim2.new(1,-48,0,124),Color3.fromRGB(234,239,218))
local staminaTitle=text('StaminaTitle',staminaCard,'체력 훈련  LV. 1',UDim2.fromOffset(16,12),UDim2.new(1,-32,0,24),Enum.Font.GothamBold)
local staminaValue=text('StaminaValue',staminaCard,'최대 체력 60',UDim2.fromOffset(16,42),UDim2.new(1,-32,0,20),nil,MUTED)
local staminaButton=button('StaminaUpgrade',staminaCard,'100원으로 강화',UDim2.fromOffset(16,76),UDim2.new(1,-32,0,36),function() Remote:FireServer('Upgrade','Stamina') end)
local trainingMessage=text('TrainingMessage',training,'강화는 다음 런부터 적용됩니다.',UDim2.fromOffset(26,407),UDim2.new(1,-52,0,24),Enum.Font.GothamBold,MUTED)
button('CloseTraining',training,'닫기',UDim2.fromOffset(24,447),UDim2.new(1,-48,0,36),function() trainingShade.Visible=false end,GOLD)

local function updateTraining()
    local upgrades=profileData.upgrades or {Speed=1,Stamina=1}
    trainingMoney.Text=string.format('보유 %d원',profileData.money or 0)
    speedTitle.Text=string.format('속도 훈련  LV. %d',upgrades.Speed or 1)
    speedValue.Text=string.format('달리기 속도  %.1f',profileData.speed or Config.Speed)
    staminaTitle.Text=string.format('체력 훈련  LV. %d',upgrades.Stamina or 1)
    staminaValue.Text=string.format('최대 체력  %d',math.floor((profileData.maxHealth or Config.MaxHealth)+.5))
    speedButton.Text=profileData.speedCost and string.format('%d원으로 강화',profileData.speedCost) or '최대 레벨'
    staminaButton.Text=profileData.staminaCost and string.format('%d원으로 강화',profileData.staminaCost) or '최대 레벨'
    speedButton.Active=profileData.speedCost~=nil; speedButton.AutoButtonColor=speedButton.Active
    staminaButton.Active=profileData.staminaCost~=nil; staminaButton.AutoButtonColor=staminaButton.Active
end
trainingShade.Visible=false

local function layout()
    visitNpc.Visible=phase=='Lobby';visitHome.Visible=phase=='Lobby'
    local width=gui.AbsoluteSize.X
    local short=gui.AbsoluteSize.Y<450
    local narrow=width<720
    brand.Visible=(phase=='Lobby' and not short) or (width>=1050 and not short and phase~='Results')
    wallet.Visible=phase=='Lobby' or (width>=1050 and phase~='Results')
    levelCard.Visible=phase=='Lobby' and width>=760 and not short
    brand.Size=UDim2.fromOffset(narrow and 160 or 215,72)
    wallet.Size=UDim2.fromOffset(narrow and 145 or 210,72)
    wallet.Position=UDim2.new(1,narrow and -157 or -230,0,16)
    brand.Position=UDim2.fromOffset(narrow and 12 or 20,16)
    trainingShortcut.Position=narrow and UDim2.new(1,-136,0,98) or UDim2.new(1,-144,1,-74)
    hint.Visible=phase=='Lobby' and not narrow and width>1050
    sessionNote.Size=UDim2.fromOffset(math.min(520,width-24),17)
    sessionNote.Position=UDim2.new(.5,-math.min(520,width-24)/2,1,-22)
    hud.Size=UDim2.fromOffset(math.min(340,width-24),125)
    hud.Position=UDim2.new(.5,-math.min(340,width-24)/2,0,16)
    local hudScale=hud:FindFirstChildWhichIsA('UIScale')
    if not hudScale then hudScale=Instance.new('UIScale'); hudScale.Parent=hud end
    hudScale.Scale=short and .7 or 1
    hud.Position=UDim2.new(.5,-math.min(340,width-24)*hudScale.Scale/2,0,short and 8 or 16)
    result.Size=UDim2.fromOffset(math.min(360,width-24),420)
    result.Position=UDim2.new(.5,-math.min(360,width-24)/2,.5,-210)
    local resultScale=result:FindFirstChildWhichIsA('UIScale')
    if not resultScale then resultScale=Instance.new('UIScale'); resultScale.Parent=result end
    resultScale.Scale=math.min(1,(gui.AbsoluteSize.Y-24)/420)
    result.AnchorPoint=Vector2.new(.5,.5); result.Position=UDim2.fromScale(.5,.5)
    training.Size=UDim2.fromOffset(math.min(430,width-24),500)
    local trainingScale=training:FindFirstChildWhichIsA('UIScale')
    if not trainingScale then trainingScale=Instance.new('UIScale'); trainingScale.Parent=training end
    trainingScale.Scale=math.min(1,(gui.AbsoluteSize.Y-24)/500)
    runHint.Visible=not narrow and not Input.TouchEnabled
    runControls.EndButton.Position=UDim2.new(1,-132,0,narrow and 154 or 104)
    feedback.Position=UDim2.new(.5,-180,short and .4 or .28,0)
    runControls.LeftButton.Position=UDim2.new(0,width<400 and 12 or 25,1,-102)
    runControls.RightButton.Position=UDim2.new(0,width<400 and 86 or 115,1,-102)
    runControls.LeftButton.Size=UDim2.fromOffset(width<400 and 64 or 78,70)
    runControls.RightButton.Size=UDim2.fromOffset(width<400 and 64 or 78,70)
end

local function visibility()
    gui:SetAttribute('Phase',phase)
    sessionNote.Visible=phase=='Lobby'; trainingShortcut.Visible=phase=='Lobby'
    hud.Visible=phase=='Running' or phase=='Countdown'
    runControls.Visible=phase=='Running'
    countdown.Visible=phase=='Countdown'
    safetyNotice.Visible=phase=='Countdown' and state.chase==true
    shade.Visible=phase=='Results'; feedback.Visible=phase=='Running'
    if phase~='Lobby' then trainingShade.Visible=false end
    layout()
end

local function clearTrack()
    -- Hide immediately; spread disposal over frames instead of stalling the respawn frame.
    local oldTrack,oldHorse=track,horse
    if oldTrack then oldTrack.Parent=nil end
    track=nil; horse=nil; farmer=nil; chunks={}; rows={}; carrotModels={}; collectedCarrots={}
    brokenObstacles={};jumpFrom=0;jumpCount=0
    laneSequence=0; pendingLanes={}; lastLaneInput=-math.huge
    task.defer(function()
        if oldHorse then Horse.clear(oldHorse) end
        if oldTrack then
            for index,child in oldTrack:GetChildren() do
                child:Destroy()
                if index%6==0 then RunService.Heartbeat:Wait() end
            end
            oldTrack:Destroy()
        end
    end)
end
local function localPart(parent,name,size,position,color,material,shape)
    local p=World.part(parent,name,size,CFrame.new(ORIGIN+position),color,material,shape)
    p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    return p
end
local function createChunk(index)
    local chunk=Instance.new('Model'); chunk.Name='Chunk'..index; chunk.Parent=track
    local z=-index*100-50
    localPart(chunk,'Grass',Vector3.new(220,.5,100),Vector3.new(0,-.35,z),Color3.fromRGB(126,171,91),Enum.Material.Grass)
    localPart(chunk,'Track',Vector3.new(36,.2,100),Vector3.new(0,0,z),Color3.fromRGB(214,191,142),Enum.Material.Ground)
    for _,x in {-4,4} do
        for offset=-40,40,20 do
            localPart(chunk,'LaneMarker',Vector3.new(.16,.06,8),Vector3.new(x,.14,z+offset),Color3.fromRGB(245,226,177))
        end
    end
    for _,side in {-1,1} do
        for offset=-48,48,12 do
            localPart(chunk,'FencePost',Vector3.new(.5,3,.5),Vector3.new(side*21,1.5,z+offset),Color3.fromRGB(243,231,199))
        end
        for _,y in {1,2.3} do
            localPart(chunk,'FenceRail',Vector3.new(.3,.35,100),Vector3.new(side*21,y,z),Color3.fromRGB(243,231,199))
        end
        World.tree(chunk,ORIGIN.X+side*(39+index%3*8),z+index%4*12,1+index%3*.2)
        localPart(chunk,'Hill',Vector3.new(52,25,52),Vector3.new(side*75,0,z-12),Color3.fromRGB(104,151,92),Enum.Material.Grass,Enum.PartType.Ball)
    end
    if index>0 then
        World.sign(chunk,tostring(index*100)..' m',CFrame.new(ORIGIN+Vector3.new(21,4,-index*100))*CFrame.Angles(0,math.pi,0),6,3)
    end
    chunks[index]=chunk
end
local function createRow(row)
    local model=Instance.new('Model'); model.Name='Row'..row.index; model.Parent=track
    for _,l in row.lanes do
        local key=row.index..':'..l
        if brokenObstacles[key] then continue end
        local obstacle=Instance.new('Folder');obstacle.Name='Obstacle_'..key;obstacle.Parent=model
        local x=l*Config.LaneWidth
        if row.kind=='Fence' then
            for _,side in {-1,1} do
                localPart(obstacle,'FencePost',Vector3.new(.6,3.6,.65),Vector3.new(x+side*3,1.8,-row.distance),Color3.fromRGB(120,76,44),Enum.Material.Wood)
            end
            for _,y in {1.3,2.6} do
                localPart(obstacle,'JumpRail',Vector3.new(6.5,.65,.6),Vector3.new(x,y,-row.distance),Color3.fromRGB(244,202,103),Enum.Material.Wood)
            end
        elseif row.kind=='Log' then
            for h=0,3 do
                localPart(obstacle,'StackedLog',Vector3.new(7,2.2,2.2),Vector3.new(x,1.1+h*2,-row.distance),Color3.fromRGB(111+h*7,75+h*3,45),Enum.Material.Wood,Enum.PartType.Cylinder)
            end
        else
            localPart(obstacle,'BranchPostLeft',Vector3.new(.7,6,.7),Vector3.new(x-3.1,3,-row.distance),Color3.fromRGB(91,62,39),Enum.Material.Wood)
            localPart(obstacle,'BranchPostRight',Vector3.new(.7,6,.7),Vector3.new(x+3.1,3,-row.distance),Color3.fromRGB(91,62,39),Enum.Material.Wood)
            localPart(obstacle,'LowBranch',Vector3.new(7,.8,1.1),Vector3.new(x,4.1,-row.distance),Color3.fromRGB(79,104,49),Enum.Material.Wood)
            localPart(obstacle,'BranchLeaves',Vector3.new(6.2,1.2,1.5),Vector3.new(x,4.55,-row.distance),Color3.fromRGB(75,130,62),Enum.Material.Grass,Enum.PartType.Ball)
        end
    end
    for _,carrot in row.carrots do
        -- A delayed pickup can arrive before this row is streamed, or the row can be rebuilt.
        if collectedCarrots[carrot.id] then continue end
        local modelCarrot=Instance.new('Model'); modelCarrot.Name='Carrot_'..carrot.id; modelCarrot.Parent=model
        local center=Vector3.new(carrot.lane*Config.LaneWidth,1.6,-carrot.distance)
        localPart(modelCarrot,'Carrot',Vector3.new(.9,1.7,.9),center,Color3.fromRGB(249,139,47),Enum.Material.Neon,Enum.PartType.Ball)
        for i=-1,1 do
            localPart(modelCarrot,'Leaf',Vector3.new(.2,.85,.3),center+Vector3.new(i*.22,1,0),Color3.fromRGB(66,143,62))
        end
        carrotModels[carrot.id]=modelCarrot
    end
    rows[row.index]=model
end
local function updateTrack(distance)
    local chunkIndex=math.floor(distance/100)
    for index,chunk in chunks do if index<chunkIndex-1 or index>chunkIndex+4 then chunk:Destroy(); chunks[index]=nil end end
    for index=chunkIndex-1,chunkIndex+4 do if not chunks[index] then createChunk(index) end end
    local rowLength=math.max(Config.RowLength,tonumber(courseSettings and courseSettings.rowLength) or Config.RowLength)
    local first=math.max(0,math.floor((distance-60-Config.CourseStart)/rowLength))
    for index,model in rows do
        if index<first then
            for _,carrot in Course.row(index,courseSettings).carrots do
                carrotModels[carrot.id]=nil
                collectedCarrots[carrot.id]=nil
            end
            model:Destroy(); rows[index]=nil
        end
    end
    for _,row in Course.near(distance,60,Config.ViewDistance,courseSettings) do if not rows[row.index] then createRow(row) end end
end
local function hideCharacter(hidden)
    if player.Character then
        for _,p in player.Character:GetDescendants() do
            if p:IsA('BasePart') then p.LocalTransparencyModifier=hidden and 1 or 0 end
        end
    end
end
local function followCharacter(character)
    task.spawn(function()
        local humanoid=character:WaitForChild('Humanoid',10)
        local root=character:WaitForChild('HumanoidRootPart',10)
        if not humanoid or not root or phase~='Lobby' or player.Character~=character then return end
        camera=workspace.CurrentCamera
        player.CameraMode=Enum.CameraMode.Classic
        player.CameraMinZoomDistance=6; player.CameraMaxZoomDistance=35
        camera.CameraSubject=humanoid
        camera.CameraType=Enum.CameraType.Custom
        camera.CFrame=CFrame.lookAt(root.Position-root.CFrame.LookVector*16+Vector3.new(0,8,0),root.Position+Vector3.new(0,2,0))
        camera.FieldOfView=70
    end)
end
local function enterLobby()
    phase='Lobby'; clearTrack(); controls:Enable(); hideCharacter(false)
    GuiService.TouchControlsEnabled=true
    camera.CameraType=Enum.CameraType.Custom
    if player.Character then followCharacter(player.Character) end
    visibility()
end
local deathConnection
local function hookRespawn(character)
    if deathConnection then deathConnection:Disconnect();deathConnection=nil end
    task.spawn(function()
        local humanoid=character:WaitForChild('Humanoid',10)
        if humanoid and player.Character==character then
            deathConnection=humanoid.Died:Connect(enterLobby)
        end
    end)
end
player.CharacterRemoving:Connect(enterLobby)
player.CharacterAdded:Connect(function(character)
    enterLobby();hookRespawn(character)
end)
if player.Character then hookRespawn(player.Character) end

Remote.OnClientEvent:Connect(function(kind,data)
    if kind=='Profile' then
        profileData=data
        moneyText.Text=string.format('%s원',data.money); bestText.Text=string.format('최고 기록  %s m',data.best)
        levelText.Text=string.format('LV. %d',data.level)
        if data.nextExp and data.nextExp>0 then
            expText.Text=string.format('%d / %d EXP',data.exp,data.nextExp)
            expFill.Size=UDim2.fromScale(math.clamp(data.exp/data.nextExp,0,1),1)
        else
            expText.Text='MAX LEVEL'; expFill.Size=UDim2.fromScale(1,1)
        end
        sessionNote.Text=data.saveMode=='Live' and '자동 저장 켜짐' or 'STUDIO TEST · 실제 운영 저장 데이터와 분리됨'
        updateTraining()
        gui:SetAttribute('Money',data.money); gui:SetAttribute('Best',data.best); gui:SetAttribute('Level',data.level)
    elseif kind=='Lobby' then enterLobby()
    elseif kind=='OpenTraining' then
        if phase=='Lobby' then trainingMessage.Text='강화는 다음 런부터 적용됩니다.'; trainingMessage.TextColor3=MUTED; trainingShade.Visible=true end
    elseif kind=='UpgradeResult' then
        if data.ok then
            trainingMessage.Text=(data.stat=='Speed' and '속도' or '체력')..' 강화 완료!'
            trainingMessage.TextColor3=Color3.fromRGB(65,137,79)
        elseif data.result=='Money' then
            trainingMessage.Text='돈이 부족합니다.'; trainingMessage.TextColor3=Color3.fromRGB(190,91,62)
        elseif data.result=='Max' then
            trainingMessage.Text='이미 최대 레벨입니다.'; trainingMessage.TextColor3=MUTED
        else
            trainingMessage.Text='강화할 수 없습니다.'; trainingMessage.TextColor3=Color3.fromRGB(190,91,62)
        end
    elseif kind=='SaveStatus' then
        if data.mode=='Live' then sessionNote.Text=data.ok and '자동 저장 완료' or '저장 실패 · 잠시 후 다시 시도됩니다' end
    elseif kind=='Start' then
        phase='Countdown'; startAt=data.startAt; clearTrack()
        if data.horseName then selectedHorse=data.horseName end
        courseSettings=data.course
        chaseRarityName=data.rarityName
        track=Instance.new('Folder'); track.Name='LocalHorseTrack'; track.Parent=workspace
        horse=Horse.clone(track,selectedHorse)
        Horse.mount(horse,player.Character)
        if data.chase and data.pvpRole~='Owner' then farmer=Characters.farmer(track) end
        farmerX=0;farmerGap=data.pursuerGap or 24
        local initialDistance=data.initialDistance or 0
        state={distance=initialDistance,elapsed=0,health=data.maxHealth,maxHealth=data.maxHealth,speed=data.speed,carrots=0,lane=0,jumpAt=-10,slideAt=-10,serverTime=workspace:GetServerTimeNow(),chase=data.chase,pvpRole=data.pvpRole,goalDistance=data.goalDistance,pursuerGap=data.pursuerGap}
        state.ability=data.ability or 'None';state.abilityReadyAt=0
        if data.pvpRole=='Owner' then courseLabel.Text='내 말을 지키는 추격 · 3m 이내를 유지하면 체포'
        elseif data.pvpRole=='Thief' then courseLabel.Text=(data.rarityName or '상대')..' 말 탈출 · 결승선까지 도망치세요'
        else courseLabel.Text=data.chase and ((data.rarityName or 'NPC')..' 말 탈출 · 추격 거리 0이면 체포') or '초원 코스  ·  체력 0이 되면 런 종료' end
        lane=0; visualX=0; visualDistance=initialDistance; jumpAt=-10; slideAt=-10; hitFlash=0; feedback.Text=''
        wasAirborne=false; landUntil=0
        controls:Disable(); hideCharacter(true); camera.CameraType=Enum.CameraType.Scriptable
        GuiService.TouchControlsEnabled=false
        updateTrack(initialDistance); visibility()
    elseif kind=='Running' then
        phase='Running'; state.serverTime=workspace:GetServerTimeNow(); visibility()
    elseif kind=='State' then
        state=data
        -- Reapply inputs the server has not processed yet; stale snapshots must not undo a turn.
        local acknowledged=data.laneSequence or 0
        local predicted=data.lane
        local remaining={}
        for _,input in pendingLanes do
            if input.sequence>acknowledged then
                table.insert(remaining,input)
                predicted=math.clamp(predicted+input.delta,-1,1)
            end
        end
        pendingLanes=remaining; lane=predicted
        if data.jumpAt>jumpAt or data.elapsed-jumpAt>Config.JumpDuration then
            jumpAt=data.jumpAt;jumpFrom=data.jumpFrom or 0;jumpCount=data.jumpCount or 0
        end
        local serverSlideAt=data.slideAt or -10
        if serverSlideAt>slideAt or data.elapsed-slideAt>Config.SlideDuration then slideAt=serverSlideAt end
        gui:SetAttribute('SlideAt',slideAt)
    elseif kind=='Effect' then
        if data.kind=='Broken' then
            brokenObstacles[data.id]=true
            local row=rows[data.row];local obstacle=row and row:FindFirstChild('Obstacle_'..data.id)
            if obstacle then obstacle:Destroy() end
            feedback.Text='장애물 파괴!';feedback.TextColor3=GOLD;feedbackUntil=os.clock()+1
        elseif data.kind=='Ability' then
            feedback.Text='질주! 3초간 속도 +25%';feedback.TextColor3=GOLD;feedbackUntil=os.clock()+1.5
        elseif data.kind=='Carrot' then
            collectedCarrots[data.id]=true
            local model=carrotModels[data.id]; if model then model:Destroy(); carrotModels[data.id]=nil end
            feedback.Text=state.chase and '당근 +1' or '당근 +1  ·  체력 +1'; feedback.TextColor3=GOLD; feedbackUntil=os.clock()+.7
        elseif data.kind=='Hit' then
            hitFlash=1
            if state.pvpRole=='Owner' then feedback.Text='충돌!  도둑이 8m 멀어짐'
            elseif state.chase then feedback.Text='충돌!  추격자가 8m 가까워짐'
            else feedback.Text='충돌!  체력 -15' end
            feedback.TextColor3=Color3.fromRGB(255,192,148); feedbackUntil=os.clock()+1.1
        end
    elseif kind=='Result' then
        phase='Results'; state.distance=data.distance; visualDistance=data.distance
        if data.chase then
            if data.reason=='TransferPending' or data.reason=='IndexWriteFailed' or data.reason=='JournalFinalizeFailed' or data.reason=='CompletedReadFailed' then
                resultTitle.Text='소유권 이전 처리 중 · 재접속 시 자동 복구됩니다'
            elseif data.reason=='SaveFailed' or data.reason=='TransferFailed' or data.reason=='Protected' or data.reason=='Missing' or data.reason=='PlayerLeft' or data.reason=='NotOwner' then
                resultTitle.Text='소유권 확인 실패 · 말은 이전되지 않았습니다'
            elseif data.pvpRole=='Owner' then resultTitle.Text=data.success and '방어 성공!  말을 지켰습니다' or '말을 빼앗겼습니다'
            else resultTitle.Text=data.success and '탈출 성공!  말을 획득했습니다' or '체포되었습니다' end
            resultDistance.Text=string.format('%d / %d m',data.distance,data.goalDistance or data.distance)
            resultStats.Text=string.format('%s  %s\n당근 %d개  ·  충돌 %d회\n보유 말 %d마리',data.rarityId or '',data.horseName or '',data.carrots or 0,data.hits or 0,data.capturedCount or 0)
            replayButton.Visible=false
        else
            resultTitle.Text=data.record and 'NEW RECORD!  새로운 기록' or '잘 달렸어요!'
            resultDistance.Text=data.distance..' m'
            local levelLine=data.levelUps>0 and string.format('\nLEVEL UP!  LV. %d',data.level) or ''
            resultStats.Text=string.format('당근  %d개     ·     충돌  %d회\n\n+%d원     +%d EXP%s',data.carrots,data.hits,data.money,data.exp,levelLine)
            replayButton.Visible=true
        end
        gui:SetAttribute('LastReward',data.money); gui:SetAttribute('LastDistance',data.distance)
        visibility()
    end
end)

Input.InputBegan:Connect(function(input,processed)
    if processed or Input:GetFocusedTextBox() then return end
    local key=input.KeyCode
    if key==Enum.KeyCode.A or key==Enum.KeyCode.Left or key==Enum.KeyCode.DPadLeft then action('Left')
    elseif key==Enum.KeyCode.D or key==Enum.KeyCode.Right or key==Enum.KeyCode.DPadRight then action('Right')
    elseif key==Enum.KeyCode.Space or key==Enum.KeyCode.Up or key==Enum.KeyCode.ButtonA then action('Jump')
    elseif key==Enum.KeyCode.S or key==Enum.KeyCode.Down or key==Enum.KeyCode.ButtonB then action('Slide') end
    if key==Enum.KeyCode.Q or key==Enum.KeyCode.ButtonX then action('Ability') end
end)
Input.TouchSwipe:Connect(function(direction,_,processed)
    if processed then return end
    if direction==Enum.SwipeDirection.Left then action('Left')
    elseif direction==Enum.SwipeDirection.Right then action('Right')
    elseif direction==Enum.SwipeDirection.Up then action('Jump')
    elseif direction==Enum.SwipeDirection.Down then action('Slide') end
end)
camera:GetPropertyChangedSignal('ViewportSize'):Connect(layout)
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
local streamAt=0
RunService.RenderStepped:Connect(function(dt)
    if not track or not horse then return end
    local elapsed=state.elapsed
    if phase=='Running' then
        local since=math.clamp(workspace:GetServerTimeNow()-state.serverTime,0,.2)
        elapsed+=since
        local target=state.distance+(state.speed or Config.Speed)*since
        visualDistance+=(target-visualDistance)*math.min(1,dt*22)
    end
    local targetX=lane*Config.LaneWidth
    local lean=math.clamp((targetX-visualX)/Config.LaneWidth,-1,1)
    visualX+=(targetX-visualX)*(1-math.exp(-18*dt))
    local progress=(elapsed-jumpAt)/Config.JumpDuration
    local height=progress>=0 and progress<=1 and (jumpFrom*(1-progress)+math.sin(progress*math.pi)*Config.JumpHeight) or 0
    local airborne=height>0.05
    if airborne then
        wasAirborne=true
    elseif wasAirborne then
        wasAirborne=false; landUntil=os.clock()+0.22
    end
    local landing=math.clamp((landUntil-os.clock())/0.22,0,1)
    local slideElapsed=elapsed-slideAt
    local slideProgress=slideElapsed>=0 and slideElapsed<Config.SlideDuration and slideElapsed/Config.SlideDuration or nil
    if phase=='Results' then height=0; slideProgress=nil end
    local horsePosition=ORIGIN+Vector3.new(visualX,.2+height,-visualDistance)
    Horse.pose(horse,CFrame.new(horsePosition),elapsed,phase=='Running',{
        speed=state.speed or Config.Speed,
        jumpProgress=phase~='Results' and progress>=0 and progress<=1 and progress or nil,
        jumpCount=jumpCount,
        slideProgress=slideProgress,
        landing=landing,
        lean=lean,
        hit=hitFlash,
    })
    if farmer then
        farmerX+=(visualX-farmerX)*(1-math.exp(-dt*5))
        farmerGap+=((state.pursuerGap or 24)-farmerGap)*(1-math.exp(-dt*12))
        Characters.poseFarmer(farmer,CFrame.new(ORIGIN+Vector3.new(farmerX,.2,-visualDistance+farmerGap)),elapsed,phase=='Running')
        farmer:SetAttribute('Gap',farmerGap)
    end
    gui:SetAttribute('MotionState',slideProgress and 'Slide' or (airborne and (progress<0.5 and 'Jump' or 'Air') or (landing>0 and 'Land' or (phase=='Running' and 'Run' or 'Idle'))))
    hitFlash=math.max(0,hitFlash-dt*3)
    local shake=math.sin(os.clock()*65)*hitFlash*.3
    local portrait=camera.ViewportSize.X<camera.ViewportSize.Y
    local camPosition=ORIGIN+Vector3.new(visualX*(portrait and .85 or .3)+shake,19,-visualDistance+42)
    local look=ORIGIN+Vector3.new(visualX*(portrait and .75 or .25),4.5,-visualDistance-12)
    camera.CFrame=CFrame.lookAt(camPosition,look); camera.FieldOfView=phase=='Running' and 74 or 70
    if phase=='Countdown' then countdown.Text=tostring(math.max(1,math.ceil(startAt-workspace:GetServerTimeNow()))) end
    if state.chase then
        local goal=state.goalDistance or 0
        local gap=state.pursuerGap or 24
        distanceText.Text=string.format('%d / %d m',math.floor(visualDistance),math.floor(goal))
        healthText.Text=string.format(state.pvpRole=='Owner' and '도둑 거리  %.1f m' or '추격 거리  %.1f / 28 m',gap)
        healthFill.Size=UDim2.fromScale(math.clamp(gap/28,0,1),1)
        healthFill.BackgroundColor3=gap<8 and Color3.fromRGB(218,76,76) or Color3.fromRGB(98,163,96)
        carrotText.Text=(state.pvpRole=='Owner' and '소유자 추격' or (chaseRarityName or '말'))..'  ·  당근 '..state.carrots
    else
        distanceText.Text=math.floor(visualDistance)..' m'
        local maxHealth=state.maxHealth or Config.MaxHealth
        healthText.Text=string.format('체력  %d / %d',math.ceil(state.health),math.floor(maxHealth+.5))
        healthFill.Size=UDim2.fromScale(math.clamp(state.health/maxHealth,0,1),1)
        healthFill.BackgroundColor3=state.health<20 and Color3.fromRGB(218,116,76) or Color3.fromRGB(98,163,96)
        carrotText.Text='당근  '..state.carrots
    end
    gui:SetAttribute('Distance',math.floor(visualDistance)); gui:SetAttribute('Health',state.health)
    gui:SetAttribute('Lane',lane); gui:SetAttribute('JumpHeight',height)
    local ability=state.ability or 'None'
    abilityButton.Visible=ability~='None'
    abilityButton.Active=ability~='DoubleJump'
    local cooldown=math.max(0,(state.abilityReadyAt or 0)-elapsed)
    abilityButton.Text=ability=='DoubleJump' and '2단 점프 · SPACE ×2' or ((Traits.AbilityNames[ability] or '능력')..(cooldown>0 and string.format(' · %.1fs',cooldown) or ' · Q'))
    if os.clock()>feedbackUntil then feedback.Text='' end
    streamAt+=dt
    if streamAt>.2 then streamAt=0; updateTrack(visualDistance) end
end)
visibility(); Remote:FireServer('Ready')
print('[HorseRun] Client ready — keyboard, gamepad and touch')
