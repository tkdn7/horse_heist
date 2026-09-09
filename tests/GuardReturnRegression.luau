-- Local Studio fixtures; no ownership/currency writes.
return function()
    local RS=game.ReplicatedStorage
    local Motion=require(RS.Shared.GuardMotion)
    local Completion=require(game.ServerScriptService.Server.RunCompletion)
    local Characters=require(RS.HorseRun.Characters)
    local Farm=require(game.ServerScriptService.Server.PlayerFarm)
    local passed={}
    for _,fps in {30,60,120} do
        local packets={}
        for i=0,50 do
            local time=i*.1
            table.insert(packets,{arrival=time+(.03+(i%4)*.025),time=time,
                cf=CFrame.new(math.min(time,4)*20,0,0),moving=time<4,speed=time<4 and 20 or 0})
        end
        local samples,playback={},{}
        local nextPacket=1
        local previous,previousClock=nil,nil
        local stalls=0
        for frame=0,6*fps do
            local now=frame/fps
            while packets[nextPacket] and packets[nextPacket].arrival<=now do
                table.insert(samples,packets[nextPacket]);nextPacket+=1
            end
            local cf,blend=Motion.render(playback,samples,now,1/fps)
            if cf then
                if previous then
                    local step=cf.X-previous
                    assert(step>=-.0001 and step<=25/fps+.001,'Guard playback reversed or jumped on packet arrival')
                    if now>.5 and now<3.8 and step<.0001 then stalls+=1 end
                end
                if previousClock then assert(playback.clock>=previousClock,'Playback clock rewound') end
                previous=cf.X;previousClock=playback.clock
                assert(cf.X<=samples[#samples].cf.X+.0001,'Extrapolated beyond confirmed position')
                if now>5 then assert(blend<.001,'Stopped guard retained running pose') end
            end
        end
        assert(stalls==0,'Guard stopped between uneven snapshots')
        assert(math.abs(previous-80)<.001)
    end
    table.insert(passed,'30/60/120Hz guard playback: uneven packets, no inter-packet stalls, no extrapolation, smooth stop')

    for _,outcome in {'Escaped','Captured'} do
        local session={phase='Running',run={done=false}}
        assert(Completion.begin(session) and session.run.done)
        assert(not Completion.begin(session),'Completion started twice')
        assert(Completion.returnToLobby(session),'Return was blocked by pending storage')
        assert(session.phase=='Resolving','New run unlocked before ownership finished')
        local result={reason=outcome};Completion.finish(session,result)
        assert(result.background and session.phase=='Lobby' and session.run==nil)
        Completion.finish(session,{reason=outcome});assert(session.phase=='Lobby')
        local stay={phase='Running',run={}}
        assert(Completion.begin(stay));local card={};Completion.finish(stay,card)
        assert(stay.phase=='Results' and not card.background)
    end
    table.insert(passed,'Both outcomes allow immediate farm return during storage; final results do not reopen the modal or unlock transactions early')

    local farmer=Characters.farmer(nil)
    Characters.poseFarmer(farmer,CFrame.identity,.45,1,true)
    assert(farmer.Head.Color==Color3.fromRGB(245,64,48))
    assert(farmer.Head.FarmerLabel:FindFirstChildWhichIsA('TextLabel').Text=='농장주')
    assert(farmer.Head.Size.X>1.5,'Angry pulse was lost')
    farmer:Destroy()
    table.insert(passed,'Red face and angry head pulse remain without warning text')

    local attrs={};local actor={UserId=-9127771,DisplayName='StallReuseTest'}
    function actor:GetAttribute(key) return attrs[key] end
    function actor:SetAttribute(key,value) attrs[key]=value end
    local ok,err=pcall(function()
        local data={Horses={{Id='reuse-1',TemplateId='Horse1',RarityId='Bronze',Placed=true,ProtectedUntil=0}}}
        local farm=Farm.render(actor,data)
        local first,second=farm.Displays.Stall1,farm.Displays.Stall2
        Farm.render(actor,data)
        assert(farm.Displays.Stall1==first and farm.Displays.Stall2==second,'Unchanged stalls rebuilt')
        table.insert(data.Horses,{Id='reuse-2',TemplateId='Horse2',RarityId='Silver',Placed=true,ProtectedUntil=0})
        Farm.render(actor,data)
        assert(farm.Displays.Stall1==first and farm.Displays.Stall2~=second,'Adding a horse rebuilt unrelated stalls')
    end)
    Farm.remove(actor);assert(ok,tostring(err))
    table.insert(passed,'Farm update preserves unchanged stall/horse instances and rebuilds only the changed slot')
    return passed
end
