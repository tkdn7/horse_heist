-- Studio server only. Uses disposable rigs; no ownership or currency writes.
return function()
    local RS=game.ReplicatedStorage
    local Placement=require(game.ServerScriptService.Server.CharacterPlacement)
    local Characters=require(RS.HorseRun.Characters)
    local Rarity=require(RS.Shared.HorseRarity)
    local Chase=require(RS.Shared.ChaseConfig)
    local Runner=require(RS.HorseRun.Runner)
    local SlotLifecycle=require(game.ServerScriptService.Server.NpcSlotLifecycle)
    local results={}
    assert(Chase.StealHoldSeconds==2)
    for _,rarity in Rarity.Definitions do assert(rarity.StealHoldSeconds==2) end
    for _,prompt in workspace:GetDescendants() do
        if prompt:IsA('ProximityPrompt') and (prompt.Name=='StealPrompt' or prompt.Name=='PlayerStealPrompt') then
            assert(prompt.HoldDuration==2,prompt:GetFullName())
            if prompt.Name=='PlayerStealPrompt' then assert(type(prompt:GetAttribute('OwnerUserId'))=='number') end
        end
    end
    table.insert(results,'All rarities and active theft prompts hold for 2 seconds')

    assert(Chase.SlotRefillSeconds==60)
    local slot=Instance.new('Model');slot:SetAttribute('Occupied',true);slot:SetAttribute('LockedBy',123)
    local pad=Instance.new('Part');pad.Name='DisplayPad';pad.Parent=slot
    local prompt=Instance.new('ProximityPrompt');prompt.Name='StealPrompt';prompt.Parent=pad
    local horse=Instance.new('Model');horse.Name='DisplayHorse';horse.Parent=slot
    local effects=Instance.new('Folder');effects.Name='RarityEffects';effects.Parent=slot
    local refillAt=assert(SlotLifecycle.beginCooldown(slot,100,Chase.SlotRefillSeconds))
    assert(refillAt==160 and slot:GetAttribute('Occupied')==false and slot:GetAttribute('LockedBy')==nil)
    assert(slot:GetAttribute('CooldownUntil')==160 and not slot:FindFirstChild('DisplayHorse') and not pad:FindFirstChild('StealPrompt'))
    assert(SlotLifecycle.remaining(refillAt,100)==60 and SlotLifecycle.remaining(refillAt,159.2)==1 and SlotLifecycle.remaining(refillAt,161)==0)
    assert(SlotLifecycle.beginCooldown(slot,100,60)==nil,'An empty slot restarted its cooldown')
    slot:Destroy()
    table.insert(results,'Every resolved NPC theft consumes the horse and starts one 60-second slot cooldown')

    for _,rigType in {Enum.HumanoidRigType.R6,Enum.HumanoidRigType.R15} do
        local rig=Instance.new('Model')
        local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Size=Vector3.new(2,2,1)
        root.CFrame=CFrame.new(100,120,100);root.PivotOffset=CFrame.new(0,-8,0);root.Parent=rig;rig.PrimaryPart=root
        local hum=Instance.new('Humanoid');hum.RequiresNeck=false;hum.RigType=rigType;hum.HipHeight=rigType==Enum.HumanoidRigType.R15 and 5 or 0;hum.Parent=rig
        if rigType==Enum.HumanoidRigType.R6 then
            local leg=Instance.new('Part');leg.Name='Left Leg';leg.Size=Vector3.new(1,4,1);leg.Parent=rig
        end
        local destination=CFrame.new(0,Placement.groundRootY(rig,0),0)*CFrame.Angles(0,1,0)
        assert(Placement.move(rig,destination))
        assert((root.Position-destination.Position).Magnitude<.001,'Model pivot buried the root')
        assert(root.Position.Y>=.05,'Scaled avatar clearance is too short')
        assert(not root.Anchored and root.AssemblyLinearVelocity==Vector3.zero)
        rig:Destroy()
    end
    table.insert(results,'R6/R15 scaled rigs and displaced model pivots return with root above ground')

    local folder=Instance.new('Folder')
    local farmer=Characters.farmer(folder)
    local normal=farmer.Head.Color
    local normalSize=farmer.Head.Size
    local count=#farmer:GetChildren();Characters.equipFarmer(farmer);assert(#farmer:GetChildren()==count)
    local hand=farmer:FindFirstChild('Hand1');local cuff=farmer:FindFirstChild('PitchforkHandle')
    local held
    for i=1,4 do
        Characters.poseFarmer(farmer,CFrame.new(10,0,10),i*.2,true,true)
        local relative=hand.CFrame:ToObjectSpace(cuff.CFrame)
        if held then assert((relative.Position-held.Position).Magnitude<.001,'Pitchfork detached from animated hand') end
        held=relative
        assert(math.abs(cuff.CFrame.UpVector.Y)<.25,'Pitchfork is not horizontal')
        assert(farmer.Head.Color==Color3.fromRGB(245,64,48))
    end
    Characters.poseFarmer(farmer,CFrame.identity,1,false,false)
    assert(farmer.Head.Color==normal,'Calm face did not restore')
    assert((farmer.Head.Size-normalSize).Magnitude<.001,'Calm head size did not restore')
    Characters.poseFarmer(farmer,CFrame.identity,0,false,true,.45)
    assert((farmer.Head.Size-normalSize*1.35).Magnitude<.001,'Angry head did not inflate')
    assert((farmer.StrawHat.Size-farmer.StrawHat:GetAttribute('FarmerRestSize')*1.35).Magnitude<.001,'Hat left behind by head scaling')
    local swollen=farmer:Clone();swollen.Parent=folder
    Characters.poseFarmer(swollen,CFrame.identity,0,false,false)
    assert((swollen.Head.Size-normalSize).Magnitude<.001,'Cloning a swollen head compounded its scale')
    Characters.poseFarmer(farmer,CFrame.identity,0,false,true,.9)
    assert((farmer.Head.Size-normalSize).Magnitude<.001,'Angry head did not return between pulses')
    local saved=farmer:Clone();saved.Parent=folder
    Characters.poseFarmer(saved,CFrame.new(15,0,0),.3,true,true)
    assert(saved:FindFirstChild('PitchforkTine4') and saved.Head.Color==Color3.fromRGB(245,64,48))
    folder:Destroy()
    table.insert(results,'Horizontal pitchfork stays in hand; head and hat pulse 1–1.35x, return to rest, and survive cloning without scale drift')

    for _,speed in {24,32,53} do
        local run=Runner.new({mode='Chase',speed=speed})
        assert(Runner.pursuerSpeed(run,0)==speed and Runner.pursuerSpeed(run,1000)==speed)
    end
    table.insert(results,'Minigame pursuer has no elapsed-time acceleration at any horse tier')
    return results
end
