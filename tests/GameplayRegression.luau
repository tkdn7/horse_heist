-- Run in Studio's test session with ReplicatedStorage.HorseRun available.
-- Creates only unparented fixtures; does not award horses, currency, or write saves.
return function()
    local shared=game:GetService('ReplicatedStorage'):WaitForChild('HorseRun')
    local Farm=require(shared.FarmVisual)
    local Horse=require(shared.Horse)
    local Runner=require(shared.Runner)
    local Course=require(shared.Course)
    local passed={}
    local function near(a,b) return (a-b).Magnitude<.01 end

    for index=1,12 do
        local base=Farm.playerBase(index)
        local gate=base:PointToWorldSpace(Vector3.new(0,0,66))
        local road=Vector3.new(0,0,gate.Z)
        assert(base.ZVector:Dot((road-gate).Unit)>.999,'Farm gate must face road')
        assert(math.abs(gate.Z-(125+math.floor((index-1)/2)*170))<.01,'Gate must align with cross street')
        for slot=1,12 do
            local p=base:PointToObjectSpace(Farm.slot(base,slot).Position)
            assert(math.abs(p.X)<=40.01 and p.Z>=-23.01 and p.Z<=4.01,'Display left barn')
        end
    end
    table.insert(passed,'12 farm positions and 144 display slots face/align with road')

    local fixture=Instance.new('Model')
    local oldBase=CFrame.new(-118,0,125)
    Farm.player(fixture,oldBase,'Test')
    local count=#fixture:GetDescendants()
    local oldHome=fixture.Architecture.HomePoint
    local base=Farm.playerBase(1)
    Farm.alignPlayer(fixture,base)
    local first=oldHome.CFrame
    Farm.alignPlayer(fixture,base)
    assert(fixture.Architecture.HomePoint==oldHome,'Migration replaced existing objects')
    assert(#fixture:GetDescendants()==count,'Migration duplicated architecture')
    assert(near(first.Position,(base*CFrame.new(0,4,43)).Position),'Home did not rotate')
    assert(near(first.Position,oldHome.Position),'Repeated migration moved farm')
    local path=fixture.Architecture.EntrancePath
    local edge=path.CFrame:PointToWorldSpace(Vector3.new(0,0,path.Size.Z/2))
    assert(math.abs(edge.X)<=19.01,'Entrance path does not reach road')
    assert(fixture.Architecture.EntranceSign.Position.Y-fixture.Architecture.EntranceSign.Size.Y/2>7,'Sign blocks entrance')
    fixture:Destroy()
    table.insert(passed,'Saved farm migration preserves instances and is idempotent; gate clearance/path valid')

    for _,rowLength in {36,80} do
        local settings={rowLength=rowLength}
        local run=Runner.new({course=settings,maxHealth=1000})
        local counts={}
        while run.distance<90 do
            run.lane=Course.row(0,settings).safe
            run.laneFrom=run.lane*8
            for _,event in Runner.step(run,.1) do
                if event.kind=='Carrot' then counts[event.id]=(counts[event.id] or 0)+1 end
            end
        end
        assert(counts['0:a']==1 and counts['0:b']==1,'Carrot reward must occur exactly once')
    end
    table.insert(passed,'Normal and widened courses award each passed carrot once')

    local run=Runner.new()
    assert(Runner.input(run,'Left'))
    Runner.step(run,.04)
    assert(not Runner.input(run,'Right'),'Turn cooldown lost')
    Runner.step(run,.06)
    local before=Runner.xAt(run,run.elapsed)
    assert(Runner.input(run,'Right'))
    assert(math.abs(Runner.xAt(run,run.elapsed)-before)<.001,'Rapid reversal teleported horse')
    assert(Runner.input(run,'Jump'))
    assert(not Runner.input(run,'Jump'),'Jump cooldown lost')
    table.insert(passed,'Rapid turn reversal is continuous; turn and jump cooldowns retained')

    local parent=Instance.new('Folder')
    for _,name in Horse.getNames() do
        local model=Horse.clone(parent,name)
        local parts={}
        for _,partName in {'Left Leg','Right Leg','Left Arm','Right Arm'} do
            parts[#parts+1]=assert(model:FindFirstChild(partName,true))
        end
        local differences={0,0,0}
        local minHeight,maxHeight=math.huge,-math.huge
        for frame=0,90 do
            Horse.pose(model,CFrame.identity,frame/60,true,{speed=16})
            local body=model:FindFirstChild('Body',true)
            minHeight=math.min(minHeight,body.Position.Y)
            maxHeight=math.max(maxHeight,body.Position.Y)
            for i=2,4 do
                differences[i-1]=math.max(differences[i-1],(parts[1].CFrame.LookVector-parts[i].CFrame.LookVector).Magnitude)
            end
        end
        for _,value in differences do assert(value>.25,name..' legs move in unison') end
        assert(maxHeight-minHeight<.25,'Body bounce is excessive')
        local size=parts[1].Size
        Horse.pose(model,CFrame.identity,1.6,true,{slideProgress=.5})
        assert(model:GetAttribute('SlideBlend')>.9,'Slide flattening lost')
        Horse.pose(model,CFrame.identity,1.7,false)
        assert(near(parts[1].Size,size),'Leg size not restored after sliding')
        Horse.clear(model)
    end
    parent:Destroy()
    table.insert(passed,'All horse templates: distinct leg phases, limited bounce, slide restoration')
    return passed
end
