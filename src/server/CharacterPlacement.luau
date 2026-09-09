local Placement={}

function Placement.groundRootY(character,groundY)
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local hum=character and character:FindFirstChildOfClass('Humanoid')
    if not root or not hum then return groundY+4 end
    local lowest=0
    for _,part in character:GetDescendants() do
        if part:IsA('BasePart') and part.Transparency<1 then
            local localCF=root.CFrame:ToObjectSpace(part.CFrame)
            local half=part.Size*.5
            local extent=math.abs(localCF.XVector.Y)*half.X+math.abs(localCF.YVector.Y)*half.Y+math.abs(localCF.ZVector.Y)*half.Z
            lowest=math.min(lowest,localCF.Position.Y-extent)
        end
    end
    -- Leave a small clearance so shoes do not z-fight with the farm floor.
    return groundY-lowest+.05
end

function Placement.move(character,destination)
    local root=character:FindFirstChild('HumanoidRootPart')
    local hum=character:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 then return false end
    root.Anchored=true
    -- PivotOffset/accessories can put the model pivot below the actual root.
    local pivotToRoot=character:GetPivot():ToObjectSpace(root.CFrame)
    character:PivotTo(destination*pivotToRoot:Inverse())
    root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
    hum.Sit=false;hum.PlatformStand=false
    root.Anchored=false
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    return true
end

return Placement
