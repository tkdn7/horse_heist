local Config = require(script.Parent.Config)
local Course = require(script.Parent.Course)
local ChaseConfig=require(script.Parent.Parent.Shared.ChaseConfig)
local PursuitRules=require(script.Parent.Parent.Shared.PursuitRules)
local Runner = {}

function Runner.pursuerSpeed(run,time)
    return math.min(ChaseConfig.NpcMaximumSpeed,run.baseSpeed+ChaseConfig.NpcSpeedOffset)
end

local function pursuerDistance(run,time)
    return Runner.pursuerSpeed(run,time)*time
end

function Runner.new(stats)
    stats = stats or {}
    local speed = math.max(1, tonumber(stats.speed) or Config.Speed)
    local maxHealth = math.max(1, tonumber(stats.maxHealth) or Config.MaxHealth)
    local pvp = stats.mode == 'PvP'
    local chase = stats.mode == 'Chase' or pvp
    return {distance = tonumber(stats.initialDistance) or 0, elapsed = 0, health = maxHealth, maxHealth = maxHealth,
        speed = speed, baseSpeed=speed, carrots = 0, ability=stats.ability or 'None',
        carrotPace=stats.carrotPace==true,missedCarrots=0,pace=1,penaltyDistance=0,
        abilityReadyAt=0,boostUntil=-10,jumpFrom=0,jumpCount=0,broken={},pendingEffects={},
        lane = 0, x = 0, laneFrom = 0, laneAt = -10, jumpAt = -10, slideAt = -10,
        lastInput = -10, laneSequence = 0, hitAt = -10, hits = 0, done = false,
        chase = chase, pvp = pvp, goalDistance = tonumber(stats.goalDistance),
        pursuerGap = tonumber(stats.pursuerGap) or 24,
        maximumPursuerGap = tonumber(stats.maximumPursuerGap) or 24,
        hitGapPenalty = tonumber(stats.hitGapPenalty) or 8,
        gapRecoveryDelay = tonumber(stats.gapRecoveryDelay) or 2,
        gapRecoveryPerSecond = tonumber(stats.gapRecoveryPerSecond) or 1,
        course = stats.course, outcome = nil}
end

function Runner.xAt(run, time)
    local alpha = math.clamp((time - run.laneAt) / Config.LaneDuration, 0, 1)
    return run.laneFrom + (run.lane * Config.LaneWidth - run.laneFrom) * alpha
end

function Runner.heightAt(run, time)
    local progress = (time - run.jumpAt) / Config.JumpDuration
    if progress < 0 or progress > 1 then return 0 end
    return (run.jumpFrom or 0)*(1-progress)+math.sin(progress * math.pi) * Config.JumpHeight
end

function Runner.isSliding(run, time)
    local progress = time - run.slideAt
    return progress >= 0 and progress < Config.SlideDuration
end

function Runner.input(run, action)
    if run.done then return false end
    if action == 'Left' or action == 'Right' then
        if run.elapsed - run.lastInput < 0.08 then return false end
        run.lastInput = run.elapsed
        run.laneFrom = Runner.xAt(run, run.elapsed)
        run.lane = math.clamp(run.lane + (action == 'Left' and -1 or 1), -1, 1)
        run.laneAt = run.elapsed
        return true
    elseif action == 'Jump' then
        if Runner.isSliding(run, run.elapsed) then return false end
        local height=Runner.heightAt(run,run.elapsed)
        if run.ability=='DoubleJump' and height>.05 and run.jumpCount==1 and run.elapsed-run.jumpAt>=.16 then
            run.jumpFrom=height;run.jumpCount=2;run.jumpAt=run.elapsed
            return true
        end
        if run.elapsed-run.jumpAt<Config.JumpCooldown then return false end
        run.jumpFrom=0;run.jumpCount=1
        run.jumpAt = run.elapsed
        return true
    elseif action=='Ability' and run.elapsed>=run.abilityReadyAt then
        if run.ability=='SpeedBoost' then
            run.boostUntil=run.elapsed+3;run.abilityReadyAt=run.elapsed+10
            table.insert(run.pendingEffects,{kind='Ability',ability=run.ability})
            return true
        elseif run.ability=='BreakObstacle' then
            for _,row in Course.near(run.distance,0,26,run.course) do
                local key=row.index..':'..run.lane
                if row.distance>run.distance and row.distance-run.distance<=26 and table.find(row.lanes,run.lane) and not run.broken[key] then
                    run.broken[key]=true;run.abilityReadyAt=run.elapsed+8
                    table.insert(run.pendingEffects,{kind='Broken',id=key,row=row.index,lane=run.lane})
                    return true
                end
            end
        end
    elseif action == 'Slide' and run.elapsed - run.slideAt >= Config.SlideCooldown then
        if Runner.heightAt(run, run.elapsed) > 0.05 then return false end
        run.slideAt = run.elapsed
        return true
    end
    return false
end

function Runner.step(run, dt)
    if run.done then return {} end
    dt = math.clamp(dt, 0, 0.25)
    run.pace=1
    run.speed=run.baseSpeed*run.pace*(run.elapsed<run.boostUntil and 1.25 or 1)
    local previous = run.distance
    local previousTime = run.elapsed
    local nextDistance = previous + run.speed * dt
    local events = {}
    for _, row in Course.near(previous, 2, run.speed * dt + 24, run.course) do
        for _, carrot in row.carrots do
            if carrot.distance > previous and carrot.distance <= nextDistance then
                table.insert(events, {distance=carrot.distance, kind='Carrot', lane=carrot.lane, id=carrot.id})
            end
        end
        if row.distance > previous and row.distance <= nextDistance then
            table.insert(events, {distance=row.distance, kind=row.kind, lanes=row.lanes,row=row.index})
        end
    end
    table.sort(events, function(a,b) return a.distance < b.distance end)
    local messages = run.pendingEffects;run.pendingEffects={}
    local function penalize(distance)
        run.penaltyDistance+=distance
        if run.chase and not run.pvp then run.pursuerGap-=distance end
    end
    local time = previousTime
    local function advance(target)
        local delta = target - time
        if run.chase then
            time = target
            return true
        end
        if run.health <= delta * Config.Drain then
            local remaining = run.health / Config.Drain
            run.elapsed = time + remaining
            run.distance = previous + (run.elapsed - previousTime) * run.speed
            run.health = 0; run.done = true
            return false
        end
        run.health -= delta * Config.Drain
        time = target
        return true
    end
    for _, event in events do
        local eventTime = previousTime + (event.distance - previous) / run.speed
        if not advance(eventTime) then break end
        local x = Runner.xAt(run, eventTime)
        local height = Runner.heightAt(run, eventTime)
        if event.kind == 'Carrot' then
            if math.abs(x - event.lane * Config.LaneWidth) < 3 and height < 4 then
                run.carrots += 1
                run.health = math.min(run.maxHealth, run.health + Config.CarrotHeal)
                table.insert(messages, {kind='Carrot', id=event.id})
            elseif run.carrotPace then
                run.missedCarrots+=1
                penalize(PursuitRules.MissGapPenalty)
                table.insert(messages,{kind='CarrotMissed',id=event.id,missed=run.missedCarrots,gapPenalty=PursuitRules.MissGapPenalty})
            end
        else
            local hit = false
            for _, lane in event.lanes do
                if not run.broken[event.row..':'..lane] and math.abs(x - lane * Config.LaneWidth) < 3 then hit = true end
            end
            local shouldHit = false
            if event.kind == 'Log' then
                shouldHit = true
            elseif event.kind == 'Fence' then
                shouldHit = height < 3
            elseif event.kind == 'Branch' then
                shouldHit = not Runner.isSliding(run, eventTime)
            end
            if hit and shouldHit then
                run.hitAt = eventTime; run.hits += 1
                local gapPenalty
                if run.carrotPace then
                    gapPenalty=PursuitRules.HitGapPenalty
                    penalize(gapPenalty)
                elseif run.chase and not run.pvp then
                    run.pursuerGap = math.max(0, run.pursuerGap - run.hitGapPenalty*Config.MaxHealth/run.maxHealth)
                else
                    run.health = math.max(0, run.health - Config.Damage)
                end
                table.insert(messages, {kind='Hit', obstacle=event.kind,gapPenalty=gapPenalty})
                if not run.chase and run.health <= 0 then
                    run.distance = event.distance; run.elapsed = eventTime; run.done = true
                    break
                end
            end
        end
    end
    if not run.done and advance(previousTime + dt) then
        run.elapsed = previousTime + dt
        run.distance = nextDistance
    end
    run.x = Runner.xAt(run, run.elapsed)
    if run.chase and not run.pvp and not run.done then
        local travelled=run.distance-previous
        local followed=pursuerDistance(run,run.elapsed)-pursuerDistance(run,previousTime)
        run.pursuerSpeed=Runner.pursuerSpeed(run,run.elapsed)
        run.pursuerGap=math.clamp(run.pursuerGap+travelled-followed,0,run.maximumPursuerGap)
        -- Capture wins if capture and finish happen during the same simulation step.
        if run.pursuerGap <= 0 then
            run.outcome = 'Captured'
            run.done = true
        elseif run.goalDistance and run.distance >= run.goalDistance then
            run.distance = run.goalDistance
            run.outcome = 'Escaped'
            run.done = true
        end
    end
    return messages
end

function Runner.reward(run)
    return math.floor(run.distance + run.carrots * Config.CarrotValue),
        math.floor(run.distance / 10 + run.carrots * 0.5)
end

return Runner

