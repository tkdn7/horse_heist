local Placement={}

function Placement.clearance(character)
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local hum=character and character:FindFirstChildOfClass('Humanoid')
    if not root or not hum then return 4 end
    local height=root.Size.Y*.5+hum.HipHeight
    if hum.RigType==Enum.HumanoidRigType.R6 then
        local leg=character:FindFirstChild('Left Leg')
        height+=leg and leg.Size.Y or 2
    end
    return math.max(4,height+.75)
end

function Placement.move(character,destination)
    local root=character:FindFirstChild('HumanoidRootPart')
    local hum=character:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 then return false end
    root.Anchored=true
    -- PivotOffset/accessories can put the model pivot below the actual root.
    local rootToPivot=root.CFrame:ToObjectSpace(character:GetPivot())
    character:PivotTo(destination*rootToPivot)
    root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
    hum.Sit=false;hum.PlatformStand=false
    root.Anchored=false
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    return true
end

return Placement
