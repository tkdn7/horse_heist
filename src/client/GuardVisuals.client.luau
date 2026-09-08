local CollectionService=game:GetService('CollectionService')
local RunService=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local Config=require(RS:WaitForChild('Shared'):WaitForChild('GuardConfig'))
local Motion=require(RS.Shared:WaitForChild('GuardMotion'))
local Characters=require(RS:WaitForChild('HorseRun'):WaitForChild('Characters'))
local Dog=require(RS.HorseRun:WaitForChild('GuardDog'))
local TAG='HorseHeistGuard'
local visuals=Instance.new('Folder');visuals.Name='LocalGuardVisuals';visuals.Parent=workspace
local entries={}

local function line(parent,name)
    local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.Material=Enum.Material.Neon;p.CastShadow=false;p.Transparency=.3;p.Parent=parent
    return p
end
local function draw(p,a,b,color)
    local length=(b-a).Magnitude
    p.Transparency=length<.05 and 1 or .3
    if length<.05 then return end
    p.Color=color;p.Size=Vector3.new(.13,.13,length);p.CFrame=CFrame.lookAt((a+b)/2,b)
end
local function remove(model)
    local e=entries[model];if not e then return end
    entries[model]=nil;e.connection:Disconnect();e.clone:Destroy();e.debug:Destroy()
    for p,value in e.hidden do if p.Parent then
        if p:IsA('BasePart') then p.LocalTransparencyModifier=value else p.Enabled=value end
    end end
end
local function add(model)
    if entries[model] or not model:IsA('Model') or not model:IsDescendantOf(workspace) or not model.PrimaryPart then return end
    local cf=model:GetAttribute('GuardCF');if typeof(cf)~='CFrame' then return end
    local clone=model:Clone();if not clone then return end
    CollectionService:RemoveTag(clone,TAG);clone.Name=model.Name..'_Smooth'
    for _,d in clone:GetDescendants() do
        if d:IsA('BaseScript') or d:IsA('Sound') then d:Destroy()
        elseif d:IsA('BasePart') then d.CanCollide=false;d.CanTouch=false;d.CanQuery=false end
    end
    local hidden={}
    for _,p in model:GetDescendants() do
        if p:IsA('BasePart') then hidden[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1
        elseif p:IsA('BillboardGui') then hidden[p]=p.Enabled;p.Enabled=false end
    end
    local debugModel=Instance.new('Model');debugModel.Name='Detection_'..model.Name
    local e={clone=clone,hidden=hidden,samples={},phase=0,debug=debugModel,lines={},debugAt=0}
    e.dog=model:GetAttribute('GuardKind')=='Dog' and Dog.capture(clone) or nil
    for i=1,26 do e.lines[i]=line(debugModel,'View_'..i) end
    for i=1,4 do e.lines[26+i]=line(debugModel,'FarmBoundary_'..i) end
    local gui=Instance.new('BillboardGui');gui.Name='GuardDebugLabel';gui.Size=UDim2.fromOffset(230,42)
    gui.StudsOffset=Vector3.new(0,e.dog and 5 or 8,0);gui.Adornee=clone.PrimaryPart;gui.MaxDistance=160;gui.Parent=debugModel
    local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
    label.TextColor3=Color3.new(1,1,1);label.TextStrokeTransparency=.25;label.TextSize=14;label.Parent=gui;e.label=label
    local function snapshot()
        local t=model:GetAttribute('GuardSnapshotAt');local pose=model:GetAttribute('GuardCF')
        if type(t)~='number' or typeof(pose)~='CFrame' then return end
        local last=e.samples[#e.samples];if last and t<=last.time then return end
        table.insert(e.samples,{time=t,cf=pose,moving=model:GetAttribute('GuardMoving'),speed=model:GetAttribute('GuardSpeed') or 0})
        if #e.samples>12 then table.remove(e.samples,1) end
    end
    e.connection=model:GetAttributeChangedSignal('GuardSnapshotAt'):Connect(snapshot)
    snapshot();entries[model]=e;clone.Parent=visuals
end

local function range(model,e,cf,now,speed)
    local enabled=workspace:GetAttribute('GuardDebugEnabled')
    if enabled==nil then enabled=Config.ShowDetectionRange end
    e.debug.Parent=enabled and visuals or nil
    if not enabled or now-e.debugAt<.1 then return end
    e.debugAt=now
    local base,half=model:GetAttribute('GuardBase'),model:GetAttribute('GuardHalf')
    if typeof(base)~='CFrame' or typeof(half)~='Vector3' then return end
    local chasing=model:GetAttribute('GuardState')=='Chasing'
    local color=chasing and Color3.fromRGB(255,82,60) or Color3.fromRGB(91,242,119)
    local center=Vector3.new(cf.X,base.Y+.75,cf.Z)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={model,visuals};params.RespectCanCollide=true
    local prev
    for i=0,24 do
        local angle=math.rad(-Config.FieldOfView/2+Config.FieldOfView*i/24)
        local direction=(cf.Rotation*CFrame.Angles(0,angle,0)).LookVector
        local origin=cf.Position+Vector3.new(0,e.dog and 2 or 4,0)
        local distance=Config.SightRange
        -- Restrict the cone to the same farm rectangle used by the server.
        local o=base:PointToObjectSpace(center);local d=base:VectorToObjectSpace(direction)
        for _,axis in {'X','Z'} do
            if math.abs(d[axis])>.001 then
                local edge=(d[axis]>0 and half[axis] or -half[axis])
                distance=math.min(distance,math.max(0,(edge-o[axis])/d[axis]))
            end
        end
        local hit=workspace:Raycast(origin,direction*distance,params)
        if hit then distance=hit.Distance end
        local point=center+direction*distance
        if prev then draw(e.lines[i],prev,point,color) else draw(e.lines[25],center,point,color) end
        prev=point
    end
    draw(e.lines[26],center,prev,color)
    local corners={Vector3.new(-half.X,.75,-half.Z),Vector3.new(half.X,.75,-half.Z),Vector3.new(half.X,.75,half.Z),Vector3.new(-half.X,.75,half.Z)}
    for i=1,4 do draw(e.lines[26+i],base:PointToWorldSpace(corners[i]),base:PointToWorldSpace(corners[i%4+1]),Color3.fromRGB(255,196,78)) end
    e.label.Text=string.format('%s · %s · %.1f studs/s\n시야 %d° / %d studs',e.dog and '경비견' or '농장주',chasing and '추격' or '순찰',speed,Config.FieldOfView,Config.SightRange)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
for _,model in CollectionService:GetTagged(TAG) do add(model) end
RunService.PreRender:Connect(function(dt)
    local now=workspace:GetServerTimeNow();local camera=workspace.CurrentCamera
    for model,e in entries do
        if not model:IsDescendantOf(workspace) then remove(model);continue end
        local cf,moving,speed=Motion.sample(e.samples,now-Config.VisualDelay)
        if not cf then continue end
        local nearby=camera and (camera.CFrame.Position-cf.Position).Magnitude<Config.VisualDistance
        e.clone.Parent=nearby and visuals or nil
        if not nearby then e.debug.Parent=nil;continue end
        if moving then e.phase+=math.min(dt,.1)*math.clamp(speed/16,.5,1.8) end
        if e.dog then Dog.pose(e.dog,cf,e.phase,moving) else Characters.poseFarmer(e.clone,cf,e.phase,moving) end
        range(model,e,cf,now,speed)
    end
end)
