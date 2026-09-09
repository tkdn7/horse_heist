-- Run on a local Studio CLIENT, while in the lobby.
return function()
    local gui=game.Players.LocalPlayer.PlayerGui.HorseRunUI
    assert(gui:GetAttribute('Phase')=='Lobby','Run this audio test from the lobby')
    local phase,motion=gui:GetAttribute('Phase'),gui:GetAttribute('MotionState')
    local gallop=game.SoundService.GameAudio.Gallop
    local ok,err=pcall(function()
        gui:SetAttribute('Phase','Running');gui:SetAttribute('MotionState','Run');task.wait(.2)
        assert(gallop.Playing and gallop.Volume>.1,'Grounded run has no hoof audio')
        for _,state in {'Jump','Air','Slide'} do
            gui:SetAttribute('MotionState',state);task.wait()
            assert(not gallop.Playing and gallop.Volume==0,state..' kept playing hooves')
            gui:SetAttribute('MotionState','Run');task.wait(.2)
            assert(gallop.Playing and gallop.Volume>.1,'Hoof audio failed to resume after '..state)
        end
        gui:SetAttribute('MotionState','Land');task.wait()
        assert(gallop.Playing,'Landing did not resume hooves')
        gui:SetAttribute('Phase','Results');task.wait()
        assert(not gallop.Playing and gallop.Volume==0,'Result retained hoof audio')
    end)
    gui:SetAttribute('Phase',phase);gui:SetAttribute('MotionState',motion)
    assert(ok,tostring(err))
    return {'Actual Gallop sound stops immediately in Jump/Air/Slide/Results and resumes on grounded run/landing'}
end
