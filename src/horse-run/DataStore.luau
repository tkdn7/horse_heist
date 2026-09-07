local DataStoreService = game:GetService('DataStoreService')
local RunService = game:GetService('RunService')
local Progression = require(script.Parent.Progression)
local Store = DataStoreService:GetDataStore('HorseRunPlayerData_v2')
local DataStore = {}

-- Studio tests never touch live player records. Published servers use UpdateAsync.
DataStore.mode = RunService:IsStudio() and 'StudioTest' or 'Live'
local studioData = {}

local function retry(callback)
    local lastError
    for attempt = 1, 3 do
        local ok, result = pcall(callback)
        if ok then return true, result end
        lastError = result
        if attempt < 3 then task.wait(2 ^ (attempt - 1)) end
    end
    return false, lastError
end

function DataStore.load(userId)
    local key = 'Player_' .. userId
    if DataStore.mode == 'StudioTest' then
        return Progression.normalize(studioData[key]), nil
    end
    local ok, result = retry(function() return Store:GetAsync(key) end)
    if not ok then return nil, result end
    return Progression.normalize(result), nil
end

function DataStore.save(userId, data)
    local key = 'Player_' .. userId
    local clean = Progression.normalize(data)
    if DataStore.mode == 'StudioTest' then
        studioData[key] = clean
        return true
    end
    local ok, err = retry(function()
        return Store:UpdateAsync(key, function()
            return clean, {userId}
        end)
    end)
    return ok, err
end

return DataStore

