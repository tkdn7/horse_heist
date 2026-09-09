-- Local Studio server test; disposable fixtures only, no real ownership/currency writes.
return function()
    local RS=game.ReplicatedStorage
    local Rules=require(RS.Shared.PursuitRules)
    local Runner=require(RS.HorseRun.Runner)
    local Course=require(RS.HorseRun.Course)
    local Horse=require(RS.HorseRun.Horse)
    local Resolution=require(game.ServerScriptService.Server.PvpResolution)
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
    assert(bad.carrots==0 and bad.missedCarrots==2 and bad.speed==42)
    assert(bad.penaltyDistance==4 and good.penaltyDistance==0)
    local hit=Runner.new(Rules.stats(traits,0,course,false))
    local obstacle=Course.row(0,course)
    hit.distance=obstacle.distance-1;hit.lane=obstacle.lanes[1];hit.laneFrom=hit.lane*8
    Runner.step(hit,.1)
    assert(hit.hits==1 and hit.penaltyDistance==6,'PvP collisions need a finite distance penalty')
    local thief=Runner.new(Rules.stats(traits,200,{rowLength=100000},false))
    local owner=Runner.new(Rules.stats(traits,172,{rowLength=100000},false))
    thief.penaltyDistance=10;owner.penaltyDistance=6
    for _=1,200 do Runner.step(thief,.1);Runner.step(owner,.1) end
    assert(math.abs(Rules.gap(thief,owner)-24)<.001,'A past mistake must not cause permanent catch-up')
    local legacy=Runner.new({speed=42});collect(legacy,true);assert(legacy.speed==42 and legacy.missedCarrots==0)
    for _,dt in {.1,1/60} do
        local npc=Runner.new(Rules.stats(traits,0,{rowLength=100000},true))
        npc.distance=200;npc.pursuerGap=14;npc.penaltyDistance=10;npc.missedCarrots=2
        for _=1,math.floor(20/dt) do Runner.step(npc,dt) end
        assert(not npc.done and math.abs(npc.pursuerGap-14)<.001 and npc.speed==42)
    end
    local npc=Runner.new(Rules.stats(traits,0,course,true));npc.pursuerGap=3
    collect(npc,true)
    assert(npc.done and npc.outcome=='Captured','Repeated misses must still lead to capture')
    table.insert(results,'Carrot miss costs 2m, collision 6m; both roles retain speed; clean gaps hold at 10/60Hz; repeated misses capture')

    local ownerActor,thiefActor,outsider={},{},{}
    for _,state in {'Pending','RunningPlayers','RunningNpc'} do
        for _,role in {'Owner','Thief'} do
            local match={id='match',state=state,owner=ownerActor,thief=thiefActor}
            assert(not Resolution.begin(match,nil,outsider,'match'))
            assert(not Resolution.begin(match,nil,ownerActor,'old-match'))
            assert(match.state==state,'Rejected request consumed the match')
            local actor=role=='Owner' and ownerActor or thiefActor
            local settled=assert(Resolution.begin(match,nil,actor,'match'))
            assert(settled.giveUpBy==role and settled.outcome==(role=='Owner' and 'Escaped' or 'Captured'))
            assert(not Resolution.begin(match,nil,actor,'match'),'Repeated request resolved twice')
            assert(not Resolution.begin(match,'Escaped'),'Finish line raced with surrender')
        end
    end
    local cancelled={id='match',state='Cancelled',owner=ownerActor,thief=thiefActor}
    assert(not Resolution.begin(cancelled,nil,ownerActor,'match'))
    table.insert(results,'Both roles can surrender pending/running/NPC-delegated matches; stale IDs, outsiders, duplicates and finish races rejected')

    local fixtures={}
    local ok,err=pcall(function()
        for i=1,2 do
            -- Player-shaped fixture: Studio MCP cannot construct engine Player instances.
            local attributes={}
            local p={UserId=-991120-i,DisplayName='ProtectionFixture'..i}
            function p:GetAttribute(key) return attributes[key] end
            function p:SetAttribute(key,value) attributes[key]=value end
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
    for _,p in fixtures do Farm.remove(p) end
    assert(ok,tostring(err))
    table.insert(results,'Both farms fully locked across re-render; competing event rejected; token-safe unlock preserves existing horse protection')

    local folder=Instance.new('Folder')
    for _,name in Horse.getNames() do
        local original=RS.HorseRun.Horses:FindFirstChild(name)
        local count=#original:GetDescendants()
        local horse=Horse.clone(folder,name)
        local function partCount(model)
            local n=0;for _,d in model:GetDescendants() do if d:IsA('BasePart') then n+=1 end end;return n
        end
        assert(partCount(horse)==partCount(original),'Procedural geometry added to horse')
        for _,partName in {'Left Leg','Right Leg','Left Arm','Right Arm'} do
            local limb=assert(horse:FindFirstChild(partName,true))
            local source=original:FindFirstChild(partName,true)
            assert(limb.ClassName==source.ClassName and limb.Transparency==source.Transparency)
            Horse.pose(horse,CFrame.identity,.5,true,{speed=42})
            -- This asset uses invisible rig limbs with sculpted visible pieces welded onto them.
            assert(limb.Transparency==source.Transparency and (limb.Size-source.Size).Magnitude<.001)
        end
        assert(#original:GetDescendants()==count,'Source template mutated')
        local sourceVisible,cloneVisible=0,0
        for _,d in original:GetDescendants() do if d:IsA('BasePart') and d.Transparency<1 then sourceVisible+=1 end end
        for _,d in horse:GetDescendants() do if d:IsA('BasePart') and d.Transparency<1 then cloneVisible+=1 end end
        assert(sourceVisible>0 and cloneVisible==sourceVisible,'Original visible geometry changed')
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
    table.insert(results,'All three templates retain their original visible limbs without added geometry; owner avatar clone animates without scripts')
    return results
end
