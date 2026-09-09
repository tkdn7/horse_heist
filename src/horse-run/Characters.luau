local VisualRig=require(script.Parent.VisualRig)
local Characters={}
local rigs=setmetatable({},{__mode='k'})
local headParts={Head=true,Eye=true,Brow=true,Mustache=true,HatBrim=true,StrawHat=true}
local function part(parent,name,size,cf,color)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Anchored=true
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
function Characters.equipFarmer(model)
    local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')
    local head=model:FindFirstChild('Head')
    if not root or not head then return end
    if head:GetAttribute('FarmerSkinColor')==nil then head:SetAttribute('FarmerSkinColor',head.Color) end
    if model:GetAttribute('PitchforkGripVersion')==2 and model:FindFirstChild('PitchforkHandle') then return end
    -- Remove only the generated obsolete prop, including saved display copies.
    for _,p in model:GetChildren() do
        if p:GetAttribute('FarmerHandProp') and (p.Name:match('^Handcuff') or p.Name:match('^Pitchfork')) then p:Destroy() end
    end
    -- The shaft runs forward through the palm; every piece shares the hand's animation.
    local grip=CFrame.new(1.52,2.05,-.15)*CFrame.Angles(-math.pi/2,0,0)
    local function tool(name,size,rest,color,material)
        rest=grip*rest
        local p=part(model,name,size,root.CFrame*rest,color)
        p.Material=material;p:SetAttribute('FarmerHandProp',true);p:SetAttribute('GuardRestCF',rest)
    end
    tool('PitchforkHandle',Vector3.new(.2,3.6,.2),CFrame.new(0,.35,0),Color3.fromRGB(132,88,46),Enum.Material.Wood)
    local metal=Color3.fromRGB(158,170,181)
    tool('PitchforkCrossbar',Vector3.new(1.3,.18,.22),CFrame.new(0,2.1,0),metal,Enum.Material.Metal)
    for i=1,4 do
        tool('PitchforkTine'..i,Vector3.new(.13,1.05,.13),CFrame.new((i-2.5)*.38,2.68,-.08)*CFrame.Angles(-.12,0,0),metal,Enum.Material.Metal)
    end
    model:SetAttribute('PitchforkGripVersion',2)
    rigs[model]=nil
end

function Characters.setFarmerAngry(model,angry)
    local head=model:FindFirstChild('Head');if not head then return end
    local skin=head:GetAttribute('FarmerSkinColor') or head.Color
    head.Color=angry and Color3.fromRGB(245,64,48) or skin
    local gui=head:FindFirstChild('FarmerLabel')
    local label=gui and gui:FindFirstChildWhichIsA('TextLabel')
    if label then
        label.Text='농장주'
        label.TextColor3=Color3.fromRGB(255,218,129)
    end
end

function Characters.farmer(parent)
    local m=Instance.new('Model');m.Name='FarmerNPC';m:SetAttribute('Role','Farmer')
    local skin=Color3.fromRGB(222,167,117);local shirt=Color3.fromRGB(158,64,43);local blue=Color3.fromRGB(46,77,102)
    local root=part(m,'HumanoidRootPart',Vector3.one,CFrame.new(),blue);root.Transparency=1;m.PrimaryPart=root
    part(m,'Torso',Vector3.new(2.3,2.2,1.2),CFrame.new(0,3.2,0),shirt)
    part(m,'Overalls',Vector3.new(1.7,1.6,1.26),CFrame.new(0,2.9,0),blue)
    local head=part(m,'Head',Vector3.new(1.5,1.5,1.4),CFrame.new(0,5.05,0),skin)
    part(m,'HatBrim',Vector3.new(3,.18,2.6),CFrame.new(0,5.87,0),Color3.fromRGB(217,177,92))
    part(m,'StrawHat',Vector3.new(1.8,.65,1.7),CFrame.new(0,6.25,0),Color3.fromRGB(197,149,69))
    for _,side in {-1,1} do
        part(m,'Eye',Vector3.new(.18,.2,.1),CFrame.new(side*.34,5.22,-.72),Color3.fromRGB(35,29,24))
        part(m,'Brow',Vector3.new(.46,.12,.12),CFrame.new(side*.34,5.5,-.74)*CFrame.Angles(0,0,side*.22),Color3.fromRGB(72,46,29))
        part(m,'Arm'..side,Vector3.new(.7,2.15,.8),CFrame.new(side*1.52,3.25,0),shirt)
        part(m,'Hand'..side,Vector3.new(.72,.55,.82),CFrame.new(side*1.52,2.05,0),skin)
        part(m,'Leg'..side,Vector3.new(.95,2,.95),CFrame.new(side*.57,1.1,0),blue)
        part(m,'Boot'..side,Vector3.new(1,.55,1.5),CFrame.new(side*.57,.3,-.2),Color3.fromRGB(62,44,31))
    end
    part(m,'Mustache',Vector3.new(.95,.18,.15),CFrame.new(0,4.88,-.74),Color3.fromRGB(72,46,29))
    local ui=Instance.new('BillboardGui');ui.Name='FarmerLabel';ui.Size=UDim2.fromOffset(170,34);ui.StudsOffset=Vector3.new(0,2,0);ui.Adornee=head;ui.MaxDistance=110;ui.Parent=head
    local label=Instance.new('TextLabel',ui);label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Text='농장주';label.TextColor3=Color3.fromRGB(255,218,129);label.Font=Enum.Font.GothamBold;label.TextSize=20;label.TextStrokeTransparency=.3
    Characters.equipFarmer(m)
    m.Parent=parent
    local rest={};for _,p in m:GetChildren() do if p:IsA('BasePart') then
        rest[p]=p.CFrame;p:SetAttribute('GuardRestCF',p.CFrame)
        if headParts[p.Name] then p:SetAttribute('FarmerRestSize',p.Size) end
    end end
    rigs[m]={rest=rest};return m
end
function Characters.poseFarmer(model,cf,time,running,angry,animationTime)
    local state=rigs[model]
    if not state then
        Characters.equipFarmer(model)
        -- A farmer saved in the Place has no entry in this session's module cache.
        local root=model.PrimaryPart or model:FindFirstChild('HumanoidRootPart')
        if not root then return end
        model.PrimaryPart=root
        local rest={}
        for _,p in model:GetChildren() do if p:IsA('BasePart') then rest[p]=p:GetAttribute('GuardRestCF') or root.CFrame:ToObjectSpace(p.CFrame) end end
        state={rest=rest};rigs[model]=state
    end
    Characters.setFarmerAngry(model,angry==true)
    local weight=type(running)=='number' and math.clamp(running,0,1) or (running and 1 or 0)
    local phase=time*13;local bounce=math.abs(math.sin(phase))*.22*weight
    local headScale=angry and 1+.35*(1-math.cos((animationTime or time)*2*math.pi/.9))/2 or 1
    local neck=Vector3.new(0,4.3,0)
    for p,rest in state.rest do
        local offset=rest
        for _,side in {-1,1} do
            local swing=math.sin(phase)*side*.8*weight
            if p.Name=='Leg'..side or p.Name=='Boot'..side then
                offset=CFrame.new(side*.57,2.1,0)*CFrame.Angles(swing,0,0)*CFrame.new(-side*.57,-2.1,0)*rest
            elseif p.Name=='Arm'..side or p.Name=='Hand'..side or (side==1 and p:GetAttribute('FarmerHandProp')) then
                local armAngle=side==1 and (-.12-swing*.12) or (-swing-.25)
                offset=CFrame.new(side*1.52,4.1,0)*CFrame.Angles(armAngle,0,side*.04)*CFrame.new(-side*1.52,-4.1,0)*rest
            end
        end
        if headParts[p.Name] then
            local size=p:GetAttribute('FarmerRestSize')
            if not size then size=p.Size;p:SetAttribute('FarmerRestSize',size) end
            if p.Size~=size*headScale then p.Size=size*headScale end
            offset=CFrame.new(neck+(rest.Position-neck)*headScale)*rest.Rotation
            local label=p:FindFirstChild('FarmerLabel')
            if label then label.StudsOffset=Vector3.new(0,2*headScale,0) end
        end
        p.CFrame=cf*CFrame.new(0,bounce,0)*offset
    end
end
function Characters.rider(parent,character)
    if not character or not character:FindFirstChild('HumanoidRootPart') then return nil end
    local previous=character.Archivable;character.Archivable=true
    local model=character:Clone();character.Archivable=previous
    model.Name='MountedRider'
    for _,d in model:GetDescendants() do
        if d:IsA('BaseScript') or d:IsA('Tool') or d:IsA('Sound') then d:Destroy() end
    end
    local root=model:FindFirstChild('HumanoidRootPart');model.PrimaryPart=root
    local hum=model:FindFirstChildOfClass('Humanoid')
    if hum then
        hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;hum.AutoRotate=false
        hum.EvaluateStateMachine=false
        local animator=hum:FindFirstChildOfClass('Animator');if animator then animator:Destroy() end
    end
    model.Parent=parent
    local joints={}
    for _,d in model:GetDescendants() do
        if d:IsA('BasePart') then
            d.Anchored=d==root;d.Massless=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false;d.LocalTransparencyModifier=0
        elseif d:IsA('Motor6D') or d:IsA('AnimationConstraint') then
            joints[d.Name]=d
            if d:IsA('AnimationConstraint') then d.IsKinematic=true end
        end
    end
    -- Retain the avatar's skeletal connections so layered clothes follow bent legs.
    rigs[model]={root=root,joints=joints,r15=hum and hum.RigType==Enum.HumanoidRigType.R15}
    return model
end
function Characters.poseRider(model,seatCF,time,running,slide)
    local state=rigs[model];if not state then return end
    local s=slide or 0;local offsets={}
    local arm=-math.rad(52)-s*.3
    if state.r15 then
        for _,side in {'Left','Right'} do
            local sign=side=='Left' and -1 or 1
            offsets[side..'Hip']=CFrame.Angles(-.8,0,sign*.7)
            offsets[side..'Knee']=CFrame.Angles(1.15,0,0)
            offsets[side..'Ankle']=CFrame.Angles(-.2,0,0)
            offsets[side..'Shoulder']=CFrame.Angles(arm,0,sign*.16)
            offsets[side..'Elbow']=CFrame.Angles(-.55,0,0)
        end
        offsets.Waist=CFrame.Angles(-.12-s*.4,0,0)
        offsets.Neck=CFrame.Angles(.1+s*.55,0,0)
    else
        offsets['Left Hip']=CFrame.Angles(0,0,-1.05)
        offsets['Right Hip']=CFrame.Angles(0,0,1.05)
        offsets['Left Shoulder']=CFrame.Angles(0,0,-.85)
        offsets['Right Shoulder']=CFrame.Angles(0,0,.85)
        offsets.Neck=CFrame.Angles(s*.5,0,0)
    end
    local bob=running and math.sin(time*12)*.06*(1-s) or 0
    state.root.CFrame=seatCF*CFrame.new(0,1.45-s*.15+bob,.15)*CFrame.Angles(-s*1.05,0,0)
    for name,joint in state.joints do joint.Transform=offsets[name] or CFrame.identity end
end
function Characters.runnerAvatar(parent,character)
    local model=Characters.rider(parent,character)
    if model then
        model.Name='OwnerPursuer'
        model:SetAttribute('Role','OwnerPursuer')
    end
    return model
end

function Characters.poseRunner(model,groundCF,time,running,motion)
    local state=rigs[model];if not state then return end
    motion=motion or {}
    local dt=state.runTime and math.clamp(time-state.runTime,0,.1) or 0
    state.runTime=time;state.stride=(state.stride or 0)+(running and dt*(10+math.clamp((motion.speed or 32)/32,.5,2)*3) or 0)
    local swing=running and math.sin(state.stride) or 0
    local hum=model:FindFirstChildOfClass('Humanoid')
    local height=(hum and hum.HipHeight or 2)+state.root.Size.Y/2
    if not state.r15 then
        local leg=model:FindFirstChild('Left Leg');height+=leg and leg.Size.Y or 2
    end
    local offsets={}
    for _,side in {'Left','Right'} do
        local sign=side=='Left' and -1 or 1
        local step=swing*sign
        if state.r15 then
            offsets[side..'Hip']=CFrame.Angles(step*.75,0,0)
            offsets[side..'Knee']=CFrame.Angles(math.max(0,-step)*1.2,0,0)
            offsets[side..'Ankle']=CFrame.Angles(-math.max(0,-step)*.35,0,0)
            offsets[side..'Shoulder']=CFrame.Angles(-step*.75,0,sign*.08)
            offsets[side..'Elbow']=CFrame.Angles(-.8,0,0)
        else
            offsets[side..' Hip']=CFrame.Angles(0,0,-step*.7)
            offsets[side..' Shoulder']=CFrame.Angles(0,0,step*.8)
        end
    end
    local airborne=motion.height and motion.height>.1
    if airborne and state.r15 then
        offsets.LeftHip=CFrame.Angles(-.65,0,0);offsets.RightHip=CFrame.Angles(-.35,0,0)
        offsets.LeftKnee=CFrame.Angles(1,0,0);offsets.RightKnee=CFrame.Angles(.8,0,0)
    end
    local slide=motion.slide and 1 or 0
    state.root.CFrame=groundCF*CFrame.new(0,height+(motion.height or 0)+math.abs(swing)*.12-slide*.9,0)*CFrame.Angles(-.12-slide*.8,0,0)
    for name,joint in state.joints do joint.Transform=offsets[name] or CFrame.identity end
end
return Characters
