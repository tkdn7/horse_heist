local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local PathfindingService=game:GetService('PathfindingService')
local Shared=game:GetService('ReplicatedStorage')
local Config=require(Shared.Shared.GuardConfig)
local Characters=require(Shared.HorseRun.Characters)
local Dog=require(Shared.HorseRun.GuardDog)
local Guards={}
local agents={}
function Guards.inside(base,half,position)
    local p=base:PointToObjectSpace(position)
    return math.abs(p.X)<=half.X and math.abs(p.Z)<=half.Z and math.abs(p.Y)<25
end
function Guards.inView(cf,position)
    local delta=position-(cf.Position+Vector3.new(0,4,0))
    local flat=Vector3.new(delta.X,0,delta.Z)
    return delta.Magnitude<=Config.SightRange and (flat.Magnitude<.1 or cf.LookVector:Dot(flat.Unit)>=math.cos(math.rad(Config.FieldOfView/2)))
end
local function clearSight(a,root)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={a.model};params.RespectCanCollide=true
    local origin=a.cf.Position+Vector3.new(0,a.dog and 2 or 4,0)
    local hit=workspace:Raycast(origin,root.Position-origin,params)
    return not hit or hit.Instance:IsDescendantOf(root.Parent)
end
local function valid(a,p)
    if p.UserId==a.owner or p:GetAttribute('TheftProtected') then return nil end
    local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
    if not h or h.Health<=0 or not r or r.Anchored or not Guards.inside(a.base,a.half,r.Position) then return nil end
    return r,h
end
local function attach(key,model,base,half,owner,dog)
    if agents[key] and agents[key].model==model then return end
    local sound=model:FindFirstChild('GuardVoice',true) or Instance.new('Sound')
    sound.Name='GuardVoice';sound.SoundId=dog and Config.BarkSound or Config.AngrySound
    sound.Volume=Config.VoiceVolume;sound.RollOffMinDistance=12;sound.RollOffMaxDistance=95
    sound.Parent=model.PrimaryPart
    agents[key]={model=model,base=base,half=half,owner=owner,dog=dog,
        cf=base*CFrame.new(0,.5,half.Z*.55),patrol=1,voice=sound,voiceAt=-10,pathAt=-10,path={},node=1,lastSeen=0}
end
function Guards.farmer(farm)
    local model=farm:FindFirstChild('FarmerNPC',true)
    if model then attach(farm,model,CFrame.new(0,0,-215),Vector3.new(90,0,74),nil,nil) end
end
function Guards.dog(player,farm,base)
    if agents[farm] then return end
    local dog=Dog.create(farm)
    dog.model:SetAttribute('OwnerUserId',player.UserId)
    attach(farm,dog.model,base,Vector3.new(60,0,66),player.UserId,dog)
end
function Guards.remove(farm)
    local a=agents[farm];if a and a.dog then a.model:Destroy() end;agents[farm]=nil
end
local accumulated=0
RunService.Heartbeat:Connect(function(dt)
    accumulated+=dt;if accumulated<Config.Tick then return end
    local step=math.min(accumulated,.25);accumulated=0;local now=os.clock()
    for key,a in agents do
        if not a.model:IsDescendantOf(workspace) then agents[key]=nil;continue end
        local root,humanoid
        if a.target then
            root,humanoid=valid(a,a.target)
            if root and clearSight(a,root) then a.lastSeen=now;a.lastPosition=root.Position end
            if not root or now-a.lastSeen>Config.LostSightSeconds then a.target=nil;root=nil end
        end
        if not a.target then
            local nearest=math.huge
            for _,p in Players:GetPlayers() do
                local r,h=valid(a,p)
                if r and Guards.inView(a.cf,r.Position) and clearSight(a,r) then
                    local distance=(r.Position-a.cf.Position).Magnitude
                    if distance<nearest then nearest=distance;a.target=p;root=r;humanoid=h end
                end
            end
            if root then a.lastSeen=now;a.lastPosition=root.Position;a.pathAt=-10;a.path={} end
        end
        local patrols={Vector3.new(-a.half.X*.45,.5,a.half.Z*.55),Vector3.new(a.half.X*.45,.5,a.half.Z*.55),Vector3.new(0,.5,0)}
        local goal=a.target and a.lastPosition or a.base:PointToWorldSpace(patrols[a.patrol])
        local chasing=a.target~=nil
        a.model:SetAttribute('GuardState',chasing and 'Chasing' or 'Patrolling')
        a.model:SetAttribute('TargetUserId',a.target and a.target.UserId or nil)
        if chasing and now-a.voiceAt>=Config.VoiceInterval then a.voice:Play();a.voiceAt=now end
        if root and (root.Position-a.cf.Position).Magnitude<=Config.CatchDistance+1 and clearSight(a,root) then
            -- Recheck immunity at the actual capture, not just at detection.
            if not a.target:GetAttribute('TheftProtected') then humanoid.Health=0 end
            a.target=nil
        end
        if not a.pathBusy and now-a.pathAt>=Config.PathInterval then
            a.pathBusy=true;a.pathAt=now
            local start=a.cf.Position
            task.spawn(function()
                local path=PathfindingService:CreatePath({AgentRadius=a.dog and 1.2 or 1.8,AgentHeight=a.dog and 4 or 6,AgentCanJump=false,WaypointSpacing=4})
                local ok=pcall(function() path:ComputeAsync(start,goal) end)
                if ok and path.Status==Enum.PathStatus.Success then a.path=path:GetWaypoints();a.node=2 else a.path={} end
                a.pathBusy=false
            end)
        end
        local waypoint=a.path[a.node]
        -- Prefer the unobstructed direct route during pursuit; stale patrol waypoints must not pull away.
        if root and clearSight(a,root) then waypoint=nil end
        local destination=waypoint and waypoint.Position or goal
        local direction=Vector3.new(destination.X-a.cf.X,0,destination.Z-a.cf.Z)
        local speed=chasing and Config.ChaseSpeed or Config.PatrolSpeed
        local moving=direction.Magnitude>.3
        if moving then
            local travel=direction.Unit*math.min(speed*step,direction.Magnitude)
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={a.model};params.RespectCanCollide=true
            local blocked=workspace:Raycast(a.cf.Position+Vector3.new(0,1.8,0),travel,params)
            if not blocked or (root and blocked.Instance:IsDescendantOf(root.Parent)) then
                local position=a.cf.Position+travel
                a.cf=CFrame.lookAt(position,position+direction.Unit)
            end
        end
        if direction.Magnitude<2 then
            if waypoint then a.node+=1 else a.patrol=a.patrol%#patrols+1 end
        end
        if a.dog then Dog.pose(a.dog,a.cf,now,moving) else Characters.poseFarmer(a.model,a.cf,now,moving) end
    end
end)
return Guards
