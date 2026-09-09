-- Articulated display limbs. The original union assets remain in the template.
local Legs={}
local function segment(model,name,size,cf,color,material)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=material
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=model
    return p
end
local function joint(name,a,b,c0,c1)
    local m=Instance.new('Motor6D');m.Name=name;m.Part0=a;m.Part1=b;m.C0=c0;m.C1=c1;m.Parent=a
    return m
end
function Legs.build(model)
    local result={}
    for _,motor in model:GetDescendants() do
        if motor:IsA('Motor6D') and (motor.Name=='Left Hip' or motor.Name=='Right Hip' or motor.Name=='Left Shoulder' or motor.Name=='Right Shoulder') then
            local source=motor.Part1
            if not source then continue end
            local top=source.CFrame*motor.C1
            local length=motor.C1.Y+source.Size.Y*.5
            local upperLength,lowerLength,hoofLength=length*.46,length*.43,length*.11
            local width=math.min(source.Size.X,source.Size.Z)*.64
            local upper=segment(model,motor.Name..' Upper',Vector3.new(width,upperLength,width*.95),top*CFrame.new(0,-upperLength/2,0),source.Color,source.Material)
            local lower=segment(model,motor.Name..' Lower',Vector3.new(width*.66,lowerLength,width*.7),top*CFrame.new(0,-upperLength-lowerLength/2,0),source.Color,source.Material)
            local hoof=segment(model,motor.Name..' Hoof',Vector3.new(width*.9,hoofLength,width*1.2),top*CFrame.new(0,-length+hoofLength/2,-width*.08),Color3.fromRGB(49,39,33),Enum.Material.SmoothPlastic)
            local link=Instance.new('Weld');link.Name='UpperLegLink';link.Part0=source;link.Part1=upper;link.C0=source.CFrame:ToObjectSpace(upper.CFrame);link.Parent=upper
            joint(motor.Name..' Knee',upper,lower,CFrame.new(0,-upperLength/2,0),CFrame.new(0,lowerLength/2,0))
            joint(motor.Name..' Fetlock',lower,hoof,CFrame.new(0,-lowerLength/2,0),CFrame.new(0,hoofLength/2,width*.08))
            source.Transparency=1
            result[motor.Name]={upper=upperLength,lower=lowerLength+hoofLength,front=motor.Name:find('Shoulder')~=nil}
        end
    end
    local count=0;for _ in result do count+=1 end
    model:SetAttribute('ArticulatedLegCount',count)
    return result
end

function Legs.sample(leg,cycle)
    local length=leg.upper+leg.lower
    local stance=.54
    local z,lift
    if cycle<stance then
        z=(-.36+.72*cycle/stance)*length;lift=0
    else
        local t=(cycle-stance)/(1-stance)
        local smooth=t*t*(3-2*t)
        z=(.36-.72*smooth)*length;lift=math.sin(t*math.pi)*length*.32
    end
    local down=length*.94-lift
    local distance=math.min(length*.995,math.sqrt(z*z+down*down))
    local angle=math.atan2(-z,down)
    local knee=math.acos(math.clamp((distance*distance-leg.upper^2-leg.lower^2)/(2*leg.upper*leg.lower),-1,1))*(leg.front and -1 or 1)
    local hip=angle-math.atan2(leg.lower*math.sin(knee),leg.upper+leg.lower*math.cos(knee))
    local hoof=-(hip+knee)*(cycle<stance and 1 or .45)
    return hip,knee,hoof
end
return Legs
