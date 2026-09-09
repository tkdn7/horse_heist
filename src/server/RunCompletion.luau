local Completion={}

function Completion.begin(session)
    if session.completing then return false end
    session.completing=true;session.returnAfterCompletion=false;session.phase='Resolving'
    if session.run then session.run.done=true end
    return true
end

function Completion.returnToLobby(session)
    if session.completing then
        -- Keep transactions/new runs locked, but allow walking around the farm.
        session.returnAfterCompletion=true
        return true
    end
    if session.phase~='Results' then return false end
    session.phase='Lobby';session.run=nil
    return true
end

function Completion.finish(session,data)
    if not session or not session.completing then return end
    data.background=session.returnAfterCompletion==true
    session.completing=false;session.returnAfterCompletion=nil
    session.phase=data.background and 'Lobby' or 'Results'
    if data.background then session.run=nil end
end

return table.freeze(Completion)
