local Horse=require(script.Parent.Horse)
local World={}
local green=Color3.fromRGB(116,169,92)
local cream=Color3.fromRGB(245,232,195)
local wood=Color3.fromRGB(103,77,51)

function World.part(parent,name,size,cf,color,material,shape)
    local p=Instance.new('Part'); p.Name=name; p.Size=size; p.CFrame=cf; p.Color=color
    p.Anchored=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Material=material or Enum.Material.SmoothPlastic
    if shape then p.Shape=shape end
    p.Parent=parent; return p
end

function World.sign(parent,text,cf,width,height)
    local p=World.part(parent,'Sign',Vector3.new(width,height,.35),cf,Color3.fromRGB(28,67,51))
    local ui=Instance.new('SurfaceGui'); ui.Face=Enum.NormalId.Front
    ui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; ui.PixelsPerStud=40; ui.Parent=p
    local label=Instance.new('TextLabel'); label.Size=UDim2.fromScale(.92,.86); label.Position=UDim2.fromScale(.04,.07)
    label.BackgroundTransparency=1; label.Text=text; label.TextColor3=cream; label.Font=Enum.Font.GothamBold
    label.TextScaled=true; label.Parent=ui
    return p
end

function World.tree(parent,x,z,scale)
    local s=scale or 1
    World.part(parent,'Trunk',Vector3.new(1.6,6,1.6)*s,CFrame.new(x,3*s,z),wood,Enum.Material.Wood)
    World.part(parent,'Canopy',Vector3.new(9,10,9)*s,CFrame.new(x,10*s,z),Color3.fromRGB(54,118,73),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
    World.part(parent,'CanopyLight',Vector3.new(7,7,7)*s,CFrame.new(x+2*s,12*s,z-.5*s),Color3.fromRGB(96,154,82),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
end

function World.fence(parent,x,z,length)
    for i=0,math.floor(length/8) do
        World.part(parent,'FencePost',Vector3.new(.6,3.7,.6),CFrame.new(x,1.85,z-i*8),cream,Enum.Material.Wood)
    end
    for _,y in {1.3,2.7} do
        World.part(parent,'FenceRail',Vector3.new(.35,.4,length),CFrame.new(x,y,z-length/2),cream,Enum.Material.Wood)
    end
end

function World.build()
    return require(script.Parent.FarmVisual).world()
end
return World
