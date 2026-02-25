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
	Cash   = { need = "Cash",    prio = {"Cash","Cooldown","Oxygen","Speed","Damage"} },
}

for _, cfg in pairs(CFG) do
	cfg.prio.n = #cfg.prio
end

local function withdrawIds()
	local kids = storageRoot:GetChildren()
	local out, n = {}, 0
	for i = 1, #kids do
		local inst = kids[i]
		if inst.ClassName == "Frame" then n += 1; out[n] = inst.Name end
	end
	return out
end

local _ids, _ws, _ord = table.create(64), table.create(64), table.create(64)

local function depositFishByWeightDesc()
	local ids, ws, ord = _ids, _ws, _ord
	local n = 0

	local function scan(container)
		local kids = container:GetChildren()
		for i = 1, #kids do
			local inst = kids[i]
			if inst.ClassName == "Frame" and inst:GetAttribute("class") == "fish" then
				local id = inst:GetAttribute("id")
				if id ~= nil then
					n += 1
					ids[n] = tostring(id)
					local w = inst:GetAttribute("weight")
					ws[n] = (type(w) == "number") and w or (tonumber(w) or 0)
				end
			end
		end
	end

	scan(Hotbar); scan(FishList)
	if n == 0 then return end

	if n > 1 then
		for i = 1, n do ord[i] = i end
		sort(ord, function(a,b) return ws[a] > ws[b] end)

		local tmp = table.create(n)
		for i = 1, n do tmp[i] = ids[ord[i]] end
		for i = 1, n do ids[i] = tmp[i] end
		for i = n + 1, #tmp do tmp[i] = nil end
	else
		ids[1] = ids[1]
	end

	for i = n + 1, #ids do ids[i] = nil end
	for i = n + 1, #ws  do ws[i]  = nil end
	for i = n + 1, #ord do ord[i] = nil end

	pcall(function() DepositRF:InvokeServer(ids) end)
end

local function withdrawAll()
	local ids = withdrawIds()
	if #ids > 0 then pcall(function() WithdrawRF:InvokeServer(ids) end) end
end

local function statNum(stats, name)
	local v = stats:FindFirstChild(name)
	if v ~= nil then 
		local s = v.Value.Text
		return tonumber(s:match("[+-]?%d*%.?%d+"))
	end
end

local function cmpOne(a, b, stat)
	local av, bv = statNum(a.stats, stat), statNum(b.stats, stat)
	if av == nil then return (bv == nil) and 0 or 1
	elseif bv == nil then return -1
	elseif av == bv then return 0 end
	return ((stat == "Cooldown") and (av < bv) or (av > bv)) and -1 or 1
end

local function better(a, b, key)
	local prio = CFG[key].prio
	for i = 1, prio.n do
		local r = cmpOne(a, b, prio[i])
		if r < 0 then return true end
		if r > 0 then return false end
	end
end

local function selectTop(key)
	local top = {}
	local kids = artifactsScroll:GetChildren()

	for i = 1, #kids do
		local a = kids[i]
		if a.ClassName == "Frame" then
			local item = { id = a.Name, stats = a.Main.Stats }

			local len = #top
			if len < 3 or better(item, top[3], key) then
				local pos = math.min(len + 1, 3)
				while pos > 1 and top[pos - 1] and better(item, top[pos - 1], key) do
					top[pos] = top[pos - 1]
					pos -= 1
				end
				top[pos] = item
			end
		end
	end

	return top
end

local function invokeIds(list)
	UnequipRF:InvokeServer(1); UnequipRF:InvokeServer(2); UnequipRF:InvokeServer(3)
	EquipRF:InvokeServer(list[1].id); EquipRF:InvokeServer(list[2].id); EquipRF:InvokeServer(list[3].id)
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
sellAllBtn.MouseButton1Click:Connect(function() SellRF:InvokeServer() end)
wBtn.MouseButton1Click:Connect(function() invokeIds(selectTop("Weight")) end)
dBtn.MouseButton1Click:Connect(function() invokeIds(selectTop("Damage")) end)
sBtn.MouseButton1Click:Connect(function() invokeIds(selectTop("Speed")) end)
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