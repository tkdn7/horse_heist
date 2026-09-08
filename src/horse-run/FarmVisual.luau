local Horse=require(script.Parent.Horse)
local Characters=require(script.Parent.Characters)
local FarmVisual={}
local cream=Color3.fromRGB(240,225,191)
local wood=Color3.fromRGB(105,75,48)
function FarmVisual.part(parent,name,size,cf,color,material)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
    p.Anchored=true;p.Material=material or Enum.Material.WoodPlanks;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local part=FarmVisual.part
function FarmVisual.label(parent,text,cf,width,height)
    local board=part(parent,'Sign',Vector3.new(width,height,.3),cf,Color3.fromRGB(37,65,53))
    for _,face in {Enum.NormalId.Front,Enum.NormalId.Back} do
        local ui=Instance.new('SurfaceGui',board);ui.Face=face;ui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;ui.PixelsPerStud=30
        local t=Instance.new('TextLabel',ui);t.Size=UDim2.fromScale(.94,.9);t.Position=UDim2.fromScale(.03,.05);t.BackgroundTransparency=1
        t.Text=text;t.TextScaled=true;t.Font=Enum.Font.GothamBold;t.TextColor3=cream
    end
    return board
end
function FarmVisual.playerBase(index)
    local column=(index-1)%2;local row=math.floor((index-1)/2)
    -- The gate is on local +Z. Turn both banks inward toward the central road.
    return CFrame.new(column==0 and -118 or 118,0,125+row*170)
        *CFrame.Angles(0,column==0 and math.pi/2 or -math.pi/2,0)
end
function FarmVisual.slot(base,index)
    local column=(index-1)%6;local row=math.floor((index-1)/6)
    return base*CFrame.new((column-2.5)*16,.65,-23+row*27)
end
function FarmVisual.npcSlot(index)
    return CFrame.new(((index-1)%3-1)*36,.65,-220+math.floor((index-1)/3)*37)
end
local function fence(parent,base,width,depth)
    for _,side in {-1,1} do
        for z=-depth/2,depth/2,10 do part(parent,'FencePost',Vector3.new(.7,4,.7),base*CFrame.new(side*width/2,2,z),cream) end
        for _,y in {1.4,2.9} do part(parent,'FenceRail',Vector3.new(.4,.45,depth),base*CFrame.new(side*width/2,y,0),cream) end
        for x=-width/2,width/2,10 do
            if side==-1 or math.abs(x)>13 then part(parent,'FencePost',Vector3.new(.7,4,.7),base*CFrame.new(x,2,side*depth/2),cream) end
        end
        for _,y in {1.4,2.9} do
            if side==-1 then part(parent,'FenceRail',Vector3.new(width,.45,.4),base*CFrame.new(0,y,-depth/2),cream)
            else for _,s in {-1,1} do part(parent,'FenceRail',Vector3.new(width/2-13,.45,.4),base*CFrame.new(s*(width/4+6.5),y,depth/2),cream) end end
        end
    end
end
local function barn(parent,base,width,depth,color)
    part(parent,'BarnBack',Vector3.new(width,15,1),base*CFrame.new(0,7.5,-depth/2),color)
    for _,s in {-1,1} do
        part(parent,'BarnWall',Vector3.new(1,15,depth),base*CFrame.new(s*width/2,7.5,0),color)
        part(parent,'RoofSlope',Vector3.new(width/2+3,1,depth+5),base*CFrame.new(s*width/4,17,0)*CFrame.Angles(0,0,-s*.11),Color3.fromRGB(49,65,65),Enum.Material.Slate)
    end
    part(parent,'RoofRidge',Vector3.new(2,1,depth+5),base*CFrame.new(0,18.7,0),wood)
    part(parent,'BarnHeader',Vector3.new(width,1.4,1.2),base*CFrame.new(0,14,depth/2),cream)
    for x=-width/2,width/2,16 do part(parent,'BarnPost',Vector3.new(.8,14,.8),base*CFrame.new(x,7,depth/2),cream) end
    part(parent,'StableFloor',Vector3.new(width,.3,depth),base*CFrame.new(0,.2,0),Color3.fromRGB(161,139,104),Enum.Material.Cobblestone)
end
function FarmVisual.player(farm,base,name)
    local arch=Instance.new('Folder',farm);arch.Name='Architecture'
    part(arch,'Plot',Vector3.new(122,.6,134),base*CFrame.new(0,-.2,0),Color3.fromRGB(106,150,83),Enum.Material.Grass)
    fence(arch,base,120,132)
    barn(arch,base*CFrame.new(0,0,-14),100,63,Color3.fromRGB(85,127,124))
    FarmVisual.label(arch,name..'의 마구간',base*CFrame.new(0,12,18),27,3)
    part(arch,'Courtyard',Vector3.new(106,.25,39),base*CFrame.new(0,.24,42),Color3.fromRGB(203,181,140),Enum.Material.Ground)
    -- Join the courtyard through the centered 26-stud gate to the road edge (X = +/-19).
    part(arch,'EntrancePath',Vector3.new(24,.22,39),base*CFrame.new(0,.25,80.5),Color3.fromRGB(193,170,129),Enum.Material.Ground)
    for i=1,12 do
        local cf=FarmVisual.slot(base,i)
        for _,x in {-7.7,7.7} do part(arch,'StallDivider',Vector3.new(.35,3.2,18),cf*CFrame.new(x,1.6,0),wood) end
        part(arch,'HayBale',Vector3.new(3,2,2),cf*CFrame.new(-5,1,-6),Color3.fromRGB(210,173,79),Enum.Material.Grass)
    end
    FarmVisual.label(arch,'개인 농장 · 말 12마리 전시',base*CFrame.new(0,9,65),26,3).Name='EntranceSign'
    local spawn=part(arch,'HomePoint',Vector3.one,base*CFrame.new(0,4,43),cream);spawn.Transparency=1;spawn.CanCollide=false
end
function FarmVisual.alignPlayer(farm,base)
    local arch=farm:FindFirstChild('Architecture')
    local home=arch and arch:FindFirstChild('HomePoint')
    if not home then return end
    -- Existing generated farms may be saved in the Place. Move their geometry together.
    local previousBase=home.CFrame*CFrame.new(0,-4,-43)
    local delta=base*previousBase:Inverse()
    if (previousBase.Position-base.Position).Magnitude>.01 or previousBase.ZVector:Dot(base.ZVector)<.9999 then
        for _,p in arch:GetDescendants() do
            if p:IsA('BasePart') then p.CFrame=delta*p.CFrame end
        end
    end
    if not arch:FindFirstChild('EntrancePath') then
        part(arch,'EntrancePath',Vector3.new(24,.22,39),base*CFrame.new(0,.25,80.5),Color3.fromRGB(193,170,129),Enum.Material.Ground)
    end
    for _,p in arch:GetChildren() do
        if p:IsA('BasePart') and p.Name=='Sign' then
            local localPosition=base:PointToObjectSpace(p.Position)
            if math.abs(localPosition.Z-65)<.1 and math.abs(localPosition.Y-5)<.1 then
                p.CFrame+=Vector3.new(0,4,0);p.Name='EntranceSign'
            end
        end
    end
    farm:SetAttribute('LayoutVersion',4)
end
function FarmVisual.alignRoad(world)
    if world:GetAttribute('LayoutVersion')==4 then return end
    -- Only the named generated cross streets change; keep all other saved map content.
    for _,p in world:GetChildren() do
        if p:IsA('BasePart') and p.Name=='FarmLane' then
            local row=math.max(0,math.floor((p.Position.Z-168)/170+.5))
            p.Size=Vector3.new(200,.22,20)
            p.CFrame=CFrame.new(0,.16,125+row*170)
        end
    end
    world:SetAttribute('LayoutVersion',4)
end
function FarmVisual.npc(farm)
    if farm:FindFirstChild('Architecture') then return end
    local arch=Instance.new('Folder',farm);arch.Name='Architecture'
    local base=CFrame.new(0,0,-215)
    part(arch,'RanchGround',Vector3.new(182,.6,150),base*CFrame.new(0,-.2,0),Color3.fromRGB(150,150,86),Enum.Material.Grass)
    fence(arch,base,180,148)
    barn(arch,base*CFrame.new(0,0,-43),122,51,Color3.fromRGB(156,57,43))
    FarmVisual.label(arch,'농장주의 목장',CFrame.new(0,12,-231),35,4)
    part(arch,'Paddock',Vector3.new(134,.25,78),CFrame.new(0,.25,-202),Color3.fromRGB(182,150,99),Enum.Material.Ground)
    for _,x in {-14,14} do part(arch,'EntryPillar',Vector3.new(1.8,12,1.8),CFrame.new(x,6,-140),wood) end
    FarmVisual.label(arch,'말을 훔치고 추격을 따돌리세요!',CFrame.new(0,10,-140),30,3)
    local silo=part(arch,'GrainSilo',Vector3.new(27,17,17),CFrame.new(74,13.5,-262)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(160,169,168),Enum.Material.Metal)
    silo.Shape=Enum.PartType.Cylinder
    for i=1,6 do part(arch,'HayBale',Vector3.new(5,3,4),CFrame.new(-74+(i%2)*6,1.5,-262+math.floor(i/2)*5),Color3.fromRGB(211,172,74),Enum.Material.Grass) end
    local farmer=Characters.farmer(arch);Characters.poseFarmer(farmer,CFrame.new(19,.5,-151)*CFrame.Angles(0,math.pi,0),0,false)
end
function FarmVisual.display(parent,name,template,cf)
    local model=Horse.clone(parent,template);model.Name=name
    Horse.pose(model,cf*CFrame.new(0,.55,0)*CFrame.Angles(0,math.pi,0),0,false)
    return model
end
function FarmVisual.rarity(parent,model,pad,rarity)
    local old=parent:FindFirstChild('RarityEffects');if old then old:Destroy() end
    local effects=Instance.new('Folder',parent);effects.Name='RarityEffects'
    local rank=({Bronze=1,Silver=2,Gold=3,Champion=4,Royal=5,Legend=6})[rarity.Id] or 1
    local ring=part(effects,'RarityRing',Vector3.new(.12,12,12),pad.CFrame*CFrame.new(0,.6,0)*CFrame.Angles(0,0,math.pi/2),rarity.Color,Enum.Material.Neon)
    ring.Shape=Enum.PartType.Cylinder;ring.CanCollide=false;ring.Transparency=.65
    local highlight=Instance.new('Highlight',effects);highlight.Adornee=model;highlight.FillColor=rarity.Color;highlight.FillTransparency=.96
    highlight.OutlineColor=rarity.Color;highlight.OutlineTransparency=rank<3 and .65 or .2;highlight.DepthMode=Enum.HighlightDepthMode.Occluded
    local attachment=Instance.new('Attachment',ring)
    local glow=Instance.new('ParticleEmitter',attachment);glow.Name='RaritySparkles';glow.Texture='rbxasset://textures/particles/sparkles_main.dds'
    glow.Color=ColorSequence.new(rarity.Color);glow.LightEmission=.8;glow.Rate=({1,3,7,12,18,26})[rank]
    glow.Lifetime=NumberRange.new(1,2);glow.Speed=NumberRange.new(1,3);glow.SpreadAngle=Vector2.new(180,180)
    glow.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12+rank*.04),NumberSequenceKeypoint.new(1,0)})
    glow.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)})
    if rank>=4 then
        for i=1,rank-2 do
            local angle=i*math.pi*2/(rank-2)
            local gem=part(effects,'RarityGem',Vector3.new(.6,.6,.6),pad.CFrame*CFrame.new(math.cos(angle)*5.7,1.8,math.sin(angle)*5.7)*CFrame.Angles(.6,0,.6),rarity.Color,Enum.Material.Neon)
            gem.CanCollide=false
        end
    end
end
function FarmVisual.world()
    local world=Instance.new('Model');world.Name='HorseRunWorld';world:SetAttribute('LayoutVersion',4)
    part(world,'Meadow',Vector3.new(900,1,1600),CFrame.new(0,-.6,340),Color3.fromRGB(110,151,84),Enum.Material.Grass)
    part(world,'VillageRoad',Vector3.new(38,.2,1360),CFrame.new(0,.1,390),Color3.fromRGB(193,170,129),Enum.Material.Ground)
    part(world,'VillageSquare',Vector3.new(168,.22,96),CFrame.new(0,.14,-37),Color3.fromRGB(186,170,141),Enum.Material.Cobblestone)
    for row=0,5 do part(world,'FarmLane',Vector3.new(200,.22,20),CFrame.new(0,.16,125+row*170),Color3.fromRGB(191,170,132),Enum.Material.Ground) end
    FarmVisual.label(world,'HORSE HEIST\n↑ 농장주의 목장   |   개인 농장 ↓',CFrame.new(0,9,-102),40,6)
    for _,x in {-23,23} do part(world,'Waypost',Vector3.new(1,12,1),CFrame.new(x,6,-102),wood) end
    local gate=part(world,'StartGate',Vector3.new(16,.3,12),CFrame.new(-52,.4,-40),Color3.fromRGB(198,167,91),Enum.Material.Sand)
    local prompt=Instance.new('ProximityPrompt',gate);prompt.ActionText='연습 달리기';prompt.ObjectText='연습 트랙';prompt.RequiresLineOfSight=false;prompt.MaxActivationDistance=12
    FarmVisual.label(world,'연습 트랙',CFrame.new(-52,6,-49),20,3)
    local training=part(world,'TrainingPad',Vector3.new(18,.3,14),CFrame.new(52,.4,-40),Color3.fromRGB(166,183,137),Enum.Material.Sand)
    local tp=Instance.new('ProximityPrompt',training);tp.ActionText='훈련하기';tp.ObjectText='속도 · 체력';tp.RequiresLineOfSight=false;tp.MaxActivationDistance=12
    FarmVisual.label(world,'훈련장',CFrame.new(52,6,-49),20,3)
    for i=1,42 do
        local side=i%2==0 and -1 or 1;local x=side*(208+(i%3)*25);local z=-315+math.floor(i/2)*65
        part(world,'TreeTrunk',Vector3.new(2,8,2),CFrame.new(x,4,z),wood,Enum.Material.Wood)
        local canopy=part(world,'TreeCrown',Vector3.new(15,18,15),CFrame.new(x,15,z),Color3.fromRGB(55+(i%3)*9,106+(i%3)*12,62),Enum.Material.Grass);canopy.Shape=Enum.PartType.Ball
    end
    -- Finish constructing the replacement before preserving the old generated map.
    local old=workspace:FindFirstChild('HorseRunWorld')
    if old then
        local storage=game:GetService('ServerStorage')
        local backups=storage:FindFirstChild('CodexBackups') or Instance.new('Folder',storage);backups.Name='CodexBackups'
        local archive=Instance.new('Folder',backups);archive.Name='PreviousHorseRunWorld_'..tostring(DateTime.now().UnixTimestampMillis)
        old.Parent=archive
    end
    world.Parent=workspace
    return world
end
return FarmVisual
