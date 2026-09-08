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

return Motion
