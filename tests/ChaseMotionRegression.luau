-- Run in a Studio test. Unparented fixtures only; no currency, ownership or save writes.
return function()
    local RS=game:GetService('ReplicatedStorage')
    local Motion=require(RS.Shared.GuardMotion)
    local Config=require(RS.Shared.GuardConfig)
    local Runner=require(RS.HorseRun.Runner)
    local Horse=require(RS.HorseRun.Horse)
    local results={}
    assert(Motion.chaseSpeed(0,false)==18)
    assert(Motion.chaseSpeed(4,false)==24)
    assert(Motion.chaseSpeed(1000,false)==38)
    assert(Motion.chaseSpeed(1000,true)==Config.ChaseSpeed)
    local snapshots={{time=1,cf=CFrame.new(0,0,0),moving=true,speed=20},{time=1.1,cf=CFrame.new(2,0,0),moving=true,speed=20}}
    local previous=-1
    for i=0,12 do
        local cf=Motion.sample(snapshots,1+i/120)
        assert(cf.X>=previous and math.abs(cf.X-i/6)<.0001,'Snapshot interpolation jitters')
        previous=cf.X
    end
    assert(Motion.sample(snapshots,2).X==2,'Must hold latest pose on packet loss')
    table.insert(results,'Guard acceleration capped; 120Hz interpolation continuous; packet loss cannot extrapolate through walls')

    local function simulate(dt)
        local run=Runner.new({mode='Chase',speed=32,goalDistance=100000,course={rowLength=100000}})
        -- Keep fixtures away from obstacles; test timing and pursuit alone.
        run.distance=200
        for _=1,math.floor(50/dt+.5) do Runner.step(run,dt) end
        return run
    end
    local a,b=simulate(.1),simulate(1/60)
    assert(a.pursuerGap<20 and a.pursuerGap>0)
    assert(math.abs(a.pursuerGap-b.pursuerGap)<.01,'Pursuit balance depends on frame rate')
    assert(Runner.pursuerSpeed(a,100000)<=32.4)
    local boosted=Runner.new({mode='Chase',speed=32,ability='SpeedBoost',course={rowLength=100000},pursuerGap=12})
    boosted.distance=200;assert(Runner.input(boosted,'Ability'))
    Runner.step(boosted,.2);assert(boosted.pursuerGap>12,'Boost must still create distance')
    local pvp=Runner.new({mode='PvP',course={rowLength=100000}});pvp.distance=200
    Runner.step(pvp,.2);assert(pvp.pursuerGap==24,'NPC ramp must not affect human pursuers')
    table.insert(results,'NPC runner closes gap gradually with bounded speed; 10/60Hz agree; boost and PvP preserved')

    local folder=Instance.new('Folder')
    for _,name in Horse.getNames() do
        local horse=Horse.clone(folder,name)
        local rider=game.Players:GetPlayers()[1]
        if rider and rider.Character then Horse.mount(horse,rider.Character) end
        for _,progress in {.2,.5,.75} do
            Horse.pose(horse,CFrame.new(0,7,0),progress,true,{jumpProgress=progress})
            assert(horse.PrimaryPart.CFrame.LookVector.Y>.999,'Horse must stand fully upright: '..name)
        end
        Horse.pose(horse,CFrame.new(0,7,0),.76,true,{jumpProgress=0,jumpCount=2})
        assert(horse:GetAttribute('UprightJumpBlend')>.9,'Double jump snaps posture')
        Horse.pose(horse,CFrame.identity,1.2,true,{})
        assert(horse:GetAttribute('UprightJumpBlend')==0,'Landing did not restore horse')
        if rider and rider.Character then assert(horse:FindFirstChild('MountedRider'),'Rider disappeared') end
        Horse.clear(horse)
    end
    folder:Destroy()
    table.insert(results,'Every horse template stands 90 degrees through flight; double jump continuous; rider and landing retained')
    return results
end
