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
    local conflict=false
    local function change(raw)
        conflict=false
        if Progression.normalize(raw).StoreRevision~=clean.StoreRevision then conflict=true;return nil end
        local nextData=Progression.normalize(clean);nextData.StoreRevision+=1
        return nextData
    end
    if DataStore.mode == 'StudioTest' then
        local nextData=change(studioData[key])
        if conflict then return false,'RevisionConflict' end
        studioData[key] = nextData
        return true,Progression.normalize(nextData)
    end
    local ok, err = retry(function()
        return Store:UpdateAsync(key, change)
    end)
    if conflict then return false,'RevisionConflict' end
    return ok, err
end

local function update(userId,callback)
    local key='Player_'..userId
    if DataStore.mode=='StudioTest' then
        studioData[key]=callback(studioData[key])
        return true,Progression.normalize(studioData[key])
    end
    return retry(function() return Store:UpdateAsync(key,callback) end)
end
function DataStore.creditSales(userId,total)
    return update(userId,function(raw)
        local data=Progression.normalize(raw)
        local delta=math.max(0,total-data.SaleCreditTotal)
        data.Money+=delta;data.SaleCreditTotal=math.max(total,data.SaleCreditTotal)
        data.StoreRevision+=1
        return data
    end)
end
function DataStore.hireDog(userId,cost)
    local insufficient=false
    local ok,data=update(userId,function(raw)
        local current=Progression.normalize(raw)
        insufficient=false
        if not current.GuardDog then
            if current.Money<cost then insufficient=true;return current end
            current.Money-=cost;current.GuardDog=true
            current.StoreRevision+=1
        end
        return current
    end)
    if not ok then return false,data end
    if insufficient then return false,'Money' end
    return true,data
end

return DataStore

