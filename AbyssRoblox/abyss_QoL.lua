local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local sort, tonumber, pcall = table.sort, tonumber, pcall

local S = RS.common.packages.Knit.Services
local StorageRF, InvRF = S.StorageService.RF, S.InventoryService.RF
local DepositRF, WithdrawRF = StorageRF.Deposit, StorageRF.Withdraw
local SellRF = S.SellService.RF.SellInventory
local UnequipRF, EquipRF, DeleteRF = InvRF.UnequipArtifact, InvRF.EquipArtifact, InvRF.DeleteArtifact

local Main = pg.Main
local backpackGui = Main.Backpack
local Hotbar = backpackGui.Hotbar
local FishList = backpackGui.List.CanvasGroup.ScrollingFrame
local storageRoot = Main.Center.Storage.CanvasGroup.Storage
local artifactsScroll = Main.TopLeft.Menus.Inventory.Frame.Scroll_Artifacts.Scroll

local CFG = {
	Weight = { need = "Weight",  prio = {"Weight","Cooldown","Oxygen","Speed","Damage"} },
	Damage = { need = "Damage",  prio = {"Damage","Cooldown","Speed","Oxygen","Weight"} },
	Speed  = { need = "Speed",   prio = {"Speed","Damage","Cooldown","Oxygen","Weight"} },
	Cash   = { need = "Cash",    prio = {"Cash"} },
}

for _, cfg in pairs(CFG) do
	cfg.prio.n = #cfg.prio
end

local _ids, _ws, _ord = table.create(256), table.create(256), table.create(256)
local _lastW, _lastD = 0, 0

local function withdrawAll()
	local kids = game.GetChildren(storageRoot)
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

	local kids = game.GetChildren(Hotbar)
	for i = 1, #kids do
		local inst = kids[i]
		if inst.ClassName == "Frame" and game.GetAttribute(inst, "class") == "fish" then
			n += 1
			_ids[n] = game.GetAttribute(inst, "id")
			_ws[n]  = game.GetAttribute(inst, "weight") or 0
		end
	end

	kids = game.GetChildren(FishList)
	for i = 1, #kids do
		local inst = kids[i]
		if inst.ClassName == "Frame" and game.GetAttribute(inst, "class") == "fish" then
			n += 1
			_ids[n] = game.GetAttribute(inst, "id")
			_ws[n]  = game.GetAttribute(inst, "weight") or 0
		end
	end

	for i = n + 1, _lastD do _ids[i], _ws[i], _ord[i] = nil, nil, nil end
	_lastD = n

	if n == 0 then return end

	for i = 1, n do _ord[i] = i end
	sort(_ord, function(a, b) return _ws[a] > _ws[b] end)

	local tmp = table.create(n)
	for i = 1, n do tmp[i] = _ids[_ord[i]] end
	for i = 1, n do _ids[i] = tmp[i] end

	DepositRF:InvokeServer(_ids)
end

local function statNum(stats, name)
	local v = stats:FindFirstChild(name)
	if v ~= nil then 
		local s = v.Value.Text
		if s:find("−", 1, true) then s = s:gsub("−", "-") end
		if s:find(",", 1, true) then s = s:gsub(",", ".") end

		return tonumber(s:match("[+-]?%d*%.?%d+"))
	end
end

local function equipAnyTop3(key)
	local cfg = CFG[key]
	local prio = cfg.prio
	local needStat = cfg.need

	UnequipRF:InvokeServer(1); UnequipRF:InvokeServer(2); UnequipRF:InvokeServer(3)

	local bestId, bestStats
	local secondId, secondStats
	local thirdId, thirdStats

	local function betterPair(aId, aStats, bId, bStats)
		for i = 1, prio.n or #prio do
			local stat = prio[i]
			local av = statNum(aStats, stat)
			local bv = statNum(bStats, stat)

			if av ~= bv then
				if av == nil then return false end
				if bv == nil then return true end
				if stat == "Cooldown" then
					return av < bv
				else
					return av > bv
				end
			end
		end
		return aId < bId
	end

	local kids = artifactsScroll:GetChildren()
	for i = 1, #kids do
		local a = kids[i]
		if a.ClassName == "Frame" then
			local stats = a.Main.Stats
			local id = a.Name

			if not bestStats or betterPair(id, stats, bestId, bestStats) then
				thirdId, thirdStats = secondId, secondStats
				secondId, secondStats = bestId, bestStats
				bestId, bestStats = id, stats
			elseif not secondStats or betterPair(id, stats, secondId, secondStats) then
				thirdId, thirdStats = secondId, secondStats
				secondId, secondStats = id, stats
			elseif not thirdStats or betterPair(id, stats, thirdId, thirdStats) then
				thirdId, thirdStats = id, stats
			end
		end
	end

	if bestId then EquipRF:InvokeServer(bestId, 1) end
	if secondId then EquipRF:InvokeServer(secondId, 2) end
	if thirdId then EquipRF:InvokeServer(thirdId, 3) end
end

local old = pg:FindFirstChild("FishBankGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name, sg.ResetOnSpawn, sg.Parent = "FishBankGui", false, pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size, frame.BackgroundColor3 = UDim2.fromOffset(518,120), Color3.fromRGB(25,25,25)
frame.Active = true
frame.Draggable = true

local function btn(t,x,y,c)
	local b = Instance.new("TextButton")
	b.Parent = frame
	b.Position, b.Size = UDim2.fromOffset(x,y), UDim2.fromOffset(120,44)
	b.BackgroundColor3 = c
	b.Font, b.TextSize, b.TextColor3, b.Text = Enum.Font.GothamSemibold, 14, Color3.fromRGB(240,240,240), t
	return b
end

local depositBtn  = btn("Deposit",      10, 10, Color3.fromRGB(46,140,87))
local withdrawBtn = btn("Withdraw",    136, 10, Color3.fromRGB(150,62,62))
local keepLowBtn  = btn("Keep lowest", 262, 10, Color3.fromRGB(70,90,140))
local sellAllBtn  = btn("Sell All",    388, 10, Color3.fromRGB(136,108,168))
local wBtn = btn("Weight Top",  10, 66, Color3.fromRGB(90,110,160))
local dBtn = btn("Damage Top", 136, 66, Color3.fromRGB(160,110,90))
local sBtn = btn("Speed Top",  262, 66, Color3.fromRGB(80,130,90))
local tBtn = btn("Delete Trash", 388, 66, Color3.fromRGB(150,140,70))

depositBtn.MouseButton1Click:Connect(depositFishByWeightDesc)
withdrawBtn.MouseButton1Click:Connect(withdrawAll)
keepLowBtn.MouseButton1Click:Connect(function() withdrawAll(); depositFishByWeightDesc() end)

sellAllBtn.MouseButton1Click:Connect(function()
	local eq = Main.TopLeft.Menus.Inventory.Frame["Scroll_Artifacts"].Equipped.List
	local old1 = game.GetAttribute(eq["1"], "id")
	local old2 = game.GetAttribute(eq["2"], "id")
	local old3 = game.GetAttribute(eq["3"], "id")

	equipAnyTop3("Cash")
	SellRF:InvokeServer()

	UnequipRF:InvokeServer(1); UnequipRF:InvokeServer(2); UnequipRF:InvokeServer(3)
	if old1 ~= nil then EquipRF:InvokeServer(old1, 1) end
	if old2 ~= nil then EquipRF:InvokeServer(old2, 2) end
	if old3 ~= nil then EquipRF:InvokeServer(old3, 3) end
end)
wBtn.MouseButton1Click:Connect(function() equipAnyTop3("Weight") end)
dBtn.MouseButton1Click:Connect(function() equipAnyTop3("Damage") end)
sBtn.MouseButton1Click:Connect(function() equipAnyTop3("Speed") end)
tBtn.MouseButton1Click:Connect(function() 
	local kids = artifactsScroll:GetChildren()
	for i = 1, #kids do
		local a = kids[i]
		if a.ClassName == "Frame" then
			local tl = a.Main.Title.Text
			if tl == "Tank" then
				DeleteRF:InvokeServer(a.Name)
				a:Destroy()
			end
		end
	end
end)