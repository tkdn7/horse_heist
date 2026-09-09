local Rules={MissGapPenalty=2,HitGapPenalty=6}

function Rules.gap(thief,owner)
    return math.max(0,thief.distance-owner.distance-(thief.penaltyDistance or 0)+(owner.penaltyDistance or 0))
end

-- Both roles copy the contested horse, never the owner's upgrades or a role bonus.
function Rules.stats(traits,initialDistance,course,npc)
    return {mode=npc and 'Chase' or 'PvP',speed=traits.Speed,maxHealth=traits.Stamina,
        ability=traits.Ability,initialDistance=initialDistance or 0,course=course,carrotPace=true}
end

return table.freeze(Rules)
