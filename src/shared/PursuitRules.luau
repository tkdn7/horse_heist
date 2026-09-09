local Rules={MissPenalty=.04,MinimumPace=.60}

function Rules.pace(missed)
    return math.max(Rules.MinimumPace,1-math.max(0,missed)*Rules.MissPenalty)
end

-- Both roles copy the contested horse, never the owner's upgrades or a role bonus.
function Rules.stats(traits,initialDistance,course,npc)
    return {mode=npc and 'Chase' or 'PvP',speed=traits.Speed,maxHealth=traits.Stamina,
        ability=traits.Ability,initialDistance=initialDistance or 0,course=course,carrotPace=true}
end

return table.freeze(Rules)
