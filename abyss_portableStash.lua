local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local sort = table.sort
local tonumber = tonumber

local S = RS.common.packages.Knit.Services
local StorageRF = S.StorageService.RF

local DepositRF, WithdrawRF = StorageRF.Deposit, StorageRF.Withdraw

local Main
local backpackGui
local FishList
local storageRoot
local hotbarRoot

local _ids, _ws, _ord = table.create(256), table.create(256), table.create(256)
local _lastW, _lastD = 0, 0
local _tmp = table.create(256)
local _lastTmp = 0
local _seen = {}
local _seenKeys = table.create(256)
local _seenCount = 0

local backpackFishWeights = {} -- [id]=weight
local hotbarFishWeights = {}   -- [id]=weight

local initialized = false

local function isFishId(v)
	return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

local function isFishFrame(inst)
	if inst.ClassName ~= "Frame" then return false end
	local id = inst:GetAttribute("id")
	if not isFishId(id) then return false end
	local cls = inst:GetAttribute("class")
	if cls == "fish" then return true end
	local w = inst:GetAttribute("weight")
	return type(w) == "number"
end

local function addBackpackFish(inst)
	if not isFishFrame(inst) then return end
	local id = inst:GetAttribute("id")
	backpackFishWeights[id] = inst:GetAttribute("weight") or 0
end

local function removeBackpackFish(inst)
	if not isFishFrame(inst) then return end
	local id = inst:GetAttribute("id")
	backpackFishWeights[id] = nil
end

local function rebuildBackpackFishCache()
	table.clear(backpackFishWeights)
	local kids = FishList:GetChildren()
	for i = 1, #kids do
		addBackpackFish(kids[i])
	end
end

local function rebuildHotbarFishCache()
	table.clear(hotbarFishWeights)
	local kids = hotbarRoot:GetChildren()
	for i = 1, #kids do
		local slot = kids[i]
		if slot.ClassName == "Frame" and tonumber(slot.Name) then
			local id = slot:GetAttribute("id")
			if isFishId(id) and (slot:GetAttribute("class") == "fish" or type(slot:GetAttribute("weight")) == "number") then
				hotbarFishWeights[id] = slot:GetAttribute("weight") or 0
			end
		end
	end
end

local function withdrawAll()
	local kids = storageRoot:GetChildren()
	local n = 0
	for i = 1, #kids do
		local inst = kids[i]
		if inst.ClassName == "Frame" and inst.Name ~= "Placeholder" then
			n += 1
			_ids[n] = inst.Name
		end
	end
	for i = n + 1, _lastW do _ids[i] = nil end
	_lastW = n
	if n > 0 then WithdrawRF:InvokeServer(_ids) end
end

local function depositFishByWeightDesc()
	local n = 0

	for id, w in pairs(backpackFishWeights) do
		n += 1
		_ids[n], _ws[n] = id, w or 0
		_seen[id] = true
		_seenCount += 1
		_seenKeys[_seenCount] = id
	end

	for id, w in pairs(hotbarFishWeights) do
		if not _seen[id] then
			n += 1
			_ids[n], _ws[n] = id, w or 0
		end
	end

	for i = 1, _seenCount do
		local id = _seenKeys[i]
		_seen[id] = nil
		_seenKeys[i] = nil
	end
	_seenCount = 0

	for i = n + 1, _lastD do
		_ids[i], _ws[i], _ord[i] = nil, nil, nil
	end
	_lastD = n
	if n == 0 then return end

	for i = 1, n do _ord[i] = i end
	sort(_ord, function(a, b) return (_ws[a] or 0) > (_ws[b] or 0) end)

	for i = 1, n do _tmp[i] = _ids[_ord[i]] end
	for i = 1, n do _ids[i] = _tmp[i] end
	for i = n + 1, _lastTmp do _tmp[i] = nil end
	_lastTmp = n

	DepositRF:InvokeServer(_ids)
end

local function init()
	if initialized then return end
	initialized = true

	Main = pg.Main
	backpackGui = Main.Backpack
	FishList = backpackGui.List.CanvasGroup.ScrollingFrame
	storageRoot = Main.Center.Storage.CanvasGroup.Storage
	hotbarRoot = backpackGui.Hotbar

	rebuildBackpackFishCache()
	rebuildHotbarFishCache()

	FishList.ChildAdded:Connect(addBackpackFish)
	FishList.ChildRemoved:Connect(removeBackpackFish)

	local function hookHotbarSlot(slot)
		if slot.ClassName ~= "Frame" or not tonumber(slot.Name) then return end
		slot:GetAttributeChangedSignal("id"):Connect(rebuildHotbarFishCache)
		slot:GetAttributeChangedSignal("class"):Connect(rebuildHotbarFishCache)
		slot:GetAttributeChangedSignal("weight"):Connect(rebuildHotbarFishCache)
	end

	do
		local kids = hotbarRoot:GetChildren()
		for i = 1, #kids do hookHotbarSlot(kids[i]) end
	end

	hotbarRoot.ChildAdded:Connect(function(child)
		hookHotbarSlot(child)
		rebuildHotbarFishCache()
	end)

	hotbarRoot.ChildRemoved:Connect(rebuildHotbarFishCache)
end

return {
	init = init,
	depositFishByWeightDesc = depositFishByWeightDesc,
	withdrawAll = withdrawAll,
	rebuildBackpackFishCache = rebuildBackpackFishCache,
	rebuildHotbarFishCache = rebuildHotbarFishCache,
}
