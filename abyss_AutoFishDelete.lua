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
local keyList = {}
local keyCount = 0


local function normalizeName(s)
	return string.lower(s or "")
end

local function rebuildKeyList()
	table.clear(keyList)
	for key in pairs(nameSet) do
		keyList[#keyList + 1] = key
	end
	keyCount = #keyList
end

local function isFishId(v)
	return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

local function isTargetDeleteName(name)
	if keyCount == 0 or type(name) ~= "string" or name == "" then
		return false
	end
	local n = normalizeName(name)
	for i = 1, keyCount do
		if n == keyList[i] then
			return true
		end
	end
	return false
end

local function deleteIfMatch(inst)
	if not (inst and inst.ClassName == "Frame") then return end
	local id = inst:GetAttribute("id")
	local name = inst:GetAttribute("name")
	if isFishId(id) and isTargetDeleteName(name) then
		DeleteFishRF:InvokeServer(id)
	end
end

local function deleteAllTargetFish()
	if keyCount == 0 then
		return
	end
	for _, inst in ipairs(FishList:GetChildren()) do
		deleteIfMatch(inst)
	end
	for _, slot in ipairs(hotbarRoot:GetChildren()) do
		if slot.ClassName == "Frame" and tonumber(slot.Name) then
			deleteIfMatch(slot)
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

	FishList.ChildAdded:Connect(function(child)
		if enabled and keyCount > 0 then
			deleteIfMatch(child)
		end
	end)

	local function hookHotbarSlot(slot)
		if slot.ClassName ~= "Frame" or not tonumber(slot.Name) then return end
		local function onChange()
			if enabled and keyCount > 0 then
				deleteIfMatch(slot)
			end
		end
		slot:GetAttributeChangedSignal("id"):Connect(onChange)
		slot:GetAttributeChangedSignal("name"):Connect(onChange)
	end

	do
		local kids = hotbarRoot:GetChildren()
		for i = 1, #kids do hookHotbarSlot(kids[i]) end
	end

	hotbarRoot.ChildAdded:Connect(function(child)
		hookHotbarSlot(child)
		if enabled and keyCount > 0 then
			deleteIfMatch(child)
		end
	end)
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
		if type(name) == "string" and name ~= "" then
			local key = normalizeName(name)
			if not nameSet[key] then
				nameSet[key] = true
				nameList[#nameList + 1] = name
			end
		end
	end
	rebuildKeyList()
	if enabled then
		deleteAllTargetFish()
	end
end

local function addName(name)
	if type(name) == "string" and name ~= "" then
		local key = normalizeName(name)
		if nameSet[key] then
			return false
		end
		nameSet[key] = true
		nameList[#nameList + 1] = name
		rebuildKeyList()
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
	table.clear(keyList)
	keyCount = 0
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
