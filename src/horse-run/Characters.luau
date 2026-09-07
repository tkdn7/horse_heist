local VisualRig=require(script.Parent.VisualRig)
local Characters={}
local rigs=setmetatable({},{__mode='k'})
local function part(parent,name,size,cf,color)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Anchored=true
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
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
    m.Parent=parent
    local rest={};for _,p in m:GetChildren() do if p:IsA('BasePart') then rest[p]=p.CFrame end end
    rigs[m]={rest=rest};return m
end
function Characters.poseFarmer(model,cf,time,running)
    local state=rigs[model];if not state then return end
    local phase=time*13;local bounce=running and math.abs(math.sin(phase))*.22 or 0
    for p,rest in state.rest do
        local offset=rest
        for _,side in {-1,1} do
            local swing=running and math.sin(phase)*side*.8 or 0
            if p.Name=='Leg'..side or p.Name=='Boot'..side then
                offset=CFrame.new(side*.57,2.1,0)*CFrame.Angles(swing,0,0)*CFrame.new(-side*.57,-2.1,0)*rest
            elseif p.Name=='Arm'..side or p.Name=='Hand'..side then
                offset=CFrame.new(side*1.52,4.1,0)*CFrame.Angles(-swing-.25,0,side*.1)*CFrame.new(-side*1.52,-4.1,0)*rest
            end
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
return Characters
