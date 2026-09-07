--!strict
local DataStoreService=game:GetService("DataStoreService")
local RunService=game:GetService("RunService")

local PlayerStore=DataStoreService:GetDataStore("HorseCollection_v1")
local JournalStore=DataStoreService:GetDataStore("HorseTransferJournal_v1")
local IndexStore=DataStoreService:GetDataStore("HorseTransferIndex_v1")
local OwnershipStore=DataStoreService:GetDataStore("HorseOwnership_v1")
local Collection={}
Collection.mode=RunService:IsStudio() and "StudioTest" or "Live"
local studioPlayers,studioJournals,studioIndices,studioOwners={},{},{},{}

local function retry(callback)
	local last
	for attempt=1,4 do
		local ok,result=pcall(callback)
		if ok then return true,result end
		last=result
		if attempt<4 then task.wait(2^(attempt-1)) end
	end
	return false,last
end
local function cleanHorse(raw)
	if type(raw)~="table" or type(raw.Id)~="string" or raw.Id=="" then return nil end
	return {Id=raw.Id,TemplateId=tostring(raw.TemplateId or "Horse1"),RarityId=tostring(raw.RarityId or "Bronze"),
		AcquiredAt=math.max(0,math.floor(tonumber(raw.AcquiredAt) or os.time())),
		ProtectedUntil=math.max(0,math.floor(tonumber(raw.ProtectedUntil) or 0)),Placed=raw.Placed==true}
end
function Collection.newData() return {Version=2,Revision=0,Horses={},ProtectedHorseId=nil} end
function Collection.normalize(raw)
	local data=Collection.newData()
	if type(raw)~="table" then return data end
	data.Revision=math.max(0,math.floor(tonumber(raw.Revision) or 0))
	local seen={}
	for _,entry in raw.Horses or {} do
		local horse=cleanHorse(entry)
		if horse and not seen[horse.Id] and #data.Horses<200 then seen[horse.Id]=true; table.insert(data.Horses,horse) end
	end
	if type(raw.ProtectedHorseId)=="string" and seen[raw.ProtectedHorseId] then data.ProtectedHorseId=raw.ProtectedHorseId end
	return data
end
function Collection.find(data,id:string)
	for _,horse in data.Horses do if horse.Id==id then return horse end end
	return nil
end
function Collection.add(data,record)
	if Collection.find(data,record.Id) then return false,"Duplicate" end
	if #data.Horses>=200 then return false,"CollectionFull" end
	local now=os.time(); local placedCount=0
	for _,horse in data.Horses do if horse.Placed then placedCount+=1 end end
	table.insert(data.Horses,{Id=record.Id,TemplateId=record.TemplateId or "Horse1",RarityId=record.RarityId or "Bronze",
		AcquiredAt=now,ProtectedUntil=now+600,Placed=placedCount<12})
	return true
end
function Collection.remove(data,id:string)
	for index,horse in data.Horses do
		if horse.Id==id then table.remove(data.Horses,index); if data.ProtectedHorseId==id then data.ProtectedHorseId=nil end; return horse,index end
	end
	return nil,nil
end
function Collection.isProtected(data,id:string,now:number?)
	local horse=Collection.find(data,id); if not horse then return true end
	return data.ProtectedHorseId==id or horse.ProtectedUntil>(now or os.time())
end
function Collection.setPlaced(data,id:string,placed:boolean)
	local horse=Collection.find(data,id); if not horse then return false,"Missing" end
	if placed and not horse.Placed then
		local count=0; for _,item in data.Horses do if item.Placed then count+=1 end end
		if count>=12 then return false,"FarmFull" end
	end
	horse.Placed=placed; if not placed and data.ProtectedHorseId==id then data.ProtectedHorseId=nil end
	return true
end
function Collection.protect(data,id:string)
	local horse=Collection.find(data,id); if not horse or not horse.Placed then return false,"NotPlaced" end
	data.ProtectedHorseId=id; return true
end

local function readPlayer(userId:number)
	local key="Player_"..userId
	if Collection.mode=="StudioTest" then return true,Collection.normalize(studioPlayers[key]) end
	local ok,result=retry(function() return PlayerStore:GetAsync(key) end)
	return ok,ok and Collection.normalize(result) or result
end
local function updatePlayer(userId:number,callback)
	local key="Player_"..userId
	if Collection.mode=="StudioTest" then
		local nextValue=callback(studioPlayers[key]); if nextValue~=nil then studioPlayers[key]=Collection.normalize(nextValue) end
		return true,Collection.normalize(studioPlayers[key])
	end
	local ok,result=retry(function() return PlayerStore:UpdateAsync(key,callback) end)
	return ok,ok and Collection.normalize(result) or result
end
function Collection.load(userId:number)
	local ok,result=readPlayer(userId); if not ok then return nil,result end
	return result,nil
end
function Collection.save(userId:number,data)
	local clean=Collection.normalize(data); local expected=clean.Revision; local conflict=false
	local ok,result=updatePlayer(userId,function(raw)
		local current=Collection.normalize(raw)
		if current.Revision~=expected then conflict=true; return nil end
		clean.Revision=expected+1; return clean
	end)
	if not ok then return false,result end
	if conflict then return false,"RevisionConflict",result end
	return true,result
end

local function readJournal(id:string)
	if Collection.mode=="StudioTest" then return true,studioJournals[id] end
	return retry(function() return JournalStore:GetAsync(id) end)
end
local function updateJournal(id:string,callback)
	if Collection.mode=="StudioTest" then
		local nextValue=callback(studioJournals[id]); if nextValue~=nil then studioJournals[id]=nextValue end
		return true,studioJournals[id]
	end
	return retry(function() return JournalStore:UpdateAsync(id,callback) end)
end
local function updateIndex(userId:number,id:string,add:boolean)
	local key="Player_"..userId
	local function change(raw)
		local list=type(raw)=="table" and raw or {}; local nextList={}
		for _,value in list do if type(value)=="string" and value~=id and #nextList<49 then table.insert(nextList,value) end end
		if add then table.insert(nextList,id) end
		return nextList
	end
	if Collection.mode=="StudioTest" then studioIndices[key]=change(studioIndices[key]); return true end
	local ok=retry(function() return IndexStore:UpdateAsync(key,change) end); return ok
end
local function readIndex(userId:number)
	local key="Player_"..userId
	if Collection.mode=="StudioTest" then return true,studioIndices[key] or {} end
	local ok,result=retry(function() return IndexStore:GetAsync(key) end)
	return ok,(ok and type(result)=="table") and result or {}
end
local function updateOwner(horseId:string,callback)
	if Collection.mode=="StudioTest" then
		local nextValue=callback(studioOwners[horseId]); if nextValue~=nil then studioOwners[horseId]=nextValue end
		return true,studioOwners[horseId]
	end
	return retry(function() return OwnershipStore:UpdateAsync(horseId,callback) end)
end
function Collection.claimOwnership(userId:number,horseId:string)
	local denied=false
	local ok,result=updateOwner(horseId,function(raw)
		if type(raw)=="table" and tonumber(raw.OwnerUserId)~=userId then denied=true; return nil end
		return {OwnerUserId=userId,UpdatedAt=os.time()}
	end)
	if not ok then return false,result end
	if denied then return false,"OwnedByAnotherPlayer" end
	return true
end
function Collection.addOwnedHorse(userId:number,record)
	local claimed,claimReason=Collection.claimOwnership(userId,record.Id)
	if not claimed then return false,claimReason end
	local rejected=nil
	local ok,data=updatePlayer(userId,function(raw)
		local current=Collection.normalize(raw); local existing=Collection.find(current,record.Id)
		if existing then
			if existing.TemplateId~=record.TemplateId or existing.RarityId~=record.RarityId then rejected="DuplicateMismatch"; return nil end
			return current
		end
		local added,reason=Collection.add(current,record)
		if not added then rejected=reason; return nil end
		current.Revision+=1; return current
	end)
	if not ok then return false,data end
	if rejected then return false,rejected end
	return true,data
end

local function setJournalStage(record,stage,reason)
	local ok,result=updateJournal(record.Id,function(raw)
		if type(raw)~="table" or raw.Id~=record.Id then return nil end
		raw.Stage=stage; raw.Reason=reason; raw.UpdatedAt=os.time(); return raw
	end)
	if ok and type(result)=="table" then record=result end
	return ok,record
end
local function cleanup(record)
	updateIndex(record.OwnerUserId,record.Id,false); updateIndex(record.ThiefUserId,record.Id,false)
end
local function continueTransfer(record)
	if record.Stage=="Completed" then
		cleanup(record)
		local ownerOk,ownerData=readPlayer(record.OwnerUserId); local thiefOk,thiefData=readPlayer(record.ThiefUserId)
		if ownerOk and thiefOk then return true,"Completed",ownerData,thiefData end
		return false,"CompletedReadFailed"
	end
	if record.Stage=="Aborted" then cleanup(record); return false,record.Reason or "Aborted" end
	local authorityDenied=false
	local authorityOk,authorityResult=updateOwner(record.HorseId,function(raw)
		local ownerId=type(raw)=="table" and tonumber(raw.OwnerUserId) or nil
		local pending=type(raw)=="table" and raw.PendingTransferId or nil
		local completed=type(raw)=="table" and raw.LastTransferId==record.Id
		if ownerId and ownerId~=record.OwnerUserId and not (ownerId==record.ThiefUserId and (pending==record.Id or completed)) then authorityDenied=true; return nil end
		if ownerId==record.ThiefUserId and completed then return raw end
		return {OwnerUserId=ownerId or record.OwnerUserId,PendingTransferId=record.Id,UpdatedAt=os.time()}
	end)
	if not authorityOk then return false,authorityResult end
	if authorityDenied then setJournalStage(record,"Aborted","NotOwner"); cleanup(record); return false,"NotOwner" end
	local thiefReadOk,thiefBefore=readPlayer(record.ThiefUserId)
	if not thiefReadOk then return false,thiefBefore end
	local existingAtRecipient=Collection.find(thiefBefore,record.HorseId)
	if existingAtRecipient and (existingAtRecipient.TemplateId~=record.TemplateId or existingAtRecipient.RarityId~=record.RarityId) then
		updateOwner(record.HorseId,function() return {OwnerUserId=record.OwnerUserId,UpdatedAt=os.time()} end)
		setJournalStage(record,"Aborted","DuplicateMismatch"); cleanup(record); return false,"DuplicateMismatch"
	end
	if not existingAtRecipient and #thiefBefore.Horses>=200 then
		updateOwner(record.HorseId,function() return {OwnerUserId=record.OwnerUserId,UpdatedAt=os.time()} end)
		setJournalStage(record,"Aborted","CollectionFull"); cleanup(record); return false,"CollectionFull"
	end

	local invalidReason=nil
	local ownerOk,ownerData=updatePlayer(record.OwnerUserId,function(raw)
		local data=Collection.normalize(raw); local horse=Collection.find(data,record.HorseId)
		if horse then
			if horse.TemplateId~=record.TemplateId or horse.RarityId~=record.RarityId then invalidReason="HorseMismatch"; return nil end
			if Collection.isProtected(data,record.HorseId,record.AuthorizedAt) then invalidReason="Protected"; return nil end
			Collection.remove(data,record.HorseId); data.Revision+=1
		end
		return data
	end)
	if not ownerOk then return false,ownerData end
	if invalidReason then
		updateOwner(record.HorseId,function() return {OwnerUserId=record.OwnerUserId,UpdatedAt=os.time()} end)
		setJournalStage(record,"Aborted",invalidReason); cleanup(record); return false,invalidReason
	end
	setJournalStage(record,"OwnerRemoved")

	local addReason=nil
	local thiefOk,thiefData=updatePlayer(record.ThiefUserId,function(raw)
		local data=Collection.normalize(raw); local existing=Collection.find(data,record.HorseId)
		if existing then
			if existing.TemplateId~=record.TemplateId or existing.RarityId~=record.RarityId then addReason="DuplicateMismatch"; return nil end
			return data
		end
		local added,reason=Collection.add(data,{Id=record.HorseId,TemplateId=record.TemplateId,RarityId=record.RarityId})
		if not added then addReason=reason; return nil end
		data.Revision+=1; return data
	end)
	if not thiefOk then return false,thiefData end
	if addReason then return false,addReason end
	setJournalStage(record,"RecipientAdded")
	local finalDenied=false
	local finalOk,finalResult=updateOwner(record.HorseId,function(raw)
		if type(raw)=="table" and raw.PendingTransferId==record.Id then return {OwnerUserId=record.ThiefUserId,LastTransferId=record.Id,UpdatedAt=os.time()} end
		if type(raw)=="table" and tonumber(raw.OwnerUserId)==record.ThiefUserId and raw.LastTransferId==record.Id then return raw end
		finalDenied=true; return nil
	end)
	if not finalOk then return false,finalResult end
	if finalDenied then return false,"OwnershipFinalizeConflict" end
	local completedOk=setJournalStage(record,"Completed")
	if not completedOk then return false,"JournalFinalizeFailed" end
	cleanup(record)
	return true,"Completed",ownerData,thiefData
end
function Collection.transferOwnership(id:string,ownerUserId:number,thiefUserId:number,horse)
	if ownerUserId==thiefUserId or type(id)~="string" or type(horse)~="table" then return false,"InvalidTransfer" end
	local record={Id=id,Stage="Prepared",OwnerUserId=ownerUserId,ThiefUserId=thiefUserId,HorseId=horse.Id,
		TemplateId=horse.TemplateId,RarityId=horse.RarityId,AuthorizedAt=os.time(),CreatedAt=os.time(),UpdatedAt=os.time()}
	local mismatch=false
	local ok,result=updateJournal(id,function(raw)
		if raw~=nil then
			if raw.OwnerUserId~=ownerUserId or raw.ThiefUserId~=thiefUserId or raw.HorseId~=horse.Id then mismatch=true end
			return raw
		end
		return record
	end)
	if not ok then return false,result end
	if mismatch then return false,"TransferIdCollision" end
	record=result
	if not updateIndex(ownerUserId,id,true) or not updateIndex(thiefUserId,id,true) then return false,"IndexWriteFailed" end
	return continueTransfer(record)
end
function Collection.recover(userId:number)
	local ok,list=readIndex(userId); if not ok then return nil,"IndexReadFailed" end
	local affected={}; local errors={}
	for _,id in list do
		local journalOk,record=readJournal(id)
		if journalOk and type(record)=="table" then
			affected[record.OwnerUserId]=true; affected[record.ThiefUserId]=true
			local resolved,reason=continueTransfer(record)
			local terminal=reason=="NotOwner" or reason=="Protected" or reason=="HorseMismatch" or reason=="DuplicateMismatch" or reason=="CollectionFull" or reason=="Aborted"
			if not resolved and not terminal then table.insert(errors,id..":"..tostring(reason)) end
		else updateIndex(userId,id,false) end
	end
	return affected,#errors>0 and table.concat(errors,",") or nil
end
function Collection.clientData(data)
	local list={}
	for _,horse in data.Horses do
		table.insert(list,{id=horse.Id,templateId=horse.TemplateId,rarityId=horse.RarityId,placed=horse.Placed,
			protected=data.ProtectedHorseId==horse.Id,newProtectionLeft=math.max(0,horse.ProtectedUntil-os.time())})
	end
	return {horses=list,protectedHorseId=data.ProtectedHorseId,maxPlaced=12,saveMode=Collection.mode}
end
return Collection

