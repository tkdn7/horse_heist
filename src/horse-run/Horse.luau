local VisualRig=require(script.Parent.VisualRig)
local Characters=require(script.Parent.Characters)
local Horse={}
local states=setmetatable({},{__mode='k'})
local templates=script.Parent:WaitForChild('Horses')
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
function Horse.jumpBlend(progress)
    if progress==nil or progress<0 or progress>1 then return 0 end
    return math.min(smooth(progress/.15),smooth((1-progress)/.22))
end
-- Independent contacts: hind left, hind right, front left, front right.
local gait={
    {name='Left Hip',phase=0,side=-1,reach=.52},
    {name='Right Hip',phase=.18,side=1,reach=.56},
    {name='Left Shoulder',phase=.50,side=-1,reach=.64},
    {name='Right Shoulder',phase=.68,side=1,reach=.68},
}
function Horse.getNames()
    local names={};for _,m in templates:GetChildren() do if m:IsA('Model') then table.insert(names,m.Name) end end
    table.sort(names);return names
end
function Horse.clone(parent,name)
    local template=templates:FindFirstChild(name or '') or templates:FindFirstChild(Horse.getNames()[1] or '')
    assert(template,'No horse templates available')
    local model=template:Clone()
    local root=model:FindFirstChild('HumanoidRootPart',true) or model.PrimaryPart
    assert(root,'Horse template needs a root')
    model.PrimaryPart=root
    for _,d in model:GetDescendants() do
        if d:IsA('BaseScript') then d.Disabled=true
        elseif d:IsA('Humanoid') then
            d.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
            d.EvaluateStateMachine=false;d.AutoRotate=false
        end
    end
    local bottom=math.huge
    for _,d in model:GetDescendants() do
        if d:IsA('BasePart') and d.Transparency<1 then
            local cf=root.CFrame:ToObjectSpace(d.CFrame);local sz=d.Size*.5
            local extent=math.abs(cf.XVector.Y)*sz.X+math.abs(cf.YVector.Y)*sz.Y+math.abs(cf.ZVector.Y)*sz.Z
            bottom=math.min(bottom,cf.Y-extent)
        end
    end
    model.Parent=parent
    local rig=VisualRig.capture(model,root)
    local attachment=Instance.new('Attachment');attachment.Name='SlideDustAttachment';attachment.Parent=root
    local dust=Instance.new('ParticleEmitter');dust.Name='SlideDust';dust.Texture='rbxasset://textures/particles/smoke_main.dds'
    dust.Color=ColorSequence.new(Color3.fromRGB(203,180,137));dust.Lifetime=NumberRange.new(.2,.45)
    dust.Rate=35;dust.Speed=NumberRange.new(4,8);dust.SpreadAngle=Vector2.new(45,15);dust.EmissionDirection=Enum.NormalId.Back
    dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,2)})
    dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.65),NumberSequenceKeypoint.new(1,1)})
    dust.Enabled=false;dust.Parent=attachment
    states[model]={rig=rig,height=-bottom,seat=model:FindFirstChild('Seat',true),dust=dust,attachment=attachment,stride=0}
    return model
end
function Horse.mount(model,character)
    local state=states[model];if not state then return end
    if state.rider then state.rider:Destroy() end
    state.rider=Characters.rider(model,character)
    return state.rider
end
function Horse.pose(model,cf,time,running,motion)
    local state=states[model];if not state then return end
    motion=motion or {}
    local progress=motion.slideProgress
    local slide=progress and progress>=0 and progress<1 and math.min(smooth(progress/.14),smooth((1-progress)/.2)) or 0
    local jump=motion.jumpProgress
    local airborne=jump~=nil and jump>=0 and jump<=1
    -- Deliberately uncanny: rear legs become human legs and front legs reach up like arms.
    -- Reference: iJVQSGEETLQ (~3s), an animal standing vertically with human-like arms.
    -- Rise quickly, HOLD a full 90-degree stand through flight, then settle onto four feet.
    local humanJump=Horse.jumpBlend(jump)
    local dt=state.time and math.clamp(time-state.time,0,.1) or 0;state.time=time
    -- A second jump restarts the trajectory, but must not snap a standing horse flat.
    if airborne and (motion.jumpCount or 1)>1 then
        humanJump=math.max(humanJump,(state.jumpBlend or 0)-dt*5)
    end
    state.jumpBlend=humanJump
    -- Integrate cadence so acceleration never changes the phase discontinuously.
    if running then state.stride+=dt*(8.5+math.clamp((motion.speed or 16)/32,0,2)*3.5) end
    local t=state.stride;local offsets={}
    local active=running and not airborne and 1-slide or 0
    -- Sweep backward while planted, then lift and recover faster through the air.
    -- Keep the original sculpted limbs visible. Bending them requires a skinned asset.
    for _,leg in gait do
        local cycle=(t/(2*math.pi)-leg.phase)%1
        local stance=.56
        local angle,lift
        if cycle<stance then
            angle=-leg.reach+2*leg.reach*(cycle/stance)
            lift=0
        else
            local recovery=(cycle-stance)/(1-stance)
            angle=leg.reach-2*leg.reach*smooth(recovery)
            lift=math.sin(recovery*math.pi)*.28
        end
        local tuck=airborne and math.sin(math.pi*jump)*.65 or 0
        offsets[leg.name]=CFrame.new(0,lift*active,0)*CFrame.Angles(angle*active-tuck,0,leg.side*slide*1.3)
        if airborne then
            local front=leg.name:find('Shoulder')~=nil
            local knee=front and -.18 or (.22+leg.side*.12)*math.sin(math.pi*jump)
            offsets[leg.name]=CFrame.Angles((-math.pi/2+knee)*humanJump,0,leg.side*(front and 1.05 or .12)*humanJump)
        end
    end
    local bob=(1-math.cos(t-1.1))*.07*active
    local pitch=math.sin(t-.6)*.035*active+math.pi/2*humanJump
    offsets['Upper Spine']=CFrame.Angles(0,0,math.sin(t-.4)*.035*active)
    offsets.Neck=CFrame.Angles(0,0,-math.sin(t-.4)*.04*active)
    offsets['Lower Spine']=CFrame.Angles(.05,math.sin(t*.65)*.12,0)
    local scale=Vector3.new(1+slide*.58,1-slide*.76,1+slide*.16)
    local rootCF=cf*CFrame.new(0,state.height*scale.Y+2*humanJump+bob-(motion.landing or 0)*.15,0)
        *CFrame.Angles(pitch,0,-math.clamp(motion.lean or 0,-1,1)*.055*(1-slide))
    VisualRig.pose(state.rig,rootCF,offsets,scale)
    state.attachment.Position=Vector3.new(0,-state.height*scale.Y+.35,2.5)
    state.dust.Enabled=slide>.2
    model:SetAttribute('SlideBlend',slide)
    model:SetAttribute('UprightJumpBlend',humanJump)
    if state.rider then
        local seatCF=state.seat and state.seat.CFrame or rootCF*CFrame.new(0,-.5,0)
        Characters.poseRider(state.rider,seatCF,time,running,slide)
    end
end
function Horse.clear(model)
    if model then states[model]=nil;model:Destroy() end
end
function Horse.create(parent,rider) return Horse.clone(parent) end
return Horse
