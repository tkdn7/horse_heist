local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local HttpService = game:GetService('HttpService')
local Shared = ReplicatedStorage:WaitForChild('HorseRun')
local GlobalShared = ReplicatedStorage:WaitForChild('Shared')
local Config = require(Shared.Config)
local Runner = require(Shared.Runner)
local Progression = require(Shared.Progression)
local PlayerStore = require(Shared.DataStore)
local HorseRarity = require(GlobalShared:WaitForChild('HorseRarity'))
local ChaseConfig = require(GlobalShared:WaitForChild('ChaseConfig'))
local ServerModules = ServerScriptService:WaitForChild('Server')
local HorseCollectionStore = require(ServerModules:WaitForChild('HorseCollectionStore'))
local PlayerFarm = require(ServerModules:WaitForChild('PlayerFarm'))
local Remote = Shared:WaitForChild('Event')
local CollectionRemote = Shared:FindFirstChild('HorseCollectionEvent') or Instance.new('RemoteEvent')
CollectionRemote.Name = 'HorseCollectionEvent'; CollectionRemote.Parent = Shared
local sessions = {}
local pvpEvents = {}
local pvpByPlayer = {}
local cancelPvp

local function signal(name, className)
    local found = ServerScriptService:FindFirstChild(name)
    if found then return found end
    local made = Instance.new(className); made.Name = name; made.Parent = ServerScriptService
    return made
end
local chaseRequest = signal('NpcHorseChaseRequest', 'BindableFunction')
local chaseResolved = signal('NpcHorseChaseResolved', 'BindableEvent')

local function send(player, kind, data)
    if player.Parent then Remote:FireClient(player, kind, data) end
end

local function updateLeaderstats(player, session)
    local leaderstats = player:FindFirstChild('leaderstats')
    if not leaderstats then return end
    leaderstats.Money.Value = session.data.Money
    leaderstats.Level.Value = session.data.Level
    leaderstats.Best.Value = session.data.BestDistance
end

local function sendProfile(player, session)
    updateLeaderstats(player, session)
    send(player, 'Profile', Progression.clientProfile(session.data, PlayerStore.mode))
end

local function sendCollection(player, session, result)
    local payload = HorseCollectionStore.clientData(session.horseData)
    payload.result = result
    CollectionRemote:FireClient(player, 'Collection', payload)
end

local function markDirty(session)
    session.dirty = true
    session.revision += 1
end

local function saveSession(player, session, reason)
    if not session or session.saving or not session.dirty then return true end
    if not session.canSave then return false end
    session.saving = true
    local revision = session.revision
    local ok, err = PlayerStore.save(player.UserId, session.data)
    if ok and session.revision == revision then session.dirty = false end
    session.saving = false
    if player.Parent then
        send(player, 'SaveStatus', {ok = ok, mode = PlayerStore.mode, reason = reason})
    end
    if not ok then warn('[HorseRun] Save failed for ' .. player.UserId .. ': ' .. tostring(err)) end
    return ok
end

local function saveHorseSession(player, session, reason)
    if not session then return false end
    if session.horseSaving then return false end
    if not session.horseDirty then return true end
    if not session.horseCanSave then return false end
    session.horseSaving = true
    local revision = session.horseRevision
    local ok, result = HorseCollectionStore.save(player.UserId, session.horseData)
    if ok and revision == session.horseRevision then
        session.horseData = result
        session.horseDirty = false
    end
    session.horseSaving = false
    if not ok then warn('[HorseCollection] Save failed for '..player.UserId..': '..tostring(result)) end
    return ok
end

local function restore(player)
    local character = player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    if root then
        root.Anchored = false
        character:PivotTo(PlayerFarm.home(player))
    end
end

local function setup(player)
    if sessions[player] then return end
    local leaderstats = Instance.new('Folder')
    leaderstats.Name = 'leaderstats'
    leaderstats.Parent = player
    for _, name in {'Money', 'Level', 'Best'} do
        local value = Instance.new('IntValue')
        value.Name = name
        value.Parent = leaderstats
    end

    local data, loadError = PlayerStore.load(player.UserId)
    if not data then
        data = Progression.newData()
        warn('[HorseRun] Load failed for ' .. player.UserId .. ': ' .. tostring(loadError))
    end
    local _, recoveryError = HorseCollectionStore.recover(player.UserId)
    if recoveryError then warn('[HorseTransfer] Recovery pending for '..player.UserId..': '..tostring(recoveryError)) end
    local horseData, horseLoadError = HorseCollectionStore.load(player.UserId)
    if not horseData then horseData = HorseCollectionStore.newData() end
    local session = {
        phase = 'Lobby', data = data, lastRequest = 0,
        budget = 30, budgetAt = os.clock(), serial = 0,
        dirty = false, revision = 0, saving = false, canSave = loadError == nil,
        captures = {}, chaseTarget = nil, horseData = horseData,
        horseDirty = false, horseRevision = 0, horseSaving = false, horseCanSave = horseLoadError == nil,
    }
    sessions[player] = session
    sendProfile(player, session)
    PlayerFarm.render(player, horseData)
    if player.Character then restore(player) end
    sendCollection(player, session)
    if loadError then send(player, 'SaveStatus', {ok = false, mode = PlayerStore.mode, reason = 'Load'}) end

    player.CharacterAdded:Connect(function(character)
        task.defer(function() if character:WaitForChild("HumanoidRootPart",10) then restore(player) end end)
        if session.pvpEvent and cancelPvp then
            task.defer(cancelPvp, session.pvpEvent, 'CharacterReset')
            return
        end
        if session.chaseTarget and session.chaseTarget.slot then chaseResolved:Fire(session.chaseTarget.slot, false) end
        session.phase = 'Lobby'
        session.run = nil
        session.chaseTarget = nil
        send(player, 'Lobby', {})
        sendProfile(player, session)
        sendCollection(player, session)
    end)
end

local function finish(player, session, reason)
    if session.phase ~= 'Running' then return end
    session.phase = 'Results'
    session.run.done = true
    if session.run.chase then
        local success = reason == 'Escaped'
        local target = session.chaseTarget
        if success and target then
            if session.horseDirty and not saveHorseSession(player, session, 'CapturePreflight') then success = false; reason = 'PreflightSaveFailed' end
            local added, result
            if success and session.horseSaving then success = false; reason = 'SaveBusy' end
            if success then
                session.horseSaving = true
                added, result = HorseCollectionStore.addOwnedHorse(player.UserId, {
                    Id = target.horseId, TemplateId = target.horseName, RarityId = target.rarityId,
                })
                session.horseSaving = false
            end
            if added then
                session.horseData = result; session.horseDirty = false; session.horseRevision += 1
                PlayerFarm.render(player, session.horseData); sendCollection(player, session, 'Captured')
            else
                success = false
                reason = result or reason or 'CollectionRejected'
            end
        end
        if target and target.slot then chaseResolved:Fire(target.slot, success) end
        send(player, 'Result', {
            chase = true, success = success, reason = reason,
            distance = math.floor(session.run.distance), goalDistance = session.run.goalDistance,
            carrots = session.run.carrots, hits = session.run.hits,
            pursuerGap = session.run.pursuerGap, rarityId = target and target.rarityId,
            horseName = target and target.horseName, capturedCount = #session.horseData.Horses,
            money = 0, exp = 0, levelUps = 0, level = session.data.Level,
            serial = session.serial,
        })
        session.chaseTarget = nil
        return
    end
    local money, exp = Runner.reward(session.run)
    local distance = math.floor(session.run.distance)
    local record = distance > session.data.BestDistance
    local levelUps = Progression.grantRun(session.data, money, exp, distance, session.run.carrots)
    markDirty(session)
    sendProfile(player, session)
    local stats = Progression.stats(session.data)
    send(player, 'Result', {
        distance = distance, carrots = session.run.carrots, money = money, exp = exp,
        best = session.data.BestDistance, record = record, reason = reason,
        hits = session.run.hits, serial = session.serial, level = session.data.Level,
        levelUps = levelUps, speed = stats.speed, maxHealth = stats.maxHealth,
    })
    task.spawn(saveSession, player, session, 'Run')
end

local function startRun(player, chaseTarget)
    local session = sessions[player]
    if not session or (session.phase ~= 'Lobby' and session.phase ~= 'Results') then return end
    if os.clock() - session.lastRequest < .75 then return end
    local character = player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    local humanoid = character and character:FindFirstChildWhichIsA('Humanoid')
    if not root or not humanoid or humanoid.Health <= 0 then return end
    session.lastRequest = os.clock()
    root.Anchored = true
    local stats
    local rarity
    if chaseTarget then
        rarity = HorseRarity.get(chaseTarget.rarityId)
        local seed = Random.new():NextInteger(1, 1000000)
        stats = {
            mode = 'Chase', speed = ChaseConfig.BaseSpeed, maxHealth = Config.MaxHealth,
            goalDistance = ChaseConfig.BaseSpeed * rarity.EscapeSeconds,
            pursuerGap = ChaseConfig.InitialNpcGap,
            maximumPursuerGap = ChaseConfig.MaximumNpcGap,
            hitGapPenalty = ChaseConfig.HitGapPenalty,
            gapRecoveryDelay = ChaseConfig.GapRecoveryDelay,
            gapRecoveryPerSecond = ChaseConfig.GapRecoveryPerSecond,
            course = {seed = seed, rowLength = ChaseConfig.BaseSpeed * rarity.MinimumObstacleGapSeconds},
        }
        session.chaseTarget = chaseTarget
    else
        stats = Progression.stats(session.data)
        session.chaseTarget = nil
    end
    session.phase = 'Countdown'
    session.run = Runner.new(stats)
    session.startAt = workspace:GetServerTimeNow() + Config.Countdown
    session.serial += 1
    send(player, 'Start', {startAt = session.startAt, serial = session.serial,
        speed = stats.speed, maxHealth = stats.maxHealth, chase = chaseTarget ~= nil,
        goalDistance = stats.goalDistance, pursuerGap = stats.pursuerGap,
        rarityId = rarity and rarity.Id, rarityName = rarity and rarity.DisplayName,
        horseName = chaseTarget and chaseTarget.horseName, course = stats.course})
end

chaseRequest.OnInvoke = function(player, target)
    if typeof(player) ~= 'Instance' or type(target) ~= 'table' then return false end
    local slot = target.slot
    if typeof(slot) ~= 'Instance' or not slot:IsDescendantOf(workspace) then return false end
    if slot:GetAttribute('Occupied') ~= true or slot:GetAttribute('LockedBy') ~= player.UserId then return false end
    local before = sessions[player] and sessions[player].serial
    startRun(player, target)
    local session = sessions[player]
    return session ~= nil and session.phase == 'Countdown' and session.serial ~= before
end

local function anchorForRun(player)
    local character = player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    local humanoid = character and character:FindFirstChildWhichIsA('Humanoid')
    if not root or not humanoid or humanoid.Health <= 0 then return false end
    root.Anchored = true
    return true
end

local function unlockPvp(event)
    local pad = event.pad
    if typeof(pad) == 'Instance' and pad.Parent then
        local prompt = pad:FindFirstChild('PlayerStealPrompt')
        if prompt and prompt:IsA('ProximityPrompt') then
            prompt:SetAttribute('Busy', false)
            prompt.Enabled = pad:GetAttribute('StealProtected') ~= true
        end
        pad:SetAttribute('ActiveStealId', nil)
    end
end

local function clearPvp(event)
    pvpEvents[event.id] = nil
    if pvpByPlayer[event.thief] == event then pvpByPlayer[event.thief] = nil end
    if pvpByPlayer[event.owner] == event then pvpByPlayer[event.owner] = nil end
    unlockPvp(event)
end

cancelPvp = function(event, reason)
    if not event or event.state == 'Finished' or event.state == 'Cancelled' then return end
    event.state = 'Cancelled'
    clearPvp(event)
    for _, player in {event.thief, event.owner} do
        local session = sessions[player]
        if session and session.pvpEvent == event then
            session.pvpEvent = nil; session.phase = 'Lobby'; session.run = nil; session.chaseTarget = nil
            restore(player); send(player, 'PvPCancelled', {reason = reason}); send(player, 'Lobby', {})
            sendCollection(player, session)
        end
    end
end

local function pvpStartPayload(event, role, run)
    return {
        startAt = event.startAt, serial = sessions[role == 'Thief' and event.thief or event.owner].serial,
        speed = ChaseConfig.BaseSpeed, maxHealth = Config.MaxHealth, chase = true, pvpRole = role,
        initialDistance = run.distance, goalDistance = event.goalDistance, pursuerGap = ChaseConfig.OwnerInitialGap,
        rarityId = event.rarityId, rarityName = HorseRarity.get(event.rarityId).DisplayName,
        horseName = event.templateId, course = event.course,
    }
end

local function startPvp(event, ownerJoined)
    if event.state ~= 'Pending' then return end
    local thiefSession, ownerSession = sessions[event.thief], sessions[event.owner]
    if not thiefSession or not ownerSession or thiefSession.pvpEvent ~= event or ownerSession.pvpEvent ~= event then
        cancelPvp(event, 'Unavailable'); return
    end
    if not anchorForRun(event.thief) or (ownerJoined and not anchorForRun(event.owner)) then
        cancelPvp(event, 'CharacterUnavailable'); return
    end
    event.state = ownerJoined and 'RunningPlayers' or 'RunningNpc'
    event.ownerJoined = ownerJoined
    event.startAt = workspace:GetServerTimeNow() + Config.Countdown
    event.course = {seed = Random.new():NextInteger(1, 1000000), rowLength = ChaseConfig.BaseSpeed * HorseRarity.get(event.rarityId).MinimumObstacleGapSeconds}
    event.goalDistance = ChaseConfig.BaseSpeed * HorseRarity.get(event.rarityId).EscapeSeconds
    event.gapAdjustment = 0; event.catchHeld = 0; event.boostReadyAt = 0; event.boostUntil = 0
    thiefSession.phase = 'Countdown'; thiefSession.serial += 1
    thiefSession.run = Runner.new({mode = ownerJoined and 'PvP' or 'Chase', speed = ChaseConfig.BaseSpeed,
        maxHealth = Config.MaxHealth, goalDistance = event.goalDistance, pursuerGap = ChaseConfig.OwnerInitialGap,
        maximumPursuerGap = ChaseConfig.OwnerInitialGap, hitGapPenalty = ChaseConfig.HitGapPenalty,
        gapRecoveryDelay = ChaseConfig.GapRecoveryDelay, gapRecoveryPerSecond = ChaseConfig.GapRecoveryPerSecond,
        course = event.course})
    send(event.thief, 'Start', pvpStartPayload(event, 'Thief', thiefSession.run))
    if ownerJoined then
        ownerSession.phase = 'Countdown'; ownerSession.serial += 1
        ownerSession.run = Runner.new({mode = 'PvP', speed = ChaseConfig.BaseSpeed, maxHealth = Config.MaxHealth,
            initialDistance = -ChaseConfig.OwnerInitialGap, course = event.course})
        send(event.owner, 'Start', pvpStartPayload(event, 'Owner', ownerSession.run))
        send(event.owner, 'PvPBoostReady', {visible = true, ready = true, cooldown = 0})
    else
        ownerSession.phase = 'Lobby'; ownerSession.pvpEvent = nil
        send(event.owner, 'PvPWaiting', {message = 'NPC가 대신 추격합니다.'})
    end
end

local function transferHorse(event)
    local thiefSession, ownerSession = sessions[event.thief], sessions[event.owner]
    if not thiefSession or not ownerSession then return false, 'PlayerLeft' end
    if HorseCollectionStore.isProtected(ownerSession.horseData, event.horseId) then return false, 'Protected' end
    if ownerSession.horseSaving or thiefSession.horseSaving then return false, 'TransferBusy' end
    if ownerSession.horseDirty and not saveHorseSession(event.owner, ownerSession, 'PvPPreflight') then return false, 'PreflightSaveFailed' end
    if thiefSession.horseDirty and not saveHorseSession(event.thief, thiefSession, 'PvPPreflight') then return false, 'PreflightSaveFailed' end
    local horse = HorseCollectionStore.find(ownerSession.horseData, event.horseId)
    if not horse then return false, 'Missing' end
    ownerSession.horseSaving = true; thiefSession.horseSaving = true
    local ok, reason, ownerData, thiefData = HorseCollectionStore.transferOwnership(
        event.id, event.owner.UserId, event.thief.UserId, horse)
    ownerSession.horseSaving = false; thiefSession.horseSaving = false
    if not ok then return false, reason or 'TransferPending' end
    ownerSession.horseData = ownerData; thiefSession.horseData = thiefData
    ownerSession.horseDirty = false; thiefSession.horseDirty = false
    ownerSession.horseRevision += 1; thiefSession.horseRevision += 1
    return true
end

local function finishPvp(event, outcome)
    if event.state ~= 'RunningPlayers' and event.state ~= 'RunningNpc' then return end
    event.state = 'Finished'
    local thiefSession, ownerSession = sessions[event.thief], sessions[event.owner]
    local escaped = outcome == 'Escaped'
    local transferred, transferReason = false, nil
    if escaped then transferred, transferReason = transferHorse(event) end
    if escaped and not transferred then outcome = transferReason or 'TransferFailed'; escaped = false end
    local thiefRun = thiefSession and thiefSession.run
    local ownerRun = ownerSession and ownerSession.run
    clearPvp(event)
    if thiefSession then
        thiefSession.pvpEvent = nil; thiefSession.phase = 'Results'
        if thiefRun then thiefRun.done = true end
        PlayerFarm.render(event.thief, thiefSession.horseData); sendCollection(event.thief, thiefSession, transferred and 'Stolen' or nil)
        send(event.thief, 'Result', {chase = true, pvpRole = 'Thief', success = escaped, reason = outcome,
            distance = math.floor(thiefRun and thiefRun.distance or 0), goalDistance = event.goalDistance,
            carrots = thiefRun and thiefRun.carrots or 0, hits = thiefRun and thiefRun.hits or 0,
            pursuerGap = event.lastGap or ChaseConfig.OwnerInitialGap, rarityId = event.rarityId,
            horseName = event.templateId, capturedCount = #thiefSession.horseData.Horses,
            money = 0, exp = 0, levelUps = 0, level = thiefSession.data.Level, serial = thiefSession.serial})
    end
    if ownerSession then
        ownerSession.pvpEvent = nil
        PlayerFarm.render(event.owner, ownerSession.horseData); sendCollection(event.owner, ownerSession, transferred and 'LostHorse' or 'Defended')
        if event.ownerJoined then
            ownerSession.phase = 'Results'
            if ownerRun then ownerRun.done = true end
            send(event.owner, 'PvPBoostReady', {visible = false})
            send(event.owner, 'Result', {chase = true, pvpRole = 'Owner', success = not escaped, reason = outcome,
                distance = math.floor(ownerRun and ownerRun.distance or 0), goalDistance = event.goalDistance,
                carrots = ownerRun and ownerRun.carrots or 0, hits = ownerRun and ownerRun.hits or 0,
                pursuerGap = event.lastGap or ChaseConfig.OwnerInitialGap, rarityId = event.rarityId,
                horseName = event.templateId, capturedCount = #ownerSession.horseData.Horses,
                money = 0, exp = 0, levelUps = 0, level = ownerSession.data.Level, serial = ownerSession.serial})
        else
            ownerSession.phase = 'Lobby'
        end
    end
end

PlayerFarm.setStealHandler(function(thief, owner, horseId, pad)
    local thiefSession, ownerSession = sessions[thief], sessions[owner]
    if thief == owner or not thiefSession or not ownerSession then return false end
    if thiefSession.phase ~= 'Lobby' or ownerSession.phase ~= 'Lobby' or pvpByPlayer[thief] or pvpByPlayer[owner] then return false end
    local horse = HorseCollectionStore.find(ownerSession.horseData, horseId)
    if not horse or not horse.Placed or HorseCollectionStore.isProtected(ownerSession.horseData, horseId) then return false end
    if pad:GetAttribute('HorseId') ~= horseId or pad:GetAttribute('ActiveStealId') then return false end
    local event = {id = HttpService:GenerateGUID(false), state = 'Pending', thief = thief, owner = owner,
        horseId = horse.Id, templateId = horse.TemplateId, rarityId = horse.RarityId, pad = pad,
        deadline = workspace:GetServerTimeNow() + ChaseConfig.JoinWindowSeconds}
    pvpEvents[event.id] = event; pvpByPlayer[thief] = event; pvpByPlayer[owner] = event
    thiefSession.pvpEvent = event; ownerSession.pvpEvent = event
    thiefSession.phase = 'PvPWaiting'; ownerSession.phase = 'PvPInvited'; pad:SetAttribute('ActiveStealId', event.id)
    anchorForRun(thief)
    send(thief, 'PvPWaiting', {eventId = event.id, ownerName = owner.DisplayName, deadline = event.deadline})
    send(owner, 'PvPInvitation', {eventId = event.id, thiefName = thief.DisplayName,
        rarityId = horse.RarityId, horseName = horse.TemplateId, deadline = event.deadline})
    return true
end)

Remote.OnServerEvent:Connect(function(player, action, argument)
    local session = sessions[player]
    if not session or type(action) ~= 'string' then return end
    local now = os.clock()
    session.budget = math.min(30, session.budget + (now - session.budgetAt) * 15)
    session.budgetAt = now
    if session.budget < 1 then return end
    session.budget -= 1

    if action == 'PvPRespond' and type(argument) == 'table' then
        local event = pvpByPlayer[player]
        if event and event.owner == player and event.state == 'Pending' and argument.eventId == event.id then
            startPvp(event, argument.accept == true)
        end
    elseif action == 'Boost' then
        local event = pvpByPlayer[player]
        if event and event.state == 'RunningPlayers' and event.owner == player and workspace:GetServerTimeNow() >= event.boostReadyAt then
            event.boostUntil = workspace:GetServerTimeNow() + ChaseConfig.OwnerBoostDuration
            event.boostReadyAt = workspace:GetServerTimeNow() + ChaseConfig.OwnerBoostCooldown
            send(player, 'PvPBoostReady', {visible = true, ready = false, cooldown = ChaseConfig.OwnerBoostCooldown})
        end
    elseif action == 'End' and session.pvpEvent then
        cancelPvp(session.pvpEvent, 'Stopped')
    elseif action == 'Ready' then
        sendProfile(player, session)
        if session.phase == 'Lobby' then send(player, 'Lobby', {}) end
    elseif action == 'Travel' and session.phase == 'Lobby' then
        local destination=argument=='Home' and PlayerFarm.home(player) or (argument=='Npc' and CFrame.new(0,4,-126))
        local character=player.Character
        local hum=character and character:FindFirstChildOfClass('Humanoid')
        if destination and hum and hum.Health>0 then character:PivotTo(destination) end
    elseif action == 'Start' then
        startRun(player)
    elseif action == 'Lobby' and session.phase == 'Results' then
        session.phase = 'Lobby'
        session.run = nil
        restore(player)
        send(player, 'Lobby', {})
        sendProfile(player, session)
    elseif action == 'End' and session.phase == 'Running' then
        finish(player, session, 'Stopped')
    elseif action == 'OpenTraining' and session.phase == 'Lobby' then
        sendProfile(player, session)
        send(player, 'OpenTraining', {})
    elseif action == 'Upgrade' and session.phase == 'Lobby' and type(argument) == 'string' then
        local ok, result = Progression.purchase(session.data, argument)
        if ok then
            markDirty(session)
            sendProfile(player, session)
            task.spawn(saveSession, player, session, 'Upgrade')
        end
        send(player, 'UpgradeResult', {ok = ok, stat = argument, result = result})
    elseif session.phase == 'Running' then
        Runner.input(session.run, action)
    end
end)

CollectionRemote.OnServerEvent:Connect(function(player, action, horseId, value)
    local session = sessions[player]
    if not session or session.phase ~= 'Lobby' or type(action) ~= 'string' then return end
    if action == 'Ready' then sendCollection(player, session); return end
    if type(horseId) ~= 'string' then return end
    local ok, reason
    if action == 'SetPlaced' then
        ok, reason = HorseCollectionStore.setPlaced(session.horseData, horseId, value == true)
    elseif action == 'Protect' then
        ok, reason = HorseCollectionStore.protect(session.horseData, horseId)
    else return end
    if ok then
        session.horseDirty = true; session.horseRevision += 1
        PlayerFarm.render(player, session.horseData)
        task.spawn(saveHorseSession, player, session, action)
    end
    sendCollection(player, session, ok and action or reason)
end)

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
    accumulated += dt
    local broadcast = accumulated >= Config.SnapshotInterval
    if broadcast then accumulated = 0 end
    for _, event in pvpEvents do
        if event.state == 'Pending' and workspace:GetServerTimeNow() >= event.deadline then
            startPvp(event, false)
        elseif (event.state == 'RunningPlayers' or event.state == 'RunningNpc') and workspace:GetServerTimeNow() >= event.startAt then
            local thiefSession, ownerSession = sessions[event.thief], sessions[event.owner]
            if not thiefSession or not thiefSession.run then cancelPvp(event, 'PlayerLeft'); continue end
            if thiefSession.phase == 'Countdown' then thiefSession.phase = 'Running'; send(event.thief, 'Running', {}) end
            if event.state == 'RunningPlayers' then
                if not ownerSession or not ownerSession.run then cancelPvp(event, 'PlayerLeft'); continue end
                if ownerSession.phase == 'Countdown' then ownerSession.phase = 'Running'; send(event.owner, 'Running', {}) end
                ownerSession.run.speed = ChaseConfig.BaseSpeed * (workspace:GetServerTimeNow() < event.boostUntil and ChaseConfig.OwnerBoostMultiplier or 1)
                local thiefEvents = Runner.step(thiefSession.run, dt)
                local ownerEvents = Runner.step(ownerSession.run, dt)
                for _, item in thiefEvents do send(event.thief, 'Effect', item); if item.kind == 'Hit' then event.gapAdjustment -= ChaseConfig.HitGapPenalty end end
                for _, item in ownerEvents do send(event.owner, 'Effect', item); if item.kind == 'Hit' then event.gapAdjustment += ChaseConfig.HitGapPenalty end end
                local gap = math.max(0, thiefSession.run.distance - ownerSession.run.distance + event.gapAdjustment)
                event.lastGap = gap
                event.catchHeld = gap <= ChaseConfig.PlayerCatchDistance and event.catchHeld + dt or 0
                if event.catchHeld >= ChaseConfig.PlayerCatchHoldSeconds then finishPvp(event, 'Captured')
                elseif thiefSession.run.distance >= event.goalDistance then finishPvp(event, 'Escaped') end
                if event.state == 'RunningPlayers' and broadcast then
                    for role, pair in {Thief = {event.thief, thiefSession}, Owner = {event.owner, ownerSession}} do
                        local p, s = pair[1], pair[2]
                        send(p, 'State', {distance=s.run.distance,elapsed=s.run.elapsed,health=s.run.health,maxHealth=s.run.maxHealth,
                            speed=s.run.speed,carrots=s.run.carrots,x=s.run.x,lane=s.run.lane,jumpAt=s.run.jumpAt,slideAt=s.run.slideAt,
                            hitAt=s.run.hitAt,chase=true,pvpRole=role,goalDistance=event.goalDistance,pursuerGap=gap,serverTime=workspace:GetServerTimeNow()})
                    end
                    local cooldown = math.max(0, event.boostReadyAt - workspace:GetServerTimeNow())
                    send(event.owner, 'PvPBoostReady', {visible = true, ready = cooldown <= 0, cooldown = cooldown})
                end
            else
                local events = Runner.step(thiefSession.run, dt)
                for _, item in events do send(event.thief, 'Effect', item) end
                event.lastGap = thiefSession.run.pursuerGap
                if thiefSession.run.done then finishPvp(event, thiefSession.run.outcome or 'Captured')
                elseif broadcast then send(event.thief, 'State', {distance=thiefSession.run.distance,elapsed=thiefSession.run.elapsed,
                    health=thiefSession.run.health,maxHealth=thiefSession.run.maxHealth,speed=thiefSession.run.speed,
                    carrots=thiefSession.run.carrots,x=thiefSession.run.x,lane=thiefSession.run.lane,jumpAt=thiefSession.run.jumpAt,
                    slideAt=thiefSession.run.slideAt,hitAt=thiefSession.run.hitAt,chase=true,pvpRole='Thief',
                    goalDistance=event.goalDistance,pursuerGap=thiefSession.run.pursuerGap,serverTime=workspace:GetServerTimeNow()}) end
            end
        end
    end
    for player, session in sessions do
        if session.pvpEvent then continue end
        if session.phase == 'Countdown' and workspace:GetServerTimeNow() >= session.startAt then
            session.phase = 'Running'
            send(player, 'Running', {})
        elseif session.phase == 'Running' then
            local events = Runner.step(session.run, dt)
            for _, event in events do send(player, 'Effect', event) end
            if session.run.done then
                finish(player, session, session.run.outcome or 'Health')
            elseif broadcast then
                send(player, 'State', {
                    distance = session.run.distance, elapsed = session.run.elapsed,
                    health = session.run.health, maxHealth = session.run.maxHealth,
                    speed = session.run.speed, carrots = session.run.carrots, x = session.run.x,
                    lane = session.run.lane, jumpAt = session.run.jumpAt,
                    slideAt = session.run.slideAt, hitAt = session.run.hitAt,
                    chase = session.run.chase, goalDistance = session.run.goalDistance,
                    pursuerGap = session.run.pursuerGap,
                    serverTime = workspace:GetServerTimeNow(),
                })
            end
        end
    end
end)

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do setup(player) end

Players.PlayerRemoving:Connect(function(player)
    local session = sessions[player]
    if session then
        local activePvp = session.pvpEvent or pvpByPlayer[player]
        if activePvp then cancelPvp(activePvp, 'PlayerLeft') end
        if session.chaseTarget and session.chaseTarget.slot then chaseResolved:Fire(session.chaseTarget.slot, false) end
        saveSession(player, session, 'Leave')
        saveHorseSession(player, session, 'Leave')
    end
    PlayerFarm.remove(player)
    sessions[player] = nil
end)

task.spawn(function()
    while task.wait(Config.AutosaveSeconds) do
        for player, session in sessions do
            task.spawn(saveSession, player, session, 'Autosave')
            task.spawn(saveHorseSession, player, session, 'Autosave')
        end
    end
end)

game:BindToClose(function()
    local pending = 0
    for player, session in sessions do
        if session.dirty then
            pending += 1
            task.spawn(function()
                saveSession(player, session, 'Shutdown')
                pending -= 1
            end)
        end
        if session.horseDirty then
            pending += 1
            task.spawn(function()
                saveHorseSession(player, session, 'Shutdown')
                pending -= 1
            end)
        end
    end
    local deadline = os.clock() + 20
    while pending > 0 and os.clock() < deadline do task.wait(.1) end
end)

local world = workspace:FindFirstChild('HorseRunWorld')
if not world or world:GetAttribute('LayoutVersion')~=3 then world=require(Shared.World).build() end
world:WaitForChild('StartGate').ProximityPrompt.Triggered:Connect(startRun)
world:WaitForChild('TrainingPad').ProximityPrompt.Triggered:Connect(function(player)
    local session = sessions[player]
    if session and session.phase == 'Lobby' then
        sendProfile(player, session)
        send(player, 'OpenTraining', {})
    end
end)

print('[HorseRun] Server ready — progression v2 / ownership journal v1 / ' .. PlayerStore.mode)
