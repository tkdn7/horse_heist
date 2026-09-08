local Traits={}
Traits.Order={'Bronze','Silver','Gold','Champion','Royal','Legend'}
Traits.Abilities={'SpeedBoost','DoubleJump','BreakObstacle'}
Traits.AbilityNames={None='없음',SpeedBoost='질주',DoubleJump='2단 점프',BreakObstacle='장애물 파괴'}
Traits.Ranges={
    Bronze={speed={24,28},stamina={60,79},base=100,chance=0},
    Silver={speed={29,33},stamina={80,99},base=300,chance=0},
    Gold={speed={34,38},stamina={100,119},base=900,chance=.30},
    Champion={speed={39,43},stamina={120,139},base=2700,chance=.45},
    Royal={speed={44,48},stamina={140,159},base=8100,chance=.60},
    Legend={speed={49,53},stamina={160,179},base=24300,chance=.75},
}
Traits.DogPrice=1500
function Traits.seed(id)
    local n=7
    for i=1,#id do n=(n*131+id:byte(i))%2147483647 end
    return n
end
function Traits.roll(rarity,random)
    local range=Traits.Ranges[rarity] or Traits.Ranges.Bronze
    local speed=random:NextInteger(range.speed[1],range.speed[2])
    local stamina=random:NextInteger(range.stamina[1],range.stamina[2])
    local ability='None'
    if random:NextNumber()<range.chance then ability=Traits.Abilities[random:NextInteger(1,#Traits.Abilities)] end
    return {Speed=speed,Stamina=stamina,Ability=ability}
end
function Traits.normalize(rarity,raw,id)
    local range=Traits.Ranges[rarity] or Traits.Ranges.Bronze
    local fallback=Traits.roll(rarity,Random.new(Traits.seed(tostring(id or 'legacy'))))
    if type(raw)~='table' then return fallback end
    local function value(v,bounds,default)
        if type(v)~='number' or v~=v then return default end
        return math.clamp(math.floor(v),bounds[1],bounds[2])
    end
    return {Speed=value(raw.Speed,range.speed,fallback.Speed),Stamina=value(raw.Stamina,range.stamina,fallback.Stamina),
        Ability=range.chance>0 and table.find(Traits.Abilities,raw.Ability) and raw.Ability or 'None'}
end
function Traits.price(rarity,raw,id)
    local range=Traits.Ranges[rarity] or Traits.Ranges.Bronze
    local t=Traits.normalize(rarity,raw,id)
    local speedQuality=(t.Speed-range.speed[1])/(range.speed[2]-range.speed[1])
    local staminaQuality=(t.Stamina-range.stamina[1])/(range.stamina[2]-range.stamina[1])
    return math.floor(range.base*(1+.3*speedQuality+.3*staminaQuality)*(t.Ability~='None' and 1.4 or 1)+.5)
end
return Traits
