local Config = require(script.Parent.Config)
local Course = require(script.Parent.Course)
local Runner = {}

function Runner.new(stats)
    stats = stats or {}
    local speed = math.max(1, tonumber(stats.speed) or Config.Speed)
    local maxHealth = math.max(1, tonumber(stats.maxHealth) or Config.MaxHealth)
    local pvp = stats.mode == 'PvP'
    local chase = stats.mode == 'Chase' or pvp
    return {distance = tonumber(stats.initialDistance) or 0, elapsed = 0, health = maxHealth, maxHealth = maxHealth,
        speed = speed, carrots = 0,
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
    return math.sin(progress * math.pi) * Config.JumpHeight
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
    elseif action == 'Jump' and run.elapsed - run.jumpAt >= Config.JumpCooldown then
        if Runner.isSliding(run, run.elapsed) then return false end
        run.jumpAt = run.elapsed
        return true
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
            table.insert(events, {distance=row.distance, kind=row.kind, lanes=row.lanes})
        end
    end
    table.sort(events, function(a,b) return a.distance < b.distance end)
    local messages = {}
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
            end
        else
            local hit = false
            for _, lane in event.lanes do
                if math.abs(x - lane * Config.LaneWidth) < 3 then hit = true end
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
                if run.chase and not run.pvp then
                    run.pursuerGap = math.max(0, run.pursuerGap - run.hitGapPenalty)
                else
                    run.health = math.max(0, run.health - Config.Damage)
                end
                table.insert(messages, {kind='Hit', obstacle=event.kind})
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
        if run.elapsed - run.hitAt >= run.gapRecoveryDelay then
            run.pursuerGap = math.min(run.maximumPursuerGap,
                run.pursuerGap + run.gapRecoveryPerSecond * dt)
        end
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

