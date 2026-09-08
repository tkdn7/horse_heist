local Dog={}
function Dog.create(parent)
    local m=Instance.new('Model');m.Name='GuardDog'
    local function part(name,size,pos,color)
        local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos);p.Color=color
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=m
        return p
    end
    local brown=Color3.fromRGB(117,79,43);local dark=Color3.fromRGB(43,35,29)
    local root=part('Root',Vector3.one,Vector3.zero,dark);root.Transparency=1;m.PrimaryPart=root
    part('Body',Vector3.new(1.6,1.5,3),Vector3.new(0,1.7,0),brown)
    part('Head',Vector3.new(1.5,1.3,1.4),Vector3.new(0,2.4,-1.65),brown)
    part('Muzzle',Vector3.new(.95,.6,.8),Vector3.new(0,2.1,-2.5),dark)
    part('Collar',Vector3.new(1.7,.25,1.1),Vector3.new(0,1.9,-1.25),Color3.fromRGB(189,55,42))
    for _,side in {-1,1} do
        part('Ear'..side,Vector3.new(.4,.9,.55),Vector3.new(side*.55,3.25,-1.5),dark)
        part('Eye'..side,Vector3.new(.16,.16,.12),Vector3.new(side*.44,2.55,-2.36),Color3.new(1,1,.75))
        for _,z in {-1,1} do part('Leg_'..side..'_'..z,Vector3.new(.45,1.3,.55),Vector3.new(side*.6,.8,z),brown) end
    end
    part('Tail',Vector3.new(.35,.4,1.5),Vector3.new(0,2,2),dark)
    local poses={};for _,p in m:GetChildren() do poses[p]=p.CFrame end
    m.Parent=parent
    return {model=m,poses=poses}
end
function Dog.pose(dog,cf,time,running)
    for p,rest in dog.poses do
        local side,z=p.Name:match('Leg_([%-0-9]+)_([%-0-9]+)')
        local swing=side and running and math.sin(time*14)*tonumber(side)*tonumber(z)*.55 or 0
        p.CFrame=cf*rest*CFrame.Angles(swing,0,0)
    end
end
return Dog
