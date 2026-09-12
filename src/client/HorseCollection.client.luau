local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Traits=require(ReplicatedStorage.Shared.HorseTraits)
local HorseRarity=require(ReplicatedStorage.Shared.HorseRarity)
local Horse=require(ReplicatedStorage:WaitForChild("HorseRun"):WaitForChild("Horse"))
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("HorseRun"):WaitForChild("HorseCollectionEvent")
local gui=Instance.new("ScreenGui"); gui.Name="HorseCollectionUI"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local function corner(parent,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 12); c.Parent=parent end
local open=Instance.new("TextButton"); open.Name="OpenCollection"; open.Text="내 말  🐴"; open.Size=UDim2.fromOffset(124,44)
open.Position=UDim2.new(1,-144,0,96); open.BackgroundColor3=Color3.fromRGB(29,76,58); open.TextColor3=Color3.fromRGB(251,246,229)
open.Font=Enum.Font.GothamBold; open.TextSize=17; open.BorderSizePixel=0; open.Parent=gui; corner(open)
local shade=Instance.new("Frame"); shade.Name="Shade"; shade.Size=UDim2.fromScale(1,1); shade.BackgroundColor3=Color3.fromRGB(9,25,20)
shade.BackgroundTransparency=.25; shade.Visible=false; shade.Parent=gui
local panel=Instance.new("Frame"); panel.Name="Panel"; panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5)
panel.Size=UDim2.fromOffset(900,590); panel.BackgroundColor3=Color3.fromRGB(251,246,229); panel.BorderSizePixel=0; panel.Parent=shade; corner(panel,18)
local panelScale=Instance.new("UIScale"); panelScale.Parent=panel
local function resize()
	local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
	panelScale.Scale=math.min(1,(viewport.X-20)/900,(viewport.Y-20)/590)
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
resize()
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(22,15); title.Size=UDim2.new(1,-90,0,38)
title.Text="내 말 창고"; title.TextColor3=Color3.fromRGB(29,76,58); title.Font=Enum.Font.GothamBlack; title.TextSize=28; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=panel
local close=Instance.new("TextButton"); close.Text="×"; close.Size=UDim2.fromOffset(44,38); close.Position=UDim2.new(1,-58,0,14)
close.BackgroundColor3=Color3.fromRGB(234,239,218); close.TextColor3=Color3.fromRGB(29,76,58); close.Font=Enum.Font.GothamBold; close.TextSize=25; close.Parent=panel; corner(close)
local note=Instance.new("TextLabel"); note.BackgroundTransparency=1; note.Position=UDim2.fromOffset(22,55); note.Size=UDim2.new(1,-44,0,36)
note.Text="농장 배치 최대 12마리 · 보호 슬롯 1개"; note.TextColor3=Color3.fromRGB(100,119,100); note.Font=Enum.Font.GothamMedium; note.TextSize=15; note.TextXAlignment=Enum.TextXAlignment.Left; note.Parent=panel
local hire=Instance.new('TextButton');hire.Name='HireDog';hire.Position=UDim2.fromOffset(22,95);hire.Size=UDim2.new(1,-44,0,36)
hire.Text='경비견 고용 · 1,500원';hire.Font=Enum.Font.GothamBold;hire.TextSize=16;hire.TextColor3=Color3.fromRGB(251,246,229);hire.BackgroundColor3=Color3.fromRGB(29,76,58);hire.Parent=panel;corner(hire)
local previewCard=Instance.new("Frame");previewCard.Name="HorsePreview";previewCard.Position=UDim2.fromOffset(18,141);previewCard.Size=UDim2.fromOffset(238,404)
previewCard.BackgroundColor3=Color3.fromRGB(29,76,58);previewCard.BorderSizePixel=0;previewCard.Parent=panel;corner(previewCard,14)
local previewTitle=Instance.new("TextLabel");previewTitle.Name="PreviewTitle";previewTitle.BackgroundTransparency=1;previewTitle.Position=UDim2.fromOffset(12,8);previewTitle.Size=UDim2.new(1,-24,0,30)
previewTitle.Text="말을 선택하세요";previewTitle.TextColor3=Color3.fromRGB(251,246,229);previewTitle.Font=Enum.Font.GothamBold;previewTitle.TextSize=17;previewTitle.TextWrapped=true;previewTitle.Parent=previewCard
local viewport=Instance.new("ViewportFrame");viewport.Name="Viewport";viewport.Position=UDim2.fromOffset(12,44);viewport.Size=UDim2.new(1,-24,0,270)
viewport.BackgroundColor3=Color3.fromRGB(218,229,204);viewport.BorderSizePixel=0;viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.fromRGB(255,244,220);viewport.LightDirection=Vector3.new(-1,-1,-1);viewport.Parent=previewCard;corner(viewport,12)
local previewCamera=Instance.new("Camera");previewCamera.Name="PreviewCamera";previewCamera.FieldOfView=34;previewCamera.Parent=viewport;viewport.CurrentCamera=previewCamera
local previewWorld=Instance.new("WorldModel");previewWorld.Name="PreviewWorld";previewWorld.Parent=viewport
local previewInfo=Instance.new("TextLabel");previewInfo.Name="PreviewInfo";previewInfo.BackgroundTransparency=1;previewInfo.Position=UDim2.fromOffset(12,323);previewInfo.Size=UDim2.new(1,-24,0,65)
previewInfo.Text="오른쪽 목록에서 말을 골라\n외형을 확인하세요.";previewInfo.TextColor3=Color3.fromRGB(234,239,218);previewInfo.Font=Enum.Font.GothamMedium;previewInfo.TextSize=14;previewInfo.TextWrapped=true;previewInfo.Parent=previewCard
local list=Instance.new("ScrollingFrame"); list.Name="HorseList"; list.Position=UDim2.fromOffset(268,141); list.Size=UDim2.new(1,-286,1,-195)
list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=7; list.Parent=panel
list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new()
local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,8); layout.Parent=list
local status=Instance.new("TextLabel"); status.BackgroundTransparency=1; status.Position=UDim2.new(0,22,1,-44); status.Size=UDim2.new(1,-44,0,26)
status.Text=""; status.TextColor3=Color3.fromRGB(100,119,100); status.Font=Enum.Font.GothamBold; status.TextSize=14; status.Parent=panel
local data={horses={},maxPlaced=12}
local selectedHorseId=nil
local previewModel=nil
local previewAngle=math.rad(145)
local previewCenter=Vector3.zero
local confirmUntil=0
hire.Activated:Connect(function()
    if data.guardDog then return end
    if os.clock()>confirmUntil then
        confirmUntil=os.clock()+5;hire.Text='1,500원으로 영구 고용? 다시 누르기'
    else remote:FireServer('HireDog');confirmUntil=0;hire.Text='고용 처리 중…' end
end)
local function button(parent,textValue,x,width)
	local b=Instance.new("TextButton"); b.Text=textValue; b.Position=UDim2.new(1,x,0,14); b.Size=UDim2.fromOffset(width,42)
	b.BackgroundColor3=Color3.fromRGB(29,76,58); b.TextColor3=Color3.fromRGB(251,246,229); b.Font=Enum.Font.GothamBold; b.TextSize=14; b.BorderSizePixel=0; b.Parent=parent; corner(b,10); return b
end
local function showPreview(horse)
	previewModel=nil
	for _,child in previewWorld:GetChildren() do child:Destroy() end
	if not horse then
		previewTitle.Text="말을 선택하세요"
		previewTitle.TextColor3=Color3.fromRGB(251,246,229)
		previewInfo.Text="오른쪽 목록에서 말을 골라\n외형을 확인하세요."
		return
	end
	local rarity=HorseRarity.get(horse.rarityId)
	previewTitle.Text=rarity.DisplayName.." · "..horse.templateId
	previewTitle.TextColor3=rarity.Color
	previewInfo.Text=string.format("속도 %d  ·  체력 %d\n능력: %s",horse.speed,horse.stamina,Traits.AbilityNames[horse.ability] or "없음")
	local ok,model=pcall(Horse.clone,previewWorld,horse.templateId)
	if not ok or not model then
		previewInfo.Text="미리보기를 불러오지 못했습니다.\n"..previewInfo.Text
		warn("[HorseCollection] Preview failed: "..tostring(model))
		return
	end
	previewModel=model
	previewAngle=math.rad(145)
	Horse.pose(model,CFrame.identity,0,false)
	local bounds,boundsSize=model:GetBoundingBox()
	previewCenter=bounds.Position
	local centeredRotation=CFrame.new(previewCenter)*CFrame.Angles(0,previewAngle,0)*CFrame.new(-previewCenter)
	Horse.pose(model,centeredRotation,0,false)
	local highlight=Instance.new("Highlight");highlight.Name="RarityHighlight";highlight.Adornee=model;highlight.FillColor=rarity.Color;highlight.FillTransparency=.94
	highlight.OutlineColor=rarity.Color;highlight.OutlineTransparency=.2;highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;highlight.Parent=previewWorld
	local radius=math.max(boundsSize.X,boundsSize.Y,boundsSize.Z)*.62
	local distance=math.max(9,radius/math.tan(math.rad(previewCamera.FieldOfView*.5)))
	local focus=previewCenter
	previewCamera.CFrame=CFrame.lookAt(focus+Vector3.new(distance*.68,distance*.18,distance),focus)
end
RunService.RenderStepped:Connect(function(dt)
	if not shade.Visible or not previewModel or not previewModel.Parent then return end
	previewAngle=(previewAngle+dt*math.rad(24))%(math.pi*2)
	local centeredRotation=CFrame.new(previewCenter)*CFrame.Angles(0,previewAngle,0)*CFrame.new(-previewCenter)
	Horse.pose(previewModel,centeredRotation,0,false)
end)
local function render()
    hire.Text=data.guardDog and '경비견이 농장을 지키고 있습니다' or '경비견 고용 · 1,500원'
    hire.Active=not data.guardDog
	for _,child in list:GetChildren() do if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end end
	if #data.horses==0 then
		selectedHorseId=nil;showPreview(nil)
		local empty=Instance.new("TextLabel"); empty.BackgroundTransparency=1; empty.Size=UDim2.new(1,0,0,90); empty.Text="아직 획득한 말이 없습니다.\nNPC 농장에서 말을 훔쳐 탈출해 보세요."
		empty.TextColor3=Color3.fromRGB(100,119,100); empty.Font=Enum.Font.GothamMedium; empty.TextSize=17; empty.Parent=list
	else
		local selected
		for _,horse in data.horses do if horse.id==selectedHorseId then selected=horse;break end end
		if not selected then selected=data.horses[1];selectedHorseId=selected.id end
		showPreview(selected)
		for _,horse in data.horses do
			local isSelected=horse.id==selectedHorseId
			local row=Instance.new("Frame"); row.Name="Horse_"..horse.id; row.Size=UDim2.new(1,-8,0,134); row.BackgroundColor3=isSelected and Color3.fromRGB(218,229,204) or Color3.fromRGB(234,239,218); row.BorderSizePixel=0; row.Parent=list; corner(row)
			local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Position=UDim2.fromOffset(14,8); label.Size=UDim2.new(1,-100,0,67)
			local protection=horse.newProtectionLeft>0 and string.format(" · 신규 보호 %d:%02d",math.floor(horse.newProtectionLeft/60),horse.newProtectionLeft%60) or ""
			label.Text=string.format("%s  %s%s%s",horse.rarityId,horse.templateId,horse.placed and " · 농장" or " · 창고",horse.protected and " · 🔒" or protection)
			label.Text..=string.format('\n속도 %d · 체력 %d · 능력: %s\n판매가 %d원',horse.speed,horse.stamina,Traits.AbilityNames[horse.ability] or '없음',horse.salePrice)
			label.TextColor3=Color3.fromRGB(29,76,58); label.Font=Enum.Font.GothamBold; label.TextSize=15; label.TextWrapped=true; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=row
			local select=Instance.new("TextButton");select.Name="SelectPreview";select.Text=isSelected and "보는 중" or "보기";select.Position=UDim2.new(1,-78,0,10);select.Size=UDim2.fromOffset(64,28)
			select.BackgroundColor3=isSelected and HorseRarity.get(horse.rarityId).Color or Color3.fromRGB(100,119,100);select.TextColor3=Color3.fromRGB(251,246,229);select.Font=Enum.Font.GothamBold;select.TextSize=13;select.BorderSizePixel=0;select.Parent=row;corner(select,8)
			select.Activated:Connect(function() selectedHorseId=horse.id;render() end)
			local place=button(row,horse.placed and "창고로" or "배치",-292,90);place.Position=UDim2.new(0,14,0,83)
			place.Activated:Connect(function() remote:FireServer("SetPlaced",horse.id,not horse.placed) end)
			local protect=button(row,horse.protected and "보호 중" or "보호",-108,90);protect.Position=UDim2.new(0,112,0,83); protect.BackgroundColor3=horse.protected and Color3.fromRGB(195,151,49) or Color3.fromRGB(29,76,58)
			protect.Activated:Connect(function() remote:FireServer("Protect",horse.id) end)
			local ride=button(row,'타고 연습',-108,104);ride.Position=UDim2.new(0,210,0,83)
			ride.Name='Ride'
			ride.Activated:Connect(function() remote:FireServer('Ride',horse.id) end)
			local sell=button(row,'판매 '..horse.salePrice..'원',-202,184);sell.Position=UDim2.new(1,-202,0,83)
			sell.Name='Sell';sell.BackgroundColor3=Color3.fromRGB(169,83,53)
			local expires=0
			sell.Activated:Connect(function()
				if os.clock()>expires then expires=os.clock()+5;sell.Text='판매 확정? 다시 누르기'
				else sell.Active=false;sell.Text='판매 처리 중…';remote:FireServer('Sell',horse.id) end
			end)
		end
	end
end
open.Activated:Connect(function() shade.Visible=true; remote:FireServer("Ready") end)
close.Activated:Connect(function() shade.Visible=false end)
remote.OnClientEvent:Connect(function(kind,payload)
	if kind~="Collection" then return end
	data=payload; render()
	note.Text=data.theftProtected and '추격 진행 중 · 내 모든 말 보호됨' or '농장 배치 최대 12마리 · 보호 슬롯 1개'
	local messages={Captured="새 말을 획득해 농장에 배치했습니다.",Stolen="상대 농장의 말을 획득했습니다.",LostHorse="추격에 실패해 말을 빼앗겼습니다.",Defended="말을 안전하게 지켰습니다.",SetPlaced="배치 상태를 변경했습니다.",Protect="보호 슬롯을 변경했습니다.",FarmFull="농장에는 최대 12마리만 배치할 수 있습니다.",NotPlaced="농장에 배치된 말만 보호할 수 있습니다."}
	status.Text=messages[payload.result] or string.format("보유 %d마리",#payload.horses)
	local economy={Sold='판매 완료! 게임 머니를 지급했습니다.',DogHired='경비견 고용 완료! 내 농장을 지킵니다.',Money='게임 머니가 부족합니다.',CreditPending='판매는 완료됐습니다. 재접속하면 대금 지급을 복구합니다.',SalePending='저장 처리 중입니다. 재접속 시 복구합니다.',SaveUnavailable='저장 상태를 확인할 수 없어 거래를 보류했습니다.',NotOwner='소유권을 확인할 수 없습니다.',Missing='이미 판매되었거나 없는 말입니다.'}
	if economy[payload.result] then status.Text=economy[payload.result] end
end)
task.spawn(function()
	local horseGui=player.PlayerGui:WaitForChild("HorseRunUI",10)
	if not horseGui then return end
	local function visibility() open.Visible=(horseGui:GetAttribute("Phase") or "Lobby")=="Lobby"; if not open.Visible then shade.Visible=false end end
	horseGui:GetAttributeChangedSignal("Phase"):Connect(visibility); visibility()
end)
remote:FireServer("Ready")

