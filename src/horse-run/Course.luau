local Config = require(script.Parent.Config)
local Course = {}

-- Deterministic course: both presentation and server rules use the same rows.
-- Every obstacle row leaves at least one lane clear. No random client rewards.
function Course.row(index, settings)
    settings = settings or {}
    local seed = math.floor(tonumber(settings.seed) or 0)
    local rowLength = math.max(Config.RowLength, tonumber(settings.rowLength) or Config.RowLength)
    local lane = ((index * 7 + seed * 5 + 1) % 3) - 1
    local distance = Config.CourseStart + index * rowLength
    local branch = (index + seed) % 6 == 4
    local log = not branch and (index + seed) % 4 == 3
    local blocked = log and {lane, lane == 1 and 0 or lane + 1} or {lane}
    local safe = -1
    for candidate = -1, 1 do
        if not table.find(blocked, candidate) then safe = candidate; break end
    end
    return {
        index = index, distance = distance,
        kind = branch and 'Branch' or (log and 'Log' or 'Fence'),
        lanes = blocked, safe = safe,
        -- Two carrots every other row: collecting everything cannot cancel drain.
        carrots = index % 2 == 0 and {
            {id = index .. ':a', distance = distance - 18, lane = safe},
            {id = index .. ':b', distance = distance - 10, lane = safe},
        } or {},
    }
end

function Course.near(distance, behind, ahead, settings)
    settings = settings or {}
    local rowLength = math.max(Config.RowLength, tonumber(settings.rowLength) or Config.RowLength)
    local rows = {}
    local first = math.max(0, math.floor((distance - behind - Config.CourseStart) / rowLength))
    local last = math.max(0, math.ceil((distance + ahead - Config.CourseStart) / rowLength))
    for i = first, last do table.insert(rows, Course.row(i, settings)) end
    return rows
end

return Course

