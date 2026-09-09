local Config=require(script.Parent.GuardConfig)
local Motion={}

function Motion.chaseSpeed(seconds,isDog)
    if isDog then return Config.ChaseSpeed end
    return math.min(Config.FarmerMaxSpeed,Config.FarmerStartSpeed+math.max(0,seconds)*Config.FarmerAcceleration)
end

-- Timestamped snapshots are sampled behind the server; never extrapolate through walls.
function Motion.sample(samples,time)
    if #samples==0 then return nil end
    for i=2,#samples do
        local a,b=samples[i-1],samples[i]
        if time<=b.time then
            local alpha=math.clamp((time-a.time)/math.max(b.time-a.time,.001),0,1)
            return a.cf:Lerp(b.cf,alpha),b.moving,b.speed
        end
    end
    local last=samples[#samples]
    return last.cf,last.moving,last.speed
end

-- A monotonic playback clock absorbs uneven packet arrivals without teleporting
-- to the newest snapshot or predicting movement beyond the server's last position.
function Motion.render(state,samples,now,dt)
    if #samples==0 then return nil end
    dt=math.clamp(dt,0,.1)
    local latest=samples[#samples].time
    local target=math.min(now-Config.VisualDelay,latest)
    if not state.clock then state.clock=math.max(samples[1].time,target) end
    local rate=math.clamp(1+(target-state.clock)*4,.75,1.25)
    state.clock=math.min(latest,state.clock+dt*rate)
    local cf=Motion.sample(samples,state.clock)
    local speed=0
    if state.cf and dt>0 then
        speed=math.min(60,(cf.Position-state.cf.Position).Magnitude/dt)
        cf=CFrame.new(cf.Position)*state.cf.Rotation:Lerp(cf.Rotation,1-math.exp(-dt*18))
    end
    local weight=math.clamp(speed/3,0,1)
    state.blend=(state.blend or 0)+(weight-(state.blend or 0))*(1-math.exp(-dt*14))
    state.phase=(state.phase or 0)+dt*speed/16
    state.cf=cf
    return cf,state.blend,state.phase,speed
end

return Motion
