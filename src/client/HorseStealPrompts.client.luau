local Players=game:GetService('Players')
local CollectionService=game:GetService('CollectionService')
local player=Players.LocalPlayer
local TAG='PlayerHorseStealPrompt'
local connections={}

local function watch(prompt)
    if connections[prompt] or not prompt:IsA('ProximityPrompt') then return end
    local function hideOwned()
        if prompt:GetAttribute('OwnerUserId')==player.UserId and prompt.Enabled then
            prompt.Enabled=false
        end
    end
    connections[prompt]={prompt:GetPropertyChangedSignal('Enabled'):Connect(hideOwned),
        prompt:GetAttributeChangedSignal('OwnerUserId'):Connect(hideOwned)}
    hideOwned()
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(prompt)
    for _,connection in connections[prompt] or {} do connection:Disconnect() end
    connections[prompt]=nil
end)
for _,prompt in CollectionService:GetTagged(TAG) do watch(prompt) end
