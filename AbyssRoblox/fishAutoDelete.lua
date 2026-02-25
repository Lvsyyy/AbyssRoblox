local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local tonumber = tonumber

local S = RS.common.packages.Knit.Services
local BackpackRF = S.BackpackService.RF
local DeleteFishRF = BackpackRF.DeleteFish

local Main
local backpackGui
local FishList
local hotbarRoot

local initialized = false
local enabled = false

local nameSet = {}
local nameList = {}

local backpackFishWeights, backpackFishNames = {}, {} -- [id]=weight/name
local hotbarFishWeights, hotbarFishNames = {}, {}     -- [id]=weight/name

local function isFishId(v)
	return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

local function isTargetDeleteName(name)
	return nameSet[name] == true
end

local function addBackpackFish(inst)
	if inst.ClassName ~= "Frame" or inst:GetAttribute("class") ~= "fish" then return end
	local id = inst:GetAttribute("id")
	if not isFishId(id) then return end
	backpackFishWeights[id] = inst:GetAttribute("weight") or 0
	backpackFishNames[id] = inst:GetAttribute("name")
end

local function removeBackpackFish(inst)
	if inst.ClassName ~= "Frame" or inst:GetAttribute("class") ~= "fish" then return end
	local id = inst:GetAttribute("id")
	if not isFishId(id) then return end
	backpackFishWeights[id], backpackFishNames[id] = nil, nil
end

local function rebuildBackpackFishCache()
	table.clear(backpackFishWeights)
	table.clear(backpackFishNames)
	local kids = FishList:GetChildren()
	for i = 1, #kids do
		addBackpackFish(kids[i])
	end
end

local function rebuildHotbarFishCache()
	table.clear(hotbarFishWeights)
	table.clear(hotbarFishNames)

	local kids = hotbarRoot:GetChildren()
	for i = 1, #kids do
		local slot = kids[i]
		if slot.ClassName == "Frame" and tonumber(slot.Name) and slot:GetAttribute("class") == "fish" then
			local id = slot:GetAttribute("id")
			if isFishId(id) then
				hotbarFishWeights[id] = slot:GetAttribute("weight") or 0
				hotbarFishNames[id] = slot:GetAttribute("name")
			end
		end
	end
end

local function deleteAllTargetFish()
	for id, name in pairs(backpackFishNames) do
		if isTargetDeleteName(name) then
			DeleteFishRF:InvokeServer(id)
		end
	end

	for id, name in pairs(hotbarFishNames) do
		if hotbarFishWeights[id] and not backpackFishWeights[id] and isTargetDeleteName(name) then
			DeleteFishRF:InvokeServer(id)
		end
	end
end

local function init()
	if initialized then return end
	initialized = true

	Main = pg.Main
	backpackGui = Main.Backpack
	FishList = backpackGui.List.CanvasGroup.ScrollingFrame
	hotbarRoot = backpackGui.Hotbar

	rebuildBackpackFishCache()
	rebuildHotbarFishCache()

	FishList.ChildAdded:Connect(function(child)
		addBackpackFish(child)
		if enabled and child.ClassName == "Frame" and child:GetAttribute("class") == "fish" then
			local id = child:GetAttribute("id")
			local name = backpackFishNames[id]
			if isFishId(id) and isTargetDeleteName(name) then
				DeleteFishRF:InvokeServer(id)
			end
		end
	end)

	FishList.ChildRemoved:Connect(removeBackpackFish)

	local function hookHotbarSlot(slot)
		if slot.ClassName ~= "Frame" or not tonumber(slot.Name) then return end
		slot:GetAttributeChangedSignal("id"):Connect(rebuildHotbarFishCache)
		slot:GetAttributeChangedSignal("class"):Connect(rebuildHotbarFishCache)
		slot:GetAttributeChangedSignal("weight"):Connect(rebuildHotbarFishCache)
		slot:GetAttributeChangedSignal("name"):Connect(rebuildHotbarFishCache)
	end

	do
		local kids = hotbarRoot:GetChildren()
		for i = 1, #kids do hookHotbarSlot(kids[i]) end
	end

	hotbarRoot.ChildAdded:Connect(function(child)
		hookHotbarSlot(child)
		rebuildHotbarFishCache()

		if enabled and child.ClassName == "Frame" and tonumber(child.Name) and child:GetAttribute("class") == "fish" then
			local id = child:GetAttribute("id")
			local name = child:GetAttribute("name")
			if isFishId(id) and isTargetDeleteName(name) then
				DeleteFishRF:InvokeServer(id)
			end
		end
	end)

	hotbarRoot.ChildRemoved:Connect(rebuildHotbarFishCache)
end

local function setEnabled(v)
	enabled = v == true
	if enabled then
		deleteAllTargetFish()
	end
end

local function getEnabled()
	return enabled
end

local function setNames(list)
	table.clear(nameSet)
	table.clear(nameList)
	for i = 1, #list do
		local name = list[i]
		if name ~= "" and not nameSet[name] then
			nameSet[name] = true
			nameList[#nameList + 1] = name
		end
	end
	if enabled then
		deleteAllTargetFish()
	end
end

local function addName(name)
	if name ~= "" and not nameSet[name] then
		nameSet[name] = true
		nameList[#nameList + 1] = name
		if enabled then
			deleteAllTargetFish()
		end
		return true
	end
	return false
end

local function clearNames()
	table.clear(nameSet)
	table.clear(nameList)
end

local function getNames()
	local out = table.create(#nameList)
	for i = 1, #nameList do out[i] = nameList[i] end
	return out
end

return {
	init = init,
	setEnabled = setEnabled,
	getEnabled = getEnabled,
	setNames = setNames,
	addName = addName,
	clearNames = clearNames,
	getNames = getNames,
	rebuildBackpackFishCache = rebuildBackpackFishCache,
	rebuildHotbarFishCache = rebuildHotbarFishCache,
}
