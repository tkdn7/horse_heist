local Resolution={}
local active={Pending=true,RunningPlayers=true,RunningNpc=true}

-- Claim resolution synchronously, before ownership persistence can yield.
-- The server derives the role and outcome; the client sends only a match ID.
function Resolution.begin(event,outcome,actor,eventId)
    if not event or not active[event.state] then return nil end
    local role
    if actor then
        if eventId~=event.id then return nil end
        if actor==event.owner then role='Owner';outcome='Escaped'
        elseif actor==event.thief then role='Thief';outcome='Captured'
        else return nil end
    elseif event.state=='Pending' or (outcome~='Captured' and outcome~='Escaped') then
        return nil
    end
    event.state='Finished'
    return {outcome=outcome,giveUpBy=role}
end

return table.freeze(Resolution)
