-- Studio's in-memory collection store only; no real player IDs or live DataStore writes.
return function()
    local Collection=require(game.ServerScriptService.Server.HorseCollectionStore)
    local Resolution=require(game.ServerScriptService.Server.PvpResolution)
    assert(Collection.mode=='StudioTest','Never run ownership fixtures against live saves')
    local prefix='surrender-test-'..game:GetService('HttpService'):GenerateGUID(false)
    local count=0
    for _,state in {'Pending','RunningPlayers','RunningNpc'} do
        for _,role in {'Owner','Thief'} do
            count+=1
            local owner={UserId=-9123000-count*2};local thief={UserId=owner.UserId-1}
            local horseId=prefix..'-'..count
            assert(Collection.addOwnedHorse(owner.UserId,{Id=horseId,TemplateId='Horse2',RarityId='Royal',
                Traits={Speed=47,Stamina=151,Ability='DoubleJump'}}))
            local original=Collection.load(owner.UserId)
            local horse=assert(Collection.find(original,horseId))
            horse.ProtectedUntil=0;original.ProtectedHorseId=nil;assert(Collection.save(owner.UserId,original))
            local match={id=horseId..'-match',state=state,owner=owner,thief=thief}
            local result=assert(Resolution.begin(match,nil,role=='Owner' and owner or thief,match.id))
            if result.outcome=='Escaped' then
                local ok,err=Collection.transferOwnership(match.id,owner.UserId,thief.UserId,horse)
                assert(ok,tostring(err))
                -- Journal replay cannot create another horse or remove a different horse.
                local replay,replayError=Collection.transferOwnership(match.id,owner.UserId,thief.UserId,horse)
                assert(replay,tostring(replayError))
            end
            assert(not Resolution.begin(match,nil,owner,match.id))
            assert(not Resolution.begin(match,nil,thief,match.id))
            local owned=Collection.find(Collection.load(owner.UserId),horseId)
            local stolen=Collection.find(Collection.load(thief.UserId),horseId)
            assert((owned~=nil)==(role=='Thief') and (stolen~=nil)==(role=='Owner'),'Surrender awarded the wrong participant')
            local kept=owned or stolen
            assert(kept.Traits.Speed==47 and kept.Traits.Stamina==151 and kept.Traits.Ability=='DoubleJump')
        end
    end
    return {'6 surrender/ownership scenarios passed: both roles, pending/player/NPC chase, journal replay, traits preserved'}
end
