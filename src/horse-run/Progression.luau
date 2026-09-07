local Config = require(script.Parent.Config)
local Progression = {}

function Progression.newData()
    return {
        Version = Config.Version,
        Money = Config.InitialMoney,
        Level = 1,
        Exp = 0,
        BestDistance = 0,
        TotalDistance = 0,
        TotalRuns = 0,
        CarrotsCollected = 0,
        Upgrades = {Speed = 1, Stamina = 1},
    }
end

local function integer(value, fallback, minimum, maximum)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return math.clamp(math.floor(value), minimum, maximum)
end

function Progression.normalize(raw)
    local data = Progression.newData()
    if type(raw) ~= 'table' then return data end
    data.Money = integer(raw.Money, data.Money, 0, 9e15)
    data.Level = integer(raw.Level, data.Level, 1, Config.MaxLevel)
    data.Exp = integer(raw.Exp, data.Exp, 0, 9e15)
    data.BestDistance = integer(raw.BestDistance or (raw.Stats and raw.Stats.BestDistance), 0, 0, 9e15)
    data.TotalDistance = integer(raw.TotalDistance or (raw.Stats and raw.Stats.TotalDistance), 0, 0, 9e15)
    data.TotalRuns = integer(raw.TotalRuns or (raw.Stats and raw.Stats.TotalRuns), 0, 0, 9e15)
    data.CarrotsCollected = integer(raw.CarrotsCollected or (raw.Stats and raw.Stats.CarrotsCollected), 0, 0, 9e15)
    local upgrades = type(raw.Upgrades) == 'table' and raw.Upgrades or {}
    data.Upgrades.Speed = integer(upgrades.Speed, 1, 1, Config.MaxUpgradeLevel)
    data.Upgrades.Stamina = integer(upgrades.Stamina, 1, 1, Config.MaxUpgradeLevel)
    data.Version = Config.Version
    while data.Level < Config.MaxLevel do
        local needed = Progression.expNeeded(data.Level)
        if data.Exp < needed then break end
        data.Exp -= needed
        data.Level += 1
    end
    if data.Level >= Config.MaxLevel then data.Exp = 0 end
    return data
end

function Progression.expNeeded(level)
    if level >= Config.MaxLevel then return 0 end
    return math.floor(Config.LevelExpBase * Config.LevelExpGrowth ^ (level - 1) + 0.5)
end

function Progression.upgradeCost(stat, currentLevel)
    local base = Config.UpgradeCosts[stat]
    if not base or currentLevel >= Config.MaxUpgradeLevel then return nil end
    return math.max(1, math.floor(base * Config.UpgradeGrowth ^ (currentLevel - 1) + 0.5))
end

function Progression.stats(data)
    local levelMultiplier = 1 + (data.Level - 1) * 0.01
    return {
        speed = (Config.Speed + Config.UpgradeGains.Speed * (data.Upgrades.Speed - 1)) * levelMultiplier,
        maxHealth = (Config.MaxHealth + Config.UpgradeGains.Stamina * (data.Upgrades.Stamina - 1)) * levelMultiplier,
    }
end

function Progression.grantRun(data, money, exp, distance, carrots)
    data.Money = math.max(0, data.Money + math.max(0, math.floor(money)))
    data.Exp += math.max(0, math.floor(exp))
    data.BestDistance = math.max(data.BestDistance, math.max(0, math.floor(distance)))
    data.TotalDistance += math.max(0, math.floor(distance))
    data.TotalRuns += 1
    data.CarrotsCollected += math.max(0, math.floor(carrots))
    local levels = 0
    while data.Level < Config.MaxLevel do
        local needed = Progression.expNeeded(data.Level)
        if data.Exp < needed then break end
        data.Exp -= needed
        data.Level += 1
        levels += 1
    end
    if data.Level >= Config.MaxLevel then data.Exp = 0 end
    return levels
end

function Progression.purchase(data, stat)
    if stat ~= 'Speed' and stat ~= 'Stamina' then return false, 'InvalidStat' end
    local current = data.Upgrades[stat]
    local cost = Progression.upgradeCost(stat, current)
    if not cost then return false, 'Max' end
    if data.Money < cost then return false, 'Money' end
    data.Money -= cost
    data.Upgrades[stat] += 1
    return true, cost
end

function Progression.clientProfile(data, saveMode)
    local stats = Progression.stats(data)
    return {
        money = data.Money, level = data.Level, exp = data.Exp,
        nextExp = Progression.expNeeded(data.Level), best = data.BestDistance,
        totalDistance = data.TotalDistance, totalRuns = data.TotalRuns,
        carrots = data.CarrotsCollected, upgrades = table.clone(data.Upgrades),
        speed = stats.speed, maxHealth = stats.maxHealth,
        speedCost = Progression.upgradeCost('Speed', data.Upgrades.Speed),
        staminaCost = Progression.upgradeCost('Stamina', data.Upgrades.Stamina),
        saveMode = saveMode,
    }
end

return Progression

