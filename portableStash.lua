local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local sort = table.sort
local tonumber = tonumber

local S = RS.common.packages.Knit.Services
local StorageRF = S.StorageService.RF
local BackpackRF = S.BackpackService.RF

local DepositRF, WithdrawRF = StorageRF.Deposit, StorageRF.Withdraw

local Main = pg.Main
local backpackGui = Main.Backpack
local FishList = backpackGui.List.CanvasGroup.ScrollingFrame
local storageRoot = Main.Center.Storage.CanvasGroup.Storage
local hotbarRoot = backpackGui.Hotbar

local _ids, _ws, _ord = table.create(256), table.create(256), table.create(256)
local _lastW, _lastD = 0, 0

local backpackFishWeights = {} -- [id]=weight
local hotbarFishWeights = {}   -- [id]=weight

local function isFishId(v)
	return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

-- =========================
-- Backpack cache
-- =========================
local function addBackpackFish(inst)
	if inst.ClassName ~= "Frame" or inst:GetAttribute("class") ~= "fish" then return end
	local id = inst:GetAttribute("id")
	if not isFishId(id) then return end
	backpackFishWeights[id] = inst:GetAttribute("weight") or 0
end

local function removeBackpackFish(inst)
	if inst.ClassName ~= "Frame" or inst:GetAttribute("class") ~= "fish" then return end
	local id = inst:GetAttribute("id")
	if not isFishId(id) then return end
	backpackFishWeights[id] = nil
end

local function rebuildBackpackFishCache()
	table.clear(backpackFishWeights)
	local kids = FishList:GetChildren()
	for i = 1, #kids do
		addBackpackFish(kids[i])
	end
end

-- =========================
-- Hotbar cache
-- numeric slot frames under Main.Backpack.Hotbar
-- =========================
local function rebuildHotbarFishCache()
	table.clear(hotbarFishWeights)
	local kids = hotbarRoot:GetChildren()
	for i = 1, #kids do
		local slot = kids[i]
		if slot.ClassName == "Frame" and tonumber(slot.Name) and slot:GetAttribute("class") == "fish" then
			local id = slot:GetAttribute("id")
			if isFishId(id) then
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

-- deposit = union(backpack fish, hotbar fish), sorted by weight desc
local function depositFishByWeightDesc()
	local n = 0
	local seen = table.create(128)

	for id, w in pairs(backpackFishWeights) do
		n += 1
		_ids[n], _ws[n] = id, w or 0
		seen[id] = true
	end

	for id, w in pairs(hotbarFishWeights) do
		if not seen[id] then
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

-- initial cache build
rebuildBackpackFishCache()
rebuildHotbarFishCache()

-- backpack watchers
FishList.ChildAdded:Connect(addBackpackFish)
FishList.ChildRemoved:Connect(removeBackpackFish)

-- hotbar watchers
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

-- UI
local old = pg:FindFirstChild("PortableStashGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "PortableStashGui"
sg.ResetOnSpawn = false
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size = UDim2.fromOffset(260, 55)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true
frame.Position = UDim2.fromOffset(100, 170)
frame.BorderSizePixel = 0

local function btn(t, x, y, c)
	local b = Instance.new("TextButton")
	b.Parent = frame
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(110, 34)
	b.BackgroundColor3 = c
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = t
	b.BorderSizePixel = 0
	return b
end

local depositBtn  = btn("Deposit", 10, 10, Color3.fromRGB(46, 140, 87))
local withdrawBtn = btn("Withdraw", 140, 10, Color3.fromRGB(150, 62, 62))

depositBtn.MouseButton1Click:Connect(function()
	rebuildHotbarFishCache()
	depositFishByWeightDesc()
end)

withdrawBtn.MouseButton1Click:Connect(withdrawAll)
