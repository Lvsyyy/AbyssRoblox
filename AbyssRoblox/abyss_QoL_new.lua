local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local sort = table.sort
local tonumber = tonumber

-- Auto-delete fish names (edit this list)
local AUTO_DELETE_FISH_NAMES = {
	["Discus"] = true,
	["Trout"] = true,
}

local S = RS.common.packages.Knit.Services
local StorageRF = S.StorageService.RF
local InvRF = S.InventoryService.RF
local BackpackRF = S.BackpackService.RF

local DepositRF, WithdrawRF = StorageRF.Deposit, StorageRF.Withdraw
local SellRF = S.SellService.RF.SellInventory
local DeleteFishRF = BackpackRF.DeleteFish
local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout

local Main = pg.Main
local backpackGui = Main.Backpack
local FishList = backpackGui.List.CanvasGroup.ScrollingFrame
local storageRoot = Main.Center.Storage.CanvasGroup.Storage
local hotbarRoot = backpackGui.Hotbar -- confirmed path

local _ids, _ws, _ord = table.create(256), table.create(256), table.create(256)
local _lastW, _lastD = 0, 0

-- caches
local backpackFishWeights, backpackFishNames = {}, {} -- [id]=weight/name
local hotbarFishWeights, hotbarFishNames = {}, {}     -- [id]=weight/name

local toggleState = false

local function isFishId(v)
	return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

local function isTargetDeleteName(name)
	return AUTO_DELETE_FISH_NAMES[name] == true
end

-- =========================
-- Backpack cache
-- =========================
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

-- =========================
-- Hotbar cache (exact logic from dump)
-- numeric slot frames under Main.Backpack.Hotbar
-- slot attrs include class/name/id/weight
-- =========================
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

-- deposit = union(backpack fish, hotbar fish), sorted by weight desc
local function depositFishByWeightDesc()
	local n = 0
	local seen = table.create(128)

	for id, w in pairs(backpackFishWeights) do
		if not (toggleState and isTargetDeleteName(backpackFishNames[id])) then
			n += 1
			_ids[n], _ws[n] = id, w or 0
			seen[id] = true
		end
	end

	for id, w in pairs(hotbarFishWeights) do
		if not seen[id] and not (toggleState and isTargetDeleteName(hotbarFishNames[id])) then
			n += 1
			_ids[n], _ws[n] = id, w or 0
			seen[id] = true
		end
	end

	for i = n + 1, _lastD do
		_ids[i], _ws[i], _ord[i] = nil, nil, nil
	end
	_lastD = n
	if n == 0 then return end

	for i = 1, n do _ord[i] = i end
	sort(_ord, function(a, b) return (_ws[a] or 0) > (_ws[b] or 0) end)

	local tmp = table.create(n)
	for i = 1, n do tmp[i] = _ids[_ord[i]] end
	for i = 1, n do _ids[i] = tmp[i] end

	DepositRF:InvokeServer(_ids)
end

local function equipArtifactsLoadout(slotNum)
	EquipArtifactsLoadoutRF:InvokeServer(slotNum)
end

-- initial cache build
rebuildBackpackFishCache()
rebuildHotbarFishCache()

-- backpack watchers
FishList.ChildAdded:Connect(function(child)
	addBackpackFish(child)

	if toggleState and child.ClassName == "Frame" and child:GetAttribute("class") == "fish" then
		local id = child:GetAttribute("id")
		local name = backpackFishNames[id]
		if isFishId(id) and isTargetDeleteName(name) then
			DeleteFishRF:InvokeServer(id)
			return
		end
	end
end)

FishList.ChildRemoved:Connect(removeBackpackFish)

-- hotbar watchers (slot attributes change in-place)
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

	if toggleState and child.ClassName == "Frame" and tonumber(child.Name) and child:GetAttribute("class") == "fish" then
		local id = child:GetAttribute("id")
		local name = child:GetAttribute("name")
		if isFishId(id) and isTargetDeleteName(name) then
			DeleteFishRF:InvokeServer(id)
		end
	end
end)

hotbarRoot.ChildRemoved:Connect(rebuildHotbarFishCache)

-- UI
local old = pg:FindFirstChild("FishBankGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "FishBankGui"
sg.ResetOnSpawn = false
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size = UDim2.fromOffset(395, 95)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true
frame.Position = UDim2.fromOffset(100, 100)
frame.BorderSizePixel = 0

local function btn(t, x, y, c)
	local b = Instance.new("TextButton")
	b.Parent = frame
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(108, 34)
	b.BackgroundColor3 = c
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = t
	b.BorderSizePixel = 0
	return b
end

local function setVerticalToggleVisual(b)
	if toggleState then
		b.Text = "O\nN"
		b.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
	else
		b.Text = "O\nF\nF"
		b.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
	end
end

local function verticalToggle(x, y)
	local c = Instance.new("TextButton")
	c.Parent = frame
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(34, 75)
	c.Font = Enum.Font.GothamBold
	c.TextSize = 11
	c.TextColor3 = Color3.fromRGB(240, 240, 240)
	c.BorderSizePixel = 0
	c.TextWrapped = true
	setVerticalToggleVisual(c)

	c.MouseButton1Click:Connect(function()
		toggleState = not toggleState
		setVerticalToggleVisual(c)
		if toggleState then
			deleteAllTargetFish()
		end
	end)

	return c
end

local depositBtn  = btn("Deposit",    10, 10, Color3.fromRGB(46, 140, 87))
local withdrawBtn = btn("Withdraw",  124, 10, Color3.fromRGB(150, 62, 62))
local sellAllBtn  = btn("Sell All",  238, 10, Color3.fromRGB(136, 108, 168))

local wBtn = btn("Weight Set",  10, 50, Color3.fromRGB(90, 110, 160))
local dBtn = btn("Damage Set", 124, 50, Color3.fromRGB(160, 110, 90))
local sBtn = btn("Speed Set",  238, 50, Color3.fromRGB(80, 130, 90))

local tBtn = verticalToggle(352, 10)

depositBtn.MouseButton1Click:Connect(function()
	rebuildHotbarFishCache()
	depositFishByWeightDesc()
end)

withdrawBtn.MouseButton1Click:Connect(withdrawAll)

sellAllBtn.MouseButton1Click:Connect(function()
	equipArtifactsLoadout(4)
	SellRF:InvokeServer()
end)

wBtn.MouseButton1Click:Connect(function() equipArtifactsLoadout(1) end)
dBtn.MouseButton1Click:Connect(function() equipArtifactsLoadout(2) end)
sBtn.MouseButton1Click:Connect(function() equipArtifactsLoadout(3) end)