--!strict

local Lifecycle={}

function Lifecycle.beginCooldown(slot:Model,now:number,duration:number):number?
	if slot:GetAttribute("Occupied")~=true then return nil end
	local refillAt=now+duration
	slot:SetAttribute("Occupied",false)
	slot:SetAttribute("LockedBy",nil)
	slot:SetAttribute("CooldownUntil",refillAt)
	for _,name in {"DisplayHorse","RarityHighlight","RarityEffects"} do
		local item=slot:FindFirstChild(name)
		if item then item:Destroy() end
	end
	local pad=slot:FindFirstChild("DisplayPad")
	if pad then
		for _,name in {"RarityGlow","StealPrompt"} do
			local item=pad:FindFirstChild(name)
			if item then item:Destroy() end
		end
	end
	return refillAt
end

function Lifecycle.remaining(refillAt:number,now:number):number
	return math.max(0,math.ceil(refillAt-now))
end

return Lifecycle
