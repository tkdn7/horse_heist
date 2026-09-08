-- Execute in a Studio SERVER test only. Synthetic user IDs never touch production saves.
return function()
    local rs=game.ReplicatedStorage
    local Traits=require(rs.Shared.HorseTraits)
    local Runner=require(rs.HorseRun.Runner)
    local Course=require(rs.HorseRun.Course)
    local Collection=require(game.ServerScriptService.Server.HorseCollectionStore)
    local Store=require(rs.HorseRun.DataStore)
    local Progression=require(rs.HorseRun.Progression)
    local Guards=require(game.ServerScriptService.Server.GuardService)
    assert(Collection.mode=='StudioTest' and Store.mode=='StudioTest')
    local passed={}
    for i,rarity in Traits.Order do
        local range=Traits.Ranges[rarity]
        for j=1,200 do
            local t=Traits.roll(rarity,Random.new(i*1000+j))
            assert(t.Speed>=range.speed[1] and t.Speed<=range.speed[2])
            assert(t.Stamina>=range.stamina[1] and t.Stamina<=range.stamina[2])
            if i<3 then assert(t.Ability=='None') end
        end
        if i>1 then
            local lower=Traits.Ranges[Traits.Order[i-1]]
            assert(lower.speed[2]<range.speed[1] and lower.stamina[2]<range.stamina[1])
        end
        local a=Traits.normalize(rarity,nil,'legacy-42');local b=Traits.normalize(rarity,nil,'legacy-42')
        assert(a.Speed==b.Speed and a.Stamina==b.Stamina and a.Ability==b.Ability)
    end
    assert(Traits.price('Gold',{Speed=36,Stamina=110,Ability='SpeedBoost'},'test')==1648)
    table.insert(passed,'1200 rolls: non-overlapping tiers, ability eligibility, stable legacy traits, price formula')

    local run=Runner.new({ability='DoubleJump'})
    assert(Runner.input(run,'Jump'));Runner.step(run,.2)
    local before=Runner.heightAt(run,run.elapsed)
    assert(Runner.input(run,'Jump'));assert(math.abs(Runner.heightAt(run,run.elapsed)-before)<.001)
    Runner.step(run,.2);assert(not Runner.input(run,'Jump'))
    for _=1,6 do Runner.step(run,.2) end
    assert(Runner.input(run,'Jump'))
    local ordinary=Runner.new();assert(Runner.input(ordinary,'Jump'));Runner.step(ordinary,.2);assert(not Runner.input(ordinary,'Jump'))
    local boost=Runner.new({speed=34,ability='SpeedBoost'})
    assert(Runner.input(boost,'Ability'));Runner.step(boost,.1);assert(boost.speed==42.5)
    assert(not Runner.input(boost,'Ability'))
    for _=1,33 do Runner.step(boost,.1) end
    assert(boost.speed==34)
    local breaker=Runner.new({ability='BreakObstacle',initialDistance=60})
    breaker.lane=Course.row(0).lanes[1];breaker.laneFrom=breaker.lane*8
    assert(Runner.input(breaker,'Ability'));local effects=Runner.step(breaker,.1)
    assert(effects[1].kind=='Broken');assert(not Runner.input(breaker,'Ability'))
    while breaker.distance<82 do Runner.step(breaker,.1) end
    assert(breaker.hits==0)
    table.insert(passed,'Double jump capped at two and continuous; boost duration/cooldown; front obstacle server collision removed')

    local id='regression-'..game:GetService('HttpService'):GenerateGUID(false)
    local user=-9100909
    local profile=Progression.newData();profile.Money=2000
    local existing=Store.load(user);profile.StoreRevision=existing.StoreRevision
    assert(Store.save(user,profile))
    local record={Id=id,TemplateId='Horse1',RarityId='Gold',Traits={Speed=36,Stamina=110,Ability='SpeedBoost'}}
    assert(Collection.addOwnedHorse(user,record))
    local sold,data=Collection.sell(user,id);assert(sold)
    assert(not Collection.find(data,id));assert(not Collection.sell(user,id))
    assert(not Collection.claimOwnership(user,id))
    local credited,paid=Store.creditSales(user,data.SaleTotal);assert(credited)
    local money=paid.Money
    local repeated,repaid=Store.creditSales(user,data.SaleTotal);assert(repeated and repaid.Money==money)
    assert(not Store.save(user,paid),'Stale profile must not overwrite transaction')
    local hired,dogProfile=Store.hireDog(user,Traits.DogPrice);assert(hired and dogProfile.GuardDog)
    local again,same=Store.hireDog(user,Traits.DogPrice);assert(again and same.Money==dogProfile.Money)
    table.insert(passed,'Sale removes horse once; sold ownership rejected; credit replay safe; stale saves rejected; dog charged once')

    local trade={Id=id..'-trade',TemplateId='Horse2',RarityId='Royal',Traits={Speed=47,Stamina=151,Ability='DoubleJump'}}
    assert(Collection.addOwnedHorse(user,trade))
    local ownerData=Collection.load(user)
    local horse=Collection.find(ownerData,trade.Id);horse.ProtectedUntil=0;ownerData.ProtectedHorseId=nil
    assert(Collection.save(user,ownerData))
    local moved,reason,_,recipient=Collection.transferOwnership(id..'-transfer',user,user-1,horse)
    assert(moved,tostring(reason))
    local transferred=Collection.find(recipient,trade.Id)
    assert(transferred.Traits.Speed==47 and transferred.Traits.Stamina==151 and transferred.Traits.Ability=='DoubleJump')
    table.insert(passed,'PvP transfer preserves individual speed, stamina, and ability')
    assert(Guards.inView(CFrame.identity,Vector3.new(0,4,-20)))
    assert(not Guards.inView(CFrame.identity,Vector3.new(0,4,20)))
    assert(not Guards.inView(CFrame.identity,Vector3.new(0,4,-100)))
    assert(Guards.inside(CFrame.new(5,0,5)*CFrame.Angles(0,math.pi/2,0),Vector3.new(60,0,66),Vector3.new(5,4,50)))
    table.insert(passed,'Guard field of view, distance limit, rotated farm bounds')
    return passed
end
