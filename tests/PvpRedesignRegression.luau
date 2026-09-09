-- Local Studio server test; disposable fixtures only, no real ownership/currency writes.
return function()
    local RS=game.ReplicatedStorage
    local Rules=require(RS.Shared.PursuitRules)
    local Runner=require(RS.HorseRun.Runner)
    local Course=require(RS.HorseRun.Course)
    local Horse=require(RS.HorseRun.Horse)
    local Legs=require(RS.HorseRun.HorseLegs)
    local Characters=require(RS.HorseRun.Characters)
    local Farm=require(game.ServerScriptService.Server.PlayerFarm)
    local results={}
    local traits={Speed=42,Stamina=138,Ability='SpeedBoost'}
    local course={seed=5,rowLength=64}
    local a=Runner.new(Rules.stats(traits,0,course,false))
    local b=Runner.new(Rules.stats(traits,-28,course,false))
    assert(a.baseSpeed==b.baseSpeed and a.maxHealth==b.maxHealth and a.ability==b.ability)
    assert(Runner.input(a,'Ability') and Runner.input(b,'Ability'))
    Runner.step(a,.1);Runner.step(b,.1)
    assert(a.speed==b.speed and a.abilityReadyAt==b.abilityReadyAt)
    for _,ability in {'DoubleJump','BreakObstacle'} do
        local values={Speed=42,Stamina=138,Ability=ability}
        local x=Runner.new(Rules.stats(values,0,course,false));local y=Runner.new(Rules.stats(values,-28,course,false))
        assert(x.ability==y.ability)
    end
    table.insert(results,'Both roles receive identical horse speed, stamina, ability and cooldowns')

    local function collect(run,miss)
        local row=Course.row(0,course)
        for _,carrot in row.carrots do
            run.distance=carrot.distance-1
            run.lane=miss and (carrot.lane==1 and -1 or 1) or carrot.lane
            run.laneFrom=run.lane*8;run.laneAt=run.elapsed-10
            Runner.step(run,.1)
        end
        Runner.step(run,.01)
    end
    local good=Runner.new(Rules.stats(traits,0,course,false))
    local bad=Runner.new(Rules.stats(traits,0,course,false))
    collect(good,false);collect(bad,true)
    assert(good.carrots==2 and good.missedCarrots==0 and good.speed==42)
    assert(bad.carrots==0 and bad.missedCarrots==2 and math.abs(bad.speed-42*.92)<.001)
    assert(Rules.pace(1000)==.6 and Rules.pace(0)==1)
    local legacy=Runner.new({speed=42});collect(legacy,true);assert(legacy.speed==42 and legacy.missedCarrots==0)
    local npc=Runner.new(Rules.stats(traits,0,{rowLength=100000},true));npc.distance=200;npc.pursuerGap=5;npc.missedCarrots=6
    for _=1,100 do Runner.step(npc,.1) end
    assert(npc.done and npc.outcome=='Captured','Missing carrots must let a constant-speed NPC catch up')
    table.insert(results,'Collected carrots retain speed; each miss reduces 4%, floor 60%; misses cause capture; normal mode unaffected')

    local fixtures={}
    local ok,err=pcall(function()
        for i=1,2 do
            local p=Instance.new('Player');p.UserId=-991120-i;p.Name='ProtectionFixture'..i
            local data={Horses={{Id='fixture-'..i,TemplateId='Horse1',RarityId='Gold',Placed=true,ProtectedUntil=0},
                {Id='protected-'..i,TemplateId='Horse2',RarityId='Silver',Placed=true,ProtectedUntil=os.time()+300}}}
            table.insert(fixtures,p)
            local farm=Farm.render(p,data)
            assert(Farm.protectForTheft(p,'match-A'))
            assert(not Farm.protectForTheft(p,'match-B'),'Overlapping theft lock allowed')
            Farm.render(p,data)
            for _,prompt in farm:GetDescendants() do
                if prompt:IsA('ProximityPrompt') and prompt.Name=='PlayerStealPrompt' then
                    assert(not prompt.Enabled and prompt.Parent:GetAttribute('FarmTheftProtected'))
                end
            end
            Farm.releaseTheftProtection(p,'match-B');assert(p:GetAttribute('FarmTheftEvent')=='match-A')
            Farm.releaseTheftProtection(p,'match-A');assert(p:GetAttribute('FarmTheftEvent')==nil)
            assert(farm.Displays.Stall1.Slot1.PlayerStealPrompt.Enabled)
            assert(not farm.Displays.Stall2.Slot2.PlayerStealPrompt.Enabled,'Existing protection lost on unlock')
        end
    end)
    for _,p in fixtures do Farm.remove(p);p:Destroy() end
    assert(ok,tostring(err))
    table.insert(results,'Both farms fully locked across re-render; competing event rejected; token-safe unlock preserves existing horse protection')

    local folder=Instance.new('Folder')
    for _,name in Horse.getNames() do
        local original=RS.HorseRun.Horses:FindFirstChild(name)
        local count=#original:GetDescendants()
        local horse=Horse.clone(folder,name)
        assert(horse:GetAttribute('ArticulatedLegCount')==4)
        for _,jointName in {'Left Hip','Right Hip','Left Shoulder','Right Shoulder'} do
            local lower=horse:FindFirstChild(jointName..' Lower')
            local upper=horse:FindFirstChild(jointName..' Upper')
            local knee=upper:FindFirstChild(jointName..' Knee')
            local min,max=math.huge,-math.huge
            for frame=1,60 do
                Horse.pose(horse,CFrame.identity,frame/60,true,{speed=42})
                local a=(upper.CFrame*knee.C0).Position;local b=(lower.CFrame*knee.C1).Position
                assert((a-b).Magnitude<.001,'Knee joint disconnected')
                local angle=upper.CFrame.LookVector:Dot(lower.CFrame.LookVector)
                min=math.min(min,angle);max=math.max(max,angle)
            end
            assert(max-min>.1,'Knee stayed rigid')
        end
        assert(#original:GetDescendants()==count,'Source template mutated')
        assert(original:FindFirstChild('Left Arm',true).Transparency<1)
        Horse.clear(horse)
    end
    local current=game.Players:GetPlayers()[1]
    if current and current.Character then
        local runner=assert(Characters.runnerAvatar(folder,current.Character))
        Characters.poseRunner(runner,CFrame.identity,0,true,{speed=42})
        Characters.poseRunner(runner,CFrame.identity,.1,true,{speed=42})
        assert(runner:GetAttribute('Role')=='OwnerPursuer' and runner:FindFirstChild('Head'))
        assert(not runner:FindFirstChildWhichIsA('BaseScript',true))
        assert(runner:FindFirstChildOfClass('Humanoid').RigType==current.Character.Humanoid.RigType)
    end
    folder:Destroy()
    table.insert(results,'All three horse clones articulate four knees without altering originals; owner avatar clone animates without scripts')
    return results
end
