local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local PathfindingService=game:GetService('PathfindingService')
local CollectionService=game:GetService('CollectionService')
local Shared=game:GetService('ReplicatedStorage')
local Config=require(Shared.Shared.GuardConfig)
local Motion=require(Shared.Shared.GuardMotion)
local Characters=require(Shared.HorseRun.Characters)
local Dog=require(Shared.HorseRun.GuardDog)
local Guards={}
local agents={}
local snapshots=Shared.HorseRun:FindFirstChild('GuardSnapshot') or Instance.new('RemoteEvent')
snapshots.Name='GuardSnapshot';snapshots.Parent=Shared.HorseRun
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
    local cf=base*CFrame.new(0,.5,half.Z*.55)
    if dog then Dog.pose(dog,cf,0,false) else Characters.poseFarmer(model,cf,0,false) end
    -- Keep a neutral server rig. Only each client's cosmetic copy animates its limbs.
    for _,part in model:GetChildren() do
        if part:IsA('BasePart') then part:SetAttribute('GuardRestCF',cf:ToObjectSpace(part.CFrame)) end
    end
    model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    model:SetAttribute('GuardKind',dog and 'Dog' or 'Farmer')
    model:SetAttribute('GuardBase',base);model:SetAttribute('GuardHalf',half)
    model:SetAttribute('GuardCF',cf);model:SetAttribute('GuardMoving',false)
    model:SetAttribute('GuardSpeed',0);model:SetAttribute('GuardSnapshotAt',workspace:GetServerTimeNow())
    agents[key]={model=model,base=base,half=half,owner=owner,dog=dog,
        cf=cf,patrol=1,voice=sound,voiceAt=-10,pathAt=-10,path={},node=1,lastSeen=0,
        pathVersion=0,chaseAt=nil,snapshotAt=0}
    CollectionService:AddTag(model,'HorseHeistGuard')
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
    local timestamp=workspace:GetServerTimeNow()
    local packet={}
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
        if a.target~=a.pathTarget then
            a.pathTarget=a.target;a.pathVersion+=1;a.path={};a.pathAt=-10
            a.chaseAt=a.target and now or nil
        end
        -- The center of a personal barn contains stall dividers. Patrol its open courtyard.
        local patrols={Vector3.new(-a.half.X*.45,.5,a.half.Z*.55),Vector3.new(a.half.X*.45,.5,a.half.Z*.55),Vector3.new(0,.5,a.dog and a.half.Z*.3 or 0)}
        local goal=a.target and a.lastPosition or a.base:PointToWorldSpace(patrols[a.patrol])
        local chasing=a.target~=nil
        a.model:SetAttribute('GuardState',chasing and 'Chasing' or 'Patrolling')
        a.model:SetAttribute('TargetUserId',a.target and a.target.UserId or nil)
        if chasing and now-a.voiceAt>=Config.VoiceInterval then a.voice:Play();a.voiceAt=now end
        if root and (root.Position-a.cf.Position).Magnitude<=Config.CatchDistance+1 and clearSight(a,root) then
            -- Recheck immunity at the actual capture, not just at detection.
            if not a.target:GetAttribute('TheftProtected') then humanoid.Health=0 end
            a.target=nil;root=nil;chasing=false;a.chaseAt=nil
            a.pathVersion+=1;a.path={};a.pathTarget=nil
            goal=a.base:PointToWorldSpace(patrols[a.patrol])
        end
        local directParams=RaycastParams.new();directParams.FilterType=Enum.RaycastFilterType.Exclude
        directParams.FilterDescendantsInstances={a.model};directParams.RespectCanCollide=true
        local goalFlat=Vector3.new(goal.X-a.cf.X,0,goal.Z-a.cf.Z)
        local directHit=workspace:Raycast(a.cf.Position+Vector3.new(0,1.8,0),goalFlat,directParams)
        local direct=not directHit or (root and directHit.Instance:IsDescendantOf(root.Parent))
        if direct then
            if #a.path>0 or a.pathBusy then a.pathVersion+=1 end
            a.path={}
        end
        if not direct and not a.pathBusy and now-a.pathAt>=Config.PathInterval then
            a.pathBusy=true;a.pathAt=now
            local start=a.cf.Position
            local version=a.pathVersion
            task.spawn(function()
                local path=PathfindingService:CreatePath({AgentRadius=a.dog and 1.2 or 1.8,AgentHeight=a.dog and 4 or 6,AgentCanJump=false,WaypointSpacing=4})
                local ok=pcall(function() path:ComputeAsync(start,goal) end)
                if agents[key]==a and version==a.pathVersion then
                    if ok and path.Status==Enum.PathStatus.Success then
                        a.path=path:GetWaypoints();a.node=2
                        -- Skip nodes already passed while ComputeAsync was yielding.
                        while a.path[a.node+1] and (a.path[a.node].Position-a.cf.Position).Magnitude<3 do a.node+=1 end
                    else a.path={} end
                end
                path:Destroy()
                a.pathBusy=false
            end)
        end
        local waypoint=a.path[a.node]
        -- Prefer the unobstructed direct route during pursuit; stale patrol waypoints must not pull away.
        if direct then waypoint=nil end
        local destination=waypoint and waypoint.Position or goal
        local direction=Vector3.new(destination.X-a.cf.X,0,destination.Z-a.cf.Z)
        local speed=chasing and Motion.chaseSpeed(now-(a.chaseAt or now),a.dog~=nil) or Config.PatrolSpeed
        local moving=direction.Magnitude>.3
        if moving then
            local travel=direction.Unit*math.min(speed*step,direction.Magnitude)
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={a.model};params.RespectCanCollide=true
            local blocked=workspace:Raycast(a.cf.Position+Vector3.new(0,1.8,0),travel,params)
            if not blocked or (root and blocked.Instance:IsDescendantOf(root.Parent)) then
                local position=a.cf.Position+travel
                a.cf=CFrame.lookAt(position,position+direction.Unit)
            else moving=false end
        end
        if direction.Magnitude<2 then
            if waypoint then a.node+=1 else a.patrol=a.patrol%#patrols+1 end
        end
        -- One rigid transform and one snapshot instead of replicating every animated limb.
        a.model:PivotTo(a.cf)
        a.model:SetAttribute('GuardState',chasing and 'Chasing' or 'Patrolling')
        a.model:SetAttribute('TargetUserId',a.target and a.target.UserId or nil)
        if not a.dog then Characters.setFarmerAngry(a.model,chasing) end
        table.insert(packet,{model=a.model,cf=a.cf,moving=moving,speed=moving and speed or 0})
        -- Durable bootstrap for streaming/new clients; active animation uses one atomic packet.
        if now-a.snapshotAt>=.5 then
            a.snapshotAt=now
            a.model:SetAttribute('GuardCF',a.cf);a.model:SetAttribute('GuardMoving',moving)
            a.model:SetAttribute('GuardSpeed',moving and speed or 0)
            a.model:SetAttribute('GuardSnapshotAt',timestamp)
        end
    end
    if #packet>0 then snapshots:FireAllClients(timestamp,packet) end
end)
return Guards
