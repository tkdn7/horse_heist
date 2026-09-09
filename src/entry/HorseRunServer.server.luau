local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local HttpService = game:GetService('HttpService')
local Shared = ReplicatedStorage:WaitForChild('HorseRun')
local GlobalShared = ReplicatedStorage:WaitForChild('Shared')
local Config = require(Shared.Config)
Players.RespawnTime=Config.RespawnSeconds
local Runner = require(Shared.Runner)
local Progression = require(Shared.Progression)
local PlayerStore = require(Shared.DataStore)
local HorseRarity = require(GlobalShared:WaitForChild('HorseRarity'))
local Traits = require(GlobalShared:WaitForChild('HorseTraits'))
local ChaseConfig = require(GlobalShared:WaitForChild('ChaseConfig'))
local ServerModules = ServerScriptService:WaitForChild('Server')
local HorseCollectionStore = require(ServerModules:WaitForChild('HorseCollectionStore'))
local PlayerFarm = require(ServerModules:WaitForChild('PlayerFarm'))
local CharacterPlacement = require(ServerModules:WaitForChild('CharacterPlacement'))
local Characters = require(Shared.Characters)
local PursuitRules = require(GlobalShared.PursuitRules)
local PvpResolution = require(ServerModules:WaitForChild('PvpResolution'))
local RunCompletion = require(ServerModules:WaitForChild('RunCompletion'))
local pursuitAvatars=Shared:FindFirstChild('PursuitAvatars') or Instance.new('Folder')
pursuitAvatars.Name='PursuitAvatars';pursuitAvatars.Parent=Shared
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
    if kind=='Result' then RunCompletion.finish(sessions[player],data) end
    if kind=='State' then
        local run=sessions[player] and sessions[player].run
        if run then
            data.ability=run.ability;data.abilityReadyAt=run.abilityReadyAt
            data.jumpFrom=run.jumpFrom;data.jumpCount=run.jumpCount
            data.carrotPace=run.carrotPace;data.missedCarrots=run.missedCarrots;data.pace=run.pace
        end
    end
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
    payload.guardDog=session.data.GuardDog;payload.dogPrice=Traits.DogPrice
    payload.theftProtected=player:GetAttribute('FarmTheftEvent')~=nil
    payload.result = result
    CollectionRemote:FireClient(player, 'Collection', payload)
end

local function markDirty(session)
    session.dirty = true
    session.revision += 1
end

local function saveSession(player, session, reason)
    if session and session.economyBusy and reason~='EconomyPreflight' then return false end
    if not session or session.saving or not session.dirty then return true end
    if not session.canSave then return false end
    session.saving = true
    local revision = session.revision
    local ok, err = PlayerStore.save(player.UserId, session.data)
    if ok then session.data.StoreRevision=err.StoreRevision end
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

local function restore(player,expectedCharacter)
    local character = player.Character
    if expectedCharacter and character~=expectedCharacter then return end
    if character and CharacterPlacement.move(character,PlayerFarm.home(player,character)) then
        player:SetAttribute('TheftProtected',false)
    end
end

local function beginCompletion(player,session,extra)
    if not RunCompletion.begin(session) then return end
    -- Return the existing avatar before saving ownership or rebuilding displays.
    restore(player)
    local run=session.run
    local data={serial=session.serial,chase=run and run.chase or false,
        distance=math.floor(run and run.distance or 0),goalDistance=run and run.goalDistance,
        carrots=run and run.carrots or 0,hits=run and run.hits or 0}
    for key,value in extra or {} do data[key]=value end
    send(player,'RunEnded',data)
end

local function setup(player)
    if sessions[player] then return end
    -- Assign the streaming/spawn destination before any data-store requests can yield.
    PlayerFarm.prepareSpawn(player)
    local function placeCharacter(character)
        local started=os.clock()
        task.spawn(function()
            if character:WaitForChild('HumanoidRootPart',10) and character:WaitForChild('Humanoid',10) and player.Parent and player.Character==character then
                restore(player,character)
                player:SetAttribute('LastSpawnPlacementMs',math.floor((os.clock()-started)*1000))
            end
        end)
    end
    player.CharacterAdded:Connect(placeCharacter)
    if player.Character then placeCharacter(player.Character) end
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
    local horseData, horseLoadError = HorseCollectionStore.recoverSales(player.UserId)
    if not horseData then horseData = HorseCollectionStore.newData() end
    if not loadError and not horseLoadError and horseData.SaleTotal>data.SaleCreditTotal then
        local credited,result=PlayerStore.creditSales(player.UserId,horseData.SaleTotal)
        if credited then data=result else loadError=result end
    end
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
    if data.GuardDog then PlayerFarm.hireDog(player,horseData) end
    if player.Character then restore(player) end
    sendCollection(player, session)
    if loadError then send(player, 'SaveStatus', {ok = false, mode = PlayerStore.mode, reason = 'Load'}) end

    player.CharacterAdded:Connect(function(character)
        if session.completing then
            session.returnAfterCompletion=true
            send(player,'Lobby',{})
            return
        end
        local activePvp=session.pvpEvent or pvpByPlayer[player]
        if activePvp and cancelPvp then
            task.defer(cancelPvp, activePvp, 'CharacterReset')
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
    beginCompletion(player,session)
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
                    Traits = target.traits,
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

local function startRun(player, chaseTarget, ownedHorse)
    local session = sessions[player]
    if not session or (session.phase ~= 'Lobby' and session.phase ~= 'Results') then return end
    if session.economyBusy or session.pvpEvent or pvpByPlayer[player] or not session.horseCanSave or not session.canSave then return end
    if os.clock() - session.lastRequest < .75 then return end
    local character = player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    local humanoid = character and character:FindFirstChildWhichIsA('Humanoid')
    if not root or not humanoid or humanoid.Health <= 0 then return end
    session.lastRequest = os.clock()
    root.Anchored = true
    player:SetAttribute('TheftProtected',true)
    -- Real avatars wait away from guards while the client renders the course and mounted rider.
    character:PivotTo(CFrame.new(7000+player.UserId%1000*12,120,0))
    local stats
    local rarity
    if chaseTarget then
        rarity = HorseRarity.get(chaseTarget.rarityId)
        local individual=Traits.normalize(chaseTarget.rarityId,chaseTarget.traits,chaseTarget.horseId)
        local seed = Random.new():NextInteger(1, 1000000)
        stats = {
            mode = 'Chase', speed = individual.Speed, maxHealth = individual.Stamina, ability=individual.Ability,
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
        stats = ownedHorse and {speed=ownedHorse.Traits.Speed,maxHealth=ownedHorse.Traits.Stamina,ability=ownedHorse.Traits.Ability} or Progression.stats(session.data)
        session.chaseTarget = nil
    end
    session.phase = 'Countdown'
    session.run = Runner.new(stats)
    -- The prompt already consumed the two-second interaction; only the race countdown remains.
    session.startAt = workspace:GetServerTimeNow() + Config.Countdown
    session.serial += 1
    send(player, 'Start', {startAt = session.startAt, serial = session.serial,
        speed = stats.speed, maxHealth = stats.maxHealth, chase = chaseTarget ~= nil,
        goalDistance = stats.goalDistance, pursuerGap = stats.pursuerGap,
        rarityId = rarity and rarity.Id, rarityName = rarity and rarity.DisplayName,
        horseName = chaseTarget and chaseTarget.horseName or (ownedHorse and ownedHorse.TemplateId), course = stats.course,
        ability=stats.ability,stealSeconds=0})
end

chaseRequest.OnInvoke = function(player, target)
    if typeof(player) ~= 'Instance' or type(target) ~= 'table' then return false end
    local slot = target.slot
    if typeof(slot) ~= 'Instance' or not slot:IsDescendantOf(workspace) then return false end
    if slot:GetAttribute('Occupied') ~= true or slot:GetAttribute('LockedBy') ~= player.UserId then return false end
    local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    local pad=slot:FindFirstChild('DisplayPad')
    if not root or not pad or (root.Position-pad.Position).Magnitude>14 then return false end
    -- The slot is the server-owned source of identity and rolled values.
    target.horseId=slot:GetAttribute('HorseId');target.horseName=slot:GetAttribute('TemplateId');target.rarityId=slot:GetAttribute('RarityId')
    target.traits={Speed=slot:GetAttribute('Speed'),Stamina=slot:GetAttribute('Stamina'),Ability=slot:GetAttribute('Ability')}
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
    player:SetAttribute('TheftProtected',true)
    character:PivotTo(CFrame.new(7000+player.UserId%1000*12,120,0))
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
    for _,player in {event.thief,event.owner} do PlayerFarm.releaseTheftProtection(player,event.id) end
    if event.avatar then event.avatar:Destroy();event.avatar=nil end
end

cancelPvp = function(event, reason)
    if not event or event.state == 'Finished' or event.state == 'Cancelled' then return end
    event.state = 'Cancelled'
    clearPvp(event)
    for _, player in {event.thief, event.owner} do
        local session = sessions[player]
        if session then
            session.pvpEvent = nil; session.phase = 'Lobby'; session.run = nil; session.chaseTarget = nil
            restore(player); send(player, 'PvPCancelled', {reason = reason}); send(player, 'Lobby', {})
            sendCollection(player, session)
        end
    end
end

local function pvpStartPayload(event, role, run)
    return {
        eventId=event.id,startAt = event.startAt, serial = sessions[role == 'Thief' and event.thief or event.owner].serial,
        speed = run.speed, maxHealth = run.maxHealth, ability=run.ability, chase = true, pvpRole = role,
        initialDistance = run.distance, goalDistance = event.goalDistance, pursuerGap = ChaseConfig.OwnerInitialGap,
        rarityId = event.rarityId, rarityName = HorseRarity.get(event.rarityId).DisplayName,
        horseName = event.templateId, course = event.course,
        carrotPace=true,pursuerKind=event.ownerJoined and 'Player' or 'Farmer',
        pursuerAvatarId=event.ownerJoined and event.id or nil,ownerName=event.owner.DisplayName,
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
    event.catchHeld = 0
    if ownerJoined then
        event.avatar=Characters.runnerAvatar(pursuitAvatars,event.owner.Character)
        if not event.avatar then cancelPvp(event,'CharacterUnavailable');return end
        event.avatar.Name=event.id;event.avatar:SetAttribute('OwnerUserId',event.owner.UserId)
        event.avatar:SetAttribute('OwnerDisplayName',event.owner.DisplayName)
    end
    thiefSession.phase = 'Countdown'; thiefSession.serial += 1
    local thiefStats=PursuitRules.stats(event.traits,0,event.course,not ownerJoined)
    thiefStats.goalDistance=event.goalDistance;thiefStats.pursuerGap=ChaseConfig.OwnerInitialGap
    thiefStats.maximumPursuerGap=ChaseConfig.OwnerInitialGap
    thiefSession.run = Runner.new(thiefStats)
    send(event.thief, 'Start', pvpStartPayload(event, 'Thief', thiefSession.run))
    if ownerJoined then
        ownerSession.phase = 'Countdown'; ownerSession.serial += 1
        ownerSession.run = Runner.new(PursuitRules.stats(event.traits,-ChaseConfig.OwnerInitialGap,event.course,false))
        send(event.owner, 'Start', pvpStartPayload(event, 'Owner', ownerSession.run))
    else
        ownerSession.phase = 'Lobby'; ownerSession.pvpEvent = nil
        send(event.owner, 'PvPWaiting', {eventId=event.id,role='Owner',delegated=true,message = 'NPC가 대신 추격합니다.'})
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

local function finishPvp(event, outcome, actor, eventId)
    local resolution=PvpResolution.begin(event,outcome,actor,eventId)
    if not resolution then return end
    outcome=resolution.outcome
    local thiefSession, ownerSession = sessions[event.thief], sessions[event.owner]
    for role,pair in {Thief={event.thief,thiefSession},Owner={event.owner,ownerSession}} do
        if pair[2] and (role=='Thief' or event.ownerJoined or resolution.giveUpBy) then
            beginCompletion(pair[1],pair[2],{chase=true,pvpRole=role,eventId=event.id})
        end
    end
    local escaped = outcome == 'Escaped'
    local transferred, transferReason = false, nil
    if escaped then
        local ok,a,b=pcall(transferHorse,event)
        if ok then transferred,transferReason=a,b else transferReason='TransferFailed';warn('[HorseTransfer] '..tostring(a)) end
    end
    if escaped and not transferred then outcome = transferReason or 'TransferFailed'; escaped = false end
    local thiefRun = thiefSession and thiefSession.run
    local ownerRun = ownerSession and ownerSession.run
    clearPvp(event)
    if thiefSession then
        thiefSession.pvpEvent = nil; thiefSession.phase = 'Results'
        if thiefRun then thiefRun.done = true end
        if transferred then PlayerFarm.render(event.thief, thiefSession.horseData) end
        sendCollection(event.thief, thiefSession, transferred and 'Stolen' or nil)
        send(event.thief, 'Result', {eventId=event.id,giveUpBy=resolution.giveUpBy,chase = true, pvpRole = 'Thief', success = escaped, reason = outcome,
            distance = math.floor(thiefRun and thiefRun.distance or 0), goalDistance = event.goalDistance,
            carrots = thiefRun and thiefRun.carrots or 0, hits = thiefRun and thiefRun.hits or 0,
            pursuerGap = event.lastGap or ChaseConfig.OwnerInitialGap, rarityId = event.rarityId,
            horseName = event.templateId, capturedCount = #thiefSession.horseData.Horses,
            money = 0, exp = 0, levelUps = 0, level = thiefSession.data.Level, serial = thiefSession.serial})
    end
    if ownerSession then
        ownerSession.pvpEvent = nil
        if transferred then PlayerFarm.render(event.owner, ownerSession.horseData) end
        sendCollection(event.owner, ownerSession, transferred and 'LostHorse' or 'Defended')
        if event.ownerJoined or resolution.giveUpBy then
            ownerSession.phase = 'Results'
            if ownerRun then ownerRun.done = true end
            send(event.owner, 'Result', {eventId=event.id,giveUpBy=resolution.giveUpBy,chase = true, pvpRole = 'Owner', success = not escaped, reason = outcome,
                distance = math.floor(ownerRun and ownerRun.distance or 0), goalDistance = event.goalDistance,
                carrots = ownerRun and ownerRun.carrots or 0, hits = ownerRun and ownerRun.hits or 0,
                pursuerGap = event.lastGap or ChaseConfig.OwnerInitialGap, rarityId = event.rarityId,
                horseName = event.templateId, capturedCount = #ownerSession.horseData.Horses,
                money = 0, exp = 0, levelUps = 0, level = ownerSession.data.Level, serial = ownerSession.serial})
        else
            ownerSession.phase = 'Lobby'
            send(event.owner,'PvPResolved',{eventId=event.id})
        end
    end
end

PlayerFarm.setStealHandler(function(thief, owner, horseId, pad)
    local thiefSession, ownerSession = sessions[thief], sessions[owner]
    if thief == owner or not thiefSession or not ownerSession then return false end
    if thiefSession.economyBusy or ownerSession.economyBusy or not thiefSession.horseCanSave or not ownerSession.horseCanSave then return false end
    if thiefSession.phase ~= 'Lobby' or ownerSession.phase ~= 'Lobby' or pvpByPlayer[thief] or pvpByPlayer[owner] then return false end
    if thief:GetAttribute('FarmTheftEvent') or owner:GetAttribute('FarmTheftEvent') then return false end
    local horse = HorseCollectionStore.find(ownerSession.horseData, horseId)
    if not horse or not horse.Placed or HorseCollectionStore.isProtected(ownerSession.horseData, horseId) then return false end
    if pad:GetAttribute('HorseId') ~= horseId or pad:GetAttribute('ActiveStealId') then return false end
    local root=thief.Character and thief.Character:FindFirstChild('HumanoidRootPart')
    local hum=thief.Character and thief.Character:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 or (root.Position-pad.Position).Magnitude>14 then return false end
    local event = {id = HttpService:GenerateGUID(false), state = 'Pending', thief = thief, owner = owner,
        horseId = horse.Id, templateId = horse.TemplateId, rarityId = horse.RarityId, pad = pad,
        traits=table.clone(horse.Traits),
        deadline = workspace:GetServerTimeNow() + ChaseConfig.JoinWindowSeconds}
    pvpEvents[event.id] = event; pvpByPlayer[thief] = event; pvpByPlayer[owner] = event
    -- These locks are acquired before any yield; the entire farms are protected, not just the selected pad.
    PlayerFarm.protectForTheft(thief,event.id);PlayerFarm.protectForTheft(owner,event.id)
    sendCollection(thief,thiefSession);sendCollection(owner,ownerSession)
    thiefSession.pvpEvent = event; ownerSession.pvpEvent = event
    thiefSession.run=nil;ownerSession.run=nil
    thiefSession.phase = 'PvPWaiting'; ownerSession.phase = 'PvPInvited'; pad:SetAttribute('ActiveStealId', event.id)
    if not anchorForRun(thief) then cancelPvp(event,'CharacterUnavailable');return false end
    send(thief, 'PvPWaiting', {eventId = event.id, role='Thief',ownerName = owner.DisplayName, deadline = event.deadline})
    send(owner, 'PvPInvitation', {eventId = event.id, thiefName = thief.DisplayName,
        rarityId = horse.RarityId, horseName = horse.TemplateId, deadline = event.deadline})
    return true
end)

Remote.OnServerEvent:Connect(function(player, action, argument)
    local session = sessions[player]
    if not session or type(action) ~= 'string' then return end
    if session.economyBusy then return end
    if session.phase == 'Running' and (action == 'Left' or action == 'Right') then
        if type(argument) ~= 'number' or argument ~= argument or math.abs(argument) == math.huge
            or argument % 1 ~= 0 or argument <= session.run.laneSequence then return end
        -- Advance the acknowledgement even if the input budget or turn cooldown rejects it.
        session.run.laneSequence = argument
    end
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
    elseif action == 'PvPGiveUp' and type(argument)=='table' then
        finishPvp(pvpByPlayer[player],nil,player,argument.eventId)
    elseif action == 'End' and pvpByPlayer[player] then
        local event=pvpByPlayer[player]
        finishPvp(event,nil,player,event.id)
    elseif action == 'Ready' then
        sendProfile(player, session)
        if session.phase == 'Lobby' then send(player, 'Lobby', {}) end
    elseif action == 'Travel' and session.phase == 'Lobby' then
        local destination=argument=='Home' and PlayerFarm.home(player,player.Character) or (argument=='Npc' and CFrame.new(0,4,-126))
        local character=player.Character
        local hum=character and character:FindFirstChildOfClass('Humanoid')
        if destination and hum and hum.Health>0 then CharacterPlacement.move(character,destination) end
    elseif action == 'Start' then
        startRun(player)
    elseif action == 'Lobby' and RunCompletion.returnToLobby(session) then
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
    if session.economyBusy or session.pvpEvent or pvpByPlayer[player] or session.horseSaving or session.saving then return end
    if not session.horseCanSave or not session.canSave then sendCollection(player,session,'SaveUnavailable');return end
    if action=='Ride' and type(horseId)=='string' then
        local horse=HorseCollectionStore.find(session.horseData,horseId)
        if horse then startRun(player,nil,horse) end
        return
    end
    if action=='Sell' or action=='HireDog' then
        if action=='Sell' and (type(horseId)~='string' or not HorseCollectionStore.find(session.horseData,horseId)) then return end
        session.economyBusy=true
        local ok,result=pcall(function()
            if not saveSession(player,session,'EconomyPreflight') or not saveHorseSession(player,session,'EconomyPreflight') then return 'SaveUnavailable' end
            if action=='Sell' then
                local sold,data=HorseCollectionStore.sell(player.UserId,horseId)
                if not sold then return data end
                session.horseData=data;session.horseDirty=false;session.horseRevision+=1
                PlayerFarm.render(player,data)
                local credited,profile=PlayerStore.creditSales(player.UserId,data.SaleTotal)
                if not credited then session.canSave=false;return 'CreditPending' end
                session.data=profile;session.dirty=false
                return 'Sold'
            end
            local purchased,profile=PlayerStore.hireDog(player.UserId,Traits.DogPrice)
            if not purchased then return profile end
            session.data=profile;session.dirty=false
            PlayerFarm.hireDog(player,session.horseData)
            return 'DogHired'
        end)
        session.economyBusy=false
        if not ok then warn('[HorseEconomy] '..tostring(result));result='SaveUnavailable' end
        sendProfile(player,session);sendCollection(player,session,result)
        return
    end
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
                local thiefEvents = Runner.step(thiefSession.run, dt)
                local ownerEvents = Runner.step(ownerSession.run, dt)
                for _, item in thiefEvents do send(event.thief, 'Effect', item) end
                for _, item in ownerEvents do send(event.owner, 'Effect', item) end
                local gap = PursuitRules.gap(thiefSession.run,ownerSession.run)
                event.lastGap = gap
                event.catchHeld = gap <= ChaseConfig.PlayerCatchDistance and event.catchHeld + dt or 0
                if event.catchHeld >= ChaseConfig.PlayerCatchHoldSeconds then finishPvp(event, 'Captured')
                elseif thiefSession.run.distance >= event.goalDistance then finishPvp(event, 'Escaped') end
                if event.state == 'RunningPlayers' and broadcast then
                    for role, pair in {Thief = {event.thief, thiefSession}, Owner = {event.owner, ownerSession}} do
                        local p, s = pair[1], pair[2]
                        send(p, 'State', {distance=s.run.distance,elapsed=s.run.elapsed,health=s.run.health,maxHealth=s.run.maxHealth,
                            speed=s.run.speed,carrots=s.run.carrots,x=s.run.x,lane=s.run.lane,laneSequence=s.run.laneSequence,jumpAt=s.run.jumpAt,slideAt=s.run.slideAt,
                            hitAt=s.run.hitAt,chase=true,pvpRole=role,goalDistance=event.goalDistance,pursuerGap=gap,
                            opponentX=(role=='Thief' and ownerSession or thiefSession).run.x,
                            opponentElapsed=(role=='Thief' and ownerSession or thiefSession).run.elapsed,
                            opponentSpeed=(role=='Thief' and ownerSession or thiefSession).run.speed,
                            opponentHeight=Runner.heightAt((role=='Thief' and ownerSession or thiefSession).run,(role=='Thief' and ownerSession or thiefSession).run.elapsed),
                            opponentSliding=Runner.isSliding((role=='Thief' and ownerSession or thiefSession).run,(role=='Thief' and ownerSession or thiefSession).run.elapsed),
                            serverTime=workspace:GetServerTimeNow()})
                    end
                end
            else
                local events = Runner.step(thiefSession.run, dt)
                for _, item in events do send(event.thief, 'Effect', item) end
                event.lastGap = thiefSession.run.pursuerGap
                if thiefSession.run.done then finishPvp(event, thiefSession.run.outcome or 'Captured')
                elseif broadcast then send(event.thief, 'State', {distance=thiefSession.run.distance,elapsed=thiefSession.run.elapsed,
                    health=thiefSession.run.health,maxHealth=thiefSession.run.maxHealth,speed=thiefSession.run.speed,
                    carrots=thiefSession.run.carrots,x=thiefSession.run.x,lane=thiefSession.run.lane,laneSequence=thiefSession.run.laneSequence,jumpAt=thiefSession.run.jumpAt,
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
                    laneSequence = session.run.laneSequence,
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
if not world then world=require(Shared.World).build() end
require(Shared.FarmVisual).alignRoad(world)
world:WaitForChild('StartGate').ProximityPrompt.Triggered:Connect(startRun)
world:WaitForChild('TrainingPad').ProximityPrompt.Triggered:Connect(function(player)
    local session = sessions[player]
    if session and session.phase == 'Lobby' then
        sendProfile(player, session)
        send(player, 'OpenTraining', {})
    end
end)

print('[HorseRun] Server ready — progression v2 / ownership journal v1 / ' .. PlayerStore.mode)
