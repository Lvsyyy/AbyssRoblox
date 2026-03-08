local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")
local Common = RS:WaitForChild("common")

local BASE = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/"
local SAVE_PATH = "abyss_settings.json"
local MODULE_CACHE_DIR = "abyss_cache"
local LOADED_MODULES = {}

local function loadModule(name)
	if LOADED_MODULES[name] then
		return LOADED_MODULES[name]
	end

	local cachePath = MODULE_CACHE_DIR .. "/" .. name .. ".lua"
	local src

	if isfile and readfile and isfile(cachePath) then
		local ok, cached = pcall(readfile, cachePath)
		if ok and type(cached) == "string" and cached ~= "" then
			src = cached
		end
	end

	if not src then
		local ok, fetched = pcall(function()
			return game:HttpGet(BASE .. name .. ".lua")
		end)
		if not ok or type(fetched) ~= "string" or fetched == "" then
			error("Failed to load module: " .. tostring(name))
		end
		src = fetched
		if writefile and type(src) == "string" and src ~= "" then
			if makefolder then
				pcall(makefolder, MODULE_CACHE_DIR)
			end
			pcall(writefile, cachePath, src)
		end
	else
		task.spawn(function()
			local ok, fresh = pcall(function()
				return game:HttpGet(BASE .. name .. ".lua")
			end)
			if ok and type(fresh) == "string" and fresh ~= "" and fresh ~= src and writefile then
				if makefolder then
					pcall(makefolder, MODULE_CACHE_DIR)
				end
				pcall(writefile, cachePath, fresh)
			end
		end)
	end

	local mod = loadstring(src)
	local result = mod()
	LOADED_MODULES[name] = result
	return result
end

local sellAll = loadModule("abyss_sellAll")
local portableStash = loadModule("abyss_portableStash")
local artifactSets = loadModule("abyss_artifactSets")
local antiAfk = loadModule("antiAfk")
local shopBuyer = loadModule("abyss_shopBuyer")
local artifactScanner = loadModule("abyss_artifactScanner")
local updateArtifacts = loadModule("abyss_UpdateArtifacts")
local deleteBadArtifacts = loadModule("abyss_DeleteBadArtifacts")
local autoDelete = loadModule("artifactAutoDelete")
local fishAutoDelete = loadModule("abyss_fishAutoDelete")
local geodeOpener = loadModule("abyss_GeodeOpener")
local geodeOnly = loadModule("abyss_geode_only")
local autoDaily = loadModule("abyss_auto_daily")
local settingsStore = loadModule("abyss_settings")
local autoRejoin = loadModule("abyss_AutoRejoin")

local KnitServices = Common:WaitForChild("packages"):WaitForChild("Knit"):WaitForChild("Services")
local FishPondRF = KnitServices:WaitForChild("FishPondService"):WaitForChild("RF")
local CollectAllRoeRF = FishPondRF:WaitForChild("CollectAll")
local SellServiceRF = KnitServices:WaitForChild("SellService"):WaitForChild("RF")
local SellInventoryRF = SellServiceRF:WaitForChild("SellInventory")
local InventoryRF = KnitServices:WaitForChild("InventoryService"):WaitForChild("RF")
local EquipArtifactsLoadoutRF = InventoryRF:WaitForChild("EquipArtifactsLoadout")

portableStash.init()
fishAutoDelete.init()

local antiOn = false
local setAntiAfk
local setFishToggleVisual
local refreshFishList
local applyArtifactAutoDeleteList
local getArtifactAutoDeleteList
local setShopToggleVisual
local refreshShopList
local setGeodeToggleVisual
local setGeodeOnlyToggleVisual
local setAutoDailyToggleVisual
local setRoeToggleVisual

local BTN_GREEN = Color3.fromRGB(46, 140, 87)
local BTN_RED = Color3.fromRGB(150, 62, 62)
local BTN_PURPLE = Color3.fromRGB(136, 103, 181)

local TAB_CONTENT_HEIGHT = 302
local TAB_PADDING_TOTAL = 20
local TAB_ROW_GAP = 10

local FishAssets = Common:WaitForChild("assets"):WaitForChild("fish")

local autoDailyOn = autoDaily.getEnabled()
local geodeOnlyOn = geodeOnly.getEnabled()
local roeAutoOn = false
local roeAutoNonce = 0

local function collectRoe()
	pcall(function()
		CollectAllRoeRF:InvokeServer()
	end)
end

local function sellRoe()
	pcall(function()
		EquipArtifactsLoadoutRF:InvokeServer(4)
		SellInventoryRF:InvokeServer()
	end)
end

local function getRoeUsageRatio()
	local main = pg:FindFirstChild("Main")
	local center = main and main:FindFirstChild("Center")
	local fishPond = center and center:FindFirstChild("FishPond")
	local pondMain = fishPond and fishPond:FindFirstChild("Main")
	local itemStash = pondMain and pondMain:FindFirstChild("itemStash")
	local itemWeight = itemStash and itemStash:FindFirstChild("ItemWeight")
	if not (itemWeight and itemWeight:IsA("TextLabel")) then
		return nil
	end

	local text = (itemWeight.Text or ""):gsub(",", "")
	local left, right = text:match("([%d%.]+)%s*kg%s*/%s*([%d%.]+)%s*kg")
	local cur = tonumber(left)
	local maxv = tonumber(right)
	if not cur or not maxv or maxv <= 0 then
		return nil
	end
	return cur / maxv
end

local function setRoeAuto(on)
	roeAutoOn = on == true
	if setRoeToggleVisual then
		setRoeToggleVisual(roeAutoOn)
	end

	roeAutoNonce += 1
	local myNonce = roeAutoNonce
	if not roeAutoOn then
		return
	end

	task.spawn(function()
		local nextActionAt = 0
		while roeAutoOn and myNonce == roeAutoNonce do
			local ratio = getRoeUsageRatio()
			if ratio and ratio >= 0.9 and tick() >= nextActionAt then
				collectRoe()
				task.wait(0.2)
				sellRoe()
				nextActionAt = tick() + 2
			end
			task.wait(0.2)
		end
	end)
end

local function setAutoDaily(on)
	autoDaily.setEnabled(on == true)
	autoDailyOn = autoDaily.getEnabled()
	if setAutoDailyToggleVisual then
		setAutoDailyToggleVisual(autoDailyOn)
	end
end

local function setGeodeOnly(on)
	geodeOnlyOn = on == true
	geodeOnly.setEnabled(geodeOnlyOn)
	geodeOnlyOn = geodeOnly.getEnabled()
	if setGeodeOnlyToggleVisual then
		setGeodeOnlyToggleVisual(geodeOnlyOn)
	end
end

local old = pg:FindFirstChild("AbyssQoLGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "AbyssQoLGui"
sg.ResetOnSpawn = false
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size = UDim2.fromOffset(500, 360)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
frame.Active = true
frame.Draggable = true
frame.Position = UDim2.fromOffset(100, 100)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local credit = Instance.new("TextLabel")
credit.Parent = frame
credit.Size = UDim2.new(1, -20, 0, 10)
credit.Position = UDim2.new(0, 10, 1, -12)
credit.BackgroundTransparency = 1
credit.BorderSizePixel = 0
credit.Font = Enum.Font.Gotham
credit.TextSize = 11
credit.TextColor3 = Color3.fromRGB(210, 210, 210)
credit.TextXAlignment = Enum.TextXAlignment.Center
credit.TextYAlignment = Enum.TextYAlignment.Center
credit.Text = "Made by @Lvsyyyyy on GitHub"

local function tabButton(parent, text)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Size = UDim2.new(1, 0, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = text
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local function makeTabContainer()
	local t = Instance.new("Frame")
	t.Parent = frame
	t.Position = UDim2.fromOffset(10, 48)
	t.Size = UDim2.fromOffset(480, 302)
	t.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	t.BorderSizePixel = 0
	t.Visible = false
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 8)

	local pad = Instance.new("UIPadding", t)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)

	local list = Instance.new("UIListLayout", t)
	list.Padding = UDim.new(0, 10)

	return t
end

local function makeRow(parent, columns, height)
	local row = Instance.new("Frame")
	row.Parent = parent
	if columns == 1 then
		row.Position = UDim2.fromOffset(4, 0)
		row.Size = UDim2.new(1, -8, 0, height)
	else
		row.Size = UDim2.new(1, 0, 0, height)
	end
	row.BackgroundTransparency = 1

	local grid = Instance.new("UIGridLayout", row)
	local pad = 8
	local xOffset = -pad
	local cellPad = (columns == 1) and 0 or pad
	grid.CellPadding = UDim2.fromOffset(cellPad, 0)
	grid.CellSize = UDim2.new(1 / columns, xOffset, 1, 0)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return row
end

local function makeButton(parent, text, color)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = text
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local function getListHeight(rowHeights)
	local rows = 0
	for i = 1, #rowHeights do
		rows = rows + rowHeights[i]
	end
	local gaps = #rowHeights
	local auto = TAB_CONTENT_HEIGHT - TAB_PADDING_TOTAL - rows - (gaps * TAB_ROW_GAP)
	return math.max(80, auto)
end

local function makeScrollingList(parent, height)
	local list = Instance.new("ScrollingFrame")
	list.Parent = parent
	list.Position = UDim2.fromOffset(0, 0)
	list.Size = UDim2.new(1, 0, 0, height)
	list.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

	local layout = Instance.new("UIListLayout", list)
	layout.Padding = UDim.new(0, 4)

	local padding = Instance.new("UIPadding", list)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)

	return list, layout
end

local function makeSelectableRow(parent, text, color, onClick)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Size = UDim2.new(1, -8, 0, 24)
	b.Text = text
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
	local p = Instance.new("UIPadding", b)
	p.PaddingLeft = UDim.new(0, 8)
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end

local tabs = {
	Artifacts = makeTabContainer(),
	Deletion = makeTabContainer(),
	Shop = makeTabContainer(),
	Misc = makeTabContainer(),
}

local function showTab(name)
	for k, v in pairs(tabs) do
		v.Visible = (k == name)
	end
end

local tabBar = Instance.new("Frame")
tabBar.Parent = frame
tabBar.Position = UDim2.fromOffset(10, 10)
tabBar.Size = UDim2.new(1, -20, 0, 28)
tabBar.BackgroundTransparency = 1

local tabGrid = Instance.new("UIGridLayout", tabBar)
tabGrid.CellPadding = UDim2.fromOffset(8, 0)
tabGrid.CellSize = UDim2.new(1 / 4, -8, 1, 0)

local tabArtifacts = tabButton(tabBar, "Artifacts")
local tabCleanup = tabButton(tabBar, "Deletion")
local tabShop = tabButton(tabBar, "Shop")
local tabMisc = tabButton(tabBar, "Misc")

tabArtifacts.MouseButton1Click:Connect(function() showTab("Artifacts") end)
tabCleanup.MouseButton1Click:Connect(function() showTab("Deletion") end)
tabShop.MouseButton1Click:Connect(function() showTab("Shop") end)
tabMisc.MouseButton1Click:Connect(function() showTab("Misc") end)

-- Artifacts tab
do
	local t = tabs["Artifacts"]

	local row2 = makeRow(t, 2, 34)
	makeButton(row2, "Update Sets", BTN_GREEN).MouseButton1Click:Connect(
		function() updateArtifacts.updateAllSets() end
	)
	makeButton(row2, "Delete Bad Artifacts", BTN_RED).MouseButton1Click:Connect(
		function() deleteBadArtifacts.deleteBadArtifacts() end
	)

	local list, lo = makeScrollingList(t, getListHeight({ 34, 34 }))

	local sel, rows = nil, {}
	local autoDeleteEnabled = {}

	local function rowColor(name)
		if autoDeleteEnabled[name] then
			return Color3.fromRGB(150, 62, 62)
		end
		return (name == sel and Color3.fromRGB(70, 94, 138) or Color3.fromRGB(45, 45, 54))
	end

	local function paint()
		for name, b in pairs(rows) do
			if b.Parent then
				b.BackgroundColor3 = rowColor(name)
			end
		end
	end

	local function clearList()
		for _, b in pairs(rows) do
			if b.Parent then b:Destroy() end
		end
		rows = {}
	end

	local function populateArtifacts()
		clearList()
		local ok, names = pcall(artifactScanner.scanArtifactNames)
		if not ok or type(names) ~= "table" then
			names = {}
		end
		for i = 1, #names do
			local name = names[i]
			local b = makeSelectableRow(list, name, rowColor(name), function()
				sel = name
				paint()
			end)
			rows[name] = b
		end

		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, lo.AbsoluteContentSize.Y + 12)
			paint()
		end)
	end

	populateArtifacts()

	local row3 = makeRow(t, 2, 34)
	local enableDeleteBtn = makeButton(row3, "Add", BTN_GREEN)
	enableDeleteBtn.MouseButton1Click:Connect(
		function()
			if not sel then return end
			autoDelete.setAutoDelete(sel, true)
			autoDeleteEnabled[sel] = true
			paint()
		end
	)
	local disableDeleteBtn = makeButton(row3, "Remove", BTN_RED)
	disableDeleteBtn.MouseButton1Click:Connect(
		function()
			if not sel then return end
			autoDelete.setAutoDelete(sel, false)
			autoDeleteEnabled[sel] = nil
			paint()
		end
	)

	local function applyArtifactAutoDeleteListImpl(list)
		for i = 1, #list do
			local name = list[i]
			autoDelete.setAutoDelete(name, true)
			autoDeleteEnabled[name] = true
		end
		paint()
	end
	local function getArtifactAutoDeleteListImpl()
		local out = {}
		for name in pairs(autoDeleteEnabled) do
			out[#out + 1] = name
		end
		table.sort(out)
		return out
	end

	applyArtifactAutoDeleteList = applyArtifactAutoDeleteListImpl
	getArtifactAutoDeleteList = getArtifactAutoDeleteListImpl
end

-- Deletion tab
do
	local t = tabs["Deletion"]
	local row2 = makeRow(t, 3, 34)
	local addBtn = makeButton(row2, "Add", BTN_GREEN)
	local delBtn = makeButton(row2, "Remove", BTN_RED)
	local toggleBtn = makeButton(row2, "Delete Fish: OFF", BTN_RED)

	local list, lo = makeScrollingList(t, getListHeight({ 34 }))
	local selectedFish
	local rows = {}
	local enabledFish = {}

	local function rowColor(name)
		if enabledFish[name] then
			return BTN_RED
		end
		return (name == selectedFish and Color3.fromRGB(70, 94, 138) or Color3.fromRGB(45, 45, 54))
	end

	local function paintRows()
		for name, b in pairs(rows) do
			if b.Parent then
				b.BackgroundColor3 = rowColor(name)
			end
		end
	end

	local function getFishModelNames()
		local out = {}
		local kids = FishAssets:GetChildren()
		for i = 1, #kids do
			local inst = kids[i]
			if inst:IsA("Model") then
				out[#out + 1] = inst.Name
			end
		end
		table.sort(out)
		return out
	end

	local function refreshList()
		for _, b in pairs(rows) do
			if b.Parent then
				b:Destroy()
			end
		end
		rows = {}

		table.clear(enabledFish)
		local enabledNames = fishAutoDelete.getNames()
		for i = 1, #enabledNames do
			enabledFish[enabledNames[i]] = true
		end

		local fishNames = getFishModelNames()
		for i = 1, #fishNames do
			local name = fishNames[i]
			local b = makeSelectableRow(list, name, rowColor(name), function()
				selectedFish = name
				paintRows()
			end)
			rows[name] = b
		end

		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, lo.AbsoluteContentSize.Y + 12)
			paintRows()
		end)
	end
	refreshFishList = refreshList

	local function setToggleVisual(on)
		if on then
			toggleBtn.Text = "Delete Fish: ON"
			toggleBtn.BackgroundColor3 = BTN_GREEN
		else
			toggleBtn.Text = "Delete Fish: OFF"
			toggleBtn.BackgroundColor3 = BTN_RED
		end
	end
	setFishToggleVisual = setToggleVisual

	addBtn.MouseButton1Click:Connect(function()
		if not selectedFish then return end
		if fishAutoDelete.addName(selectedFish) then
			refreshList()
		end
	end)

	delBtn.MouseButton1Click:Connect(function()
		if not selectedFish then return end
		local names = fishAutoDelete.getNames()
		local keep = {}
		local removed = false
		local target = string.lower(selectedFish)
		for i = 1, #names do
			local n = names[i]
			if string.lower(n) ~= target then
				keep[#keep + 1] = n
			else
				removed = true
			end
		end
		if removed then
			fishAutoDelete.setNames(keep)
			refreshList()
		end
	end)

	toggleBtn.MouseButton1Click:Connect(function()
		local on = not fishAutoDelete.getEnabled()
		fishAutoDelete.setEnabled(on)
		setToggleVisual(on)
	end)
end

-- Misc tab
do
	local t = tabs["Misc"]
	local row1 = makeRow(t, 3, 34)
	makeButton(row1, "Weight Set", BTN_PURPLE).MouseButton1Click:Connect(
		function() artifactSets.equipWeightSet() end
	)
	makeButton(row1, "Damage Set", BTN_PURPLE).MouseButton1Click:Connect(
		function() artifactSets.equipDamageSet() end
	)
	makeButton(row1, "Speed Set", BTN_PURPLE).MouseButton1Click:Connect(
		function() artifactSets.equipSpeedSet() end
	)

	local row2 = makeRow(t, 2, 34)
	local autoDailyBtn = makeButton(row2, "Auto Daily: OFF", BTN_RED)
	local function setAutoDailyToggleVisualImpl(on)
		if on then
			autoDailyBtn.Text = "Auto Daily: ON"
			autoDailyBtn.BackgroundColor3 = BTN_GREEN
		else
			autoDailyBtn.Text = "Auto Daily: OFF"
			autoDailyBtn.BackgroundColor3 = BTN_RED
		end
	end
	setAutoDailyToggleVisual = setAutoDailyToggleVisualImpl
	autoDailyBtn.MouseButton1Click:Connect(function()
		setAutoDaily(not autoDailyOn)
	end)
	setAutoDailyToggleVisualImpl(autoDailyOn)

	local antiBtn = makeButton(row2, "Anti AFK: OFF", BTN_RED)
	setAntiAfk = function(on)
		antiOn = on == true
		if antiOn then
			antiBtn.Text = "Anti AFK: ON"
			antiBtn.BackgroundColor3 = BTN_GREEN
			antiAfk.start(600)
		else
			antiBtn.Text = "Anti AFK: OFF"
			antiBtn.BackgroundColor3 = BTN_RED
			antiAfk.stop()
		end
	end
	antiBtn.MouseButton1Click:Connect(function()
		setAntiAfk(not antiOn)
	end)

	local row3 = makeRow(t, 2, 34)
	local openGeodeBtn = makeButton(row3, "Open Geode: OFF", BTN_RED)
	local function setGeodeToggleVisualImpl(on)
		if on then
			openGeodeBtn.Text = "Open Geode: ON"
			openGeodeBtn.BackgroundColor3 = BTN_GREEN
		else
			openGeodeBtn.Text = "Open Geode: OFF"
			openGeodeBtn.BackgroundColor3 = BTN_RED
		end
	end
	openGeodeBtn.MouseButton1Click:Connect(function()
		local on = not geodeOpener.getEnabled()
		geodeOpener.setEnabled(on)
		setGeodeToggleVisualImpl(on)
	end)

	local geodeOnlyBtn = makeButton(row3, "Geode only: OFF", BTN_RED)
	local function setGeodeOnlyToggleVisualImpl(on)
		if on then
			geodeOnlyBtn.Text = "Geode only: ON"
			geodeOnlyBtn.BackgroundColor3 = BTN_GREEN
		else
			geodeOnlyBtn.Text = "Geode only: OFF"
			geodeOnlyBtn.BackgroundColor3 = BTN_RED
		end
	end
	setGeodeOnlyToggleVisual = setGeodeOnlyToggleVisualImpl
	geodeOnlyBtn.MouseButton1Click:Connect(function()
		setGeodeOnly(not geodeOnlyOn)
	end)

	setGeodeToggleVisual = setGeodeToggleVisualImpl
	setGeodeToggleVisualImpl(geodeOpener.getEnabled())
	setGeodeOnlyToggleVisualImpl(geodeOnlyOn)

	local row4 = makeRow(t, 3, 34)
	makeButton(row4, "Collect Roe", BTN_GREEN).MouseButton1Click:Connect(function()
		collectRoe()
	end)
	makeButton(row4, "Sell Roe", BTN_PURPLE).MouseButton1Click:Connect(function()
		sellRoe()
	end)
	local roeToggleBtn = makeButton(row4, "Auto Roe: OFF", BTN_RED)
	local function setRoeToggleVisualImpl(on)
		if on then
			roeToggleBtn.Text = "Auto Roe: ON"
			roeToggleBtn.BackgroundColor3 = BTN_GREEN
		else
			roeToggleBtn.Text = "Auto Roe: OFF"
			roeToggleBtn.BackgroundColor3 = BTN_RED
		end
	end
	setRoeToggleVisual = setRoeToggleVisualImpl
	roeToggleBtn.MouseButton1Click:Connect(function()
		setRoeAuto(not roeAutoOn)
	end)
	setRoeToggleVisualImpl(roeAutoOn)

	local row5 = makeRow(t, 2, 34)
	makeButton(row5, "Sell All", BTN_PURPLE).MouseButton1Click:Connect(
		function() sellAll.sellAll() end
	)
	makeButton(row5, "Save Settings", BTN_PURPLE).MouseButton1Click:Connect(function()
		local payload = {
			fishNames = fishAutoDelete.getNames(),
			fishEnabled = fishAutoDelete.getEnabled(),
			antiAfk = antiOn,
			artifactAutoDelete = getArtifactAutoDeleteList and getArtifactAutoDeleteList() or {},
			shopItems = shopBuyer.getItems(),
			shopEnabled = shopBuyer.getEnabled(),
			geodeEnabled = geodeOpener.getEnabled(),
			geodeOnly = geodeOnlyOn,
			autoDaily = autoDailyOn,
			roeAuto = roeAutoOn,
		}
		settingsStore.save(SAVE_PATH, payload)
	end)

	local row6 = makeRow(t, 2, 34)
	makeButton(row6, "Deposit", BTN_GREEN).MouseButton1Click:Connect(
		function()
			portableStash.rebuildHotbarFishCache()
			portableStash.depositFishByWeightDesc()
		end
	)
	makeButton(row6, "Withdraw", BTN_RED).MouseButton1Click:Connect(
		function() portableStash.withdrawAll() end
	)
end

-- Shop tab
do
	local t = tabs["Shop"]
	local row1 = makeRow(t, 3, 34)
	local addBtn = makeButton(row1, "Add", BTN_GREEN)
	local removeBtn = makeButton(row1, "Remove", BTN_RED)
	local shopToggleBtn = makeButton(row1, "Shop Buyer: OFF", BTN_RED)

	local list, lo = makeScrollingList(t, getListHeight({ 34 }))

	local selectedName
	local rows = {}
	local enabledItems = {}

	local function rowColor(name)
		if enabledItems[string.lower(name)] then
			return Color3.fromRGB(58, 120, 66)
		end
		return (name == selectedName and Color3.fromRGB(70, 94, 138) or Color3.fromRGB(45, 45, 54))
	end

	local function paintRows()
		for name, b in pairs(rows) do
			if b.Parent then
				b.BackgroundColor3 = rowColor(name)
			end
		end
	end

	local function refreshList()
		for _, b in pairs(rows) do
			if b.Parent then
				b:Destroy()
			end
		end
		rows = {}

		table.clear(enabledItems)
		local selected = shopBuyer.getItems()
		for i = 1, #selected do
			enabledItems[string.lower(selected[i])] = true
		end

		local names = shopBuyer.getAvailableItems()
		for i = 1, #names do
			local name = names[i]
			local b = makeSelectableRow(list, name, rowColor(name), function()
				selectedName = name
				paintRows()
			end)
			rows[name] = b
		end

		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, lo.AbsoluteContentSize.Y + 12)
			paintRows()
		end)
	end
	refreshShopList = refreshList

	local function setToggleVisual(on)
		if on then
			shopToggleBtn.Text = "Shop Buyer: ON"
			shopToggleBtn.BackgroundColor3 = BTN_GREEN
		else
			shopToggleBtn.Text = "Shop Buyer: OFF"
			shopToggleBtn.BackgroundColor3 = BTN_RED
		end
	end
	setShopToggleVisual = setToggleVisual

	shopToggleBtn.MouseButton1Click:Connect(function()
		local on = not shopBuyer.getEnabled()
		shopBuyer.setEnabled(on)
		setToggleVisual(on)
	end)

	addBtn.MouseButton1Click:Connect(function()
		if not selectedName then return end
		if shopBuyer.addItem(selectedName) then
			refreshList()
		end
	end)

	removeBtn.MouseButton1Click:Connect(function()
		if not selectedName then return end
		if shopBuyer.removeItem(selectedName) then
			refreshList()
		end
	end)
end

local function loadSavedSettings()
	local decoded = settingsStore.load(SAVE_PATH)
	if type(decoded) ~= "table" then
		return false
	end

	if type(decoded.fishNames) == "table" then
		fishAutoDelete.setNames(decoded.fishNames)
	end
	if decoded.fishEnabled ~= nil then
		fishAutoDelete.setEnabled(decoded.fishEnabled == true)
	end
	if setFishToggleVisual then
		setFishToggleVisual(fishAutoDelete.getEnabled())
	end
	if refreshFishList then
		refreshFishList()
	end
	if type(decoded.artifactAutoDelete) == "table" and applyArtifactAutoDeleteList then
		applyArtifactAutoDeleteList(decoded.artifactAutoDelete)
	end
	if setAntiAfk and decoded.antiAfk ~= nil then
		setAntiAfk(decoded.antiAfk == true)
	end
	if type(decoded.shopItems) == "table" then
		shopBuyer.setItems(decoded.shopItems)
	end
	if decoded.shopEnabled ~= nil then
		shopBuyer.setEnabled(decoded.shopEnabled == true)
	end
	if decoded.geodeEnabled ~= nil then
		geodeOpener.setEnabled(decoded.geodeEnabled == true)
	end
	if decoded.geodeOnly ~= nil then
		setGeodeOnly(decoded.geodeOnly == true)
	end
	if decoded.autoDaily ~= nil then
		setAutoDaily(decoded.autoDaily == true)
	end
	if decoded.roeAuto ~= nil then
		setRoeAuto(decoded.roeAuto == true)
	end
	if setShopToggleVisual then
		setShopToggleVisual(shopBuyer.getEnabled())
	end
	if setGeodeToggleVisual then
		setGeodeToggleVisual(geodeOpener.getEnabled())
	end
	if setAutoDailyToggleVisual then
		setAutoDailyToggleVisual(autoDailyOn)
	end
	if refreshShopList then
		refreshShopList()
	end
	return true
end

local hasLoadedSettings = loadSavedSettings()

if not hasLoadedSettings then
	if setFishToggleVisual then
		setFishToggleVisual(fishAutoDelete.getEnabled())
	end
	if refreshFishList then
		refreshFishList()
	end
	if setShopToggleVisual then
		setShopToggleVisual(shopBuyer.getEnabled())
	end
	if refreshShopList then
		refreshShopList()
	end
	if setGeodeToggleVisual then
		setGeodeToggleVisual(geodeOpener.getEnabled())
	end
	if setGeodeOnlyToggleVisual then
		setGeodeOnlyToggleVisual(geodeOnlyOn)
	end
	if setAutoDailyToggleVisual then
		setAutoDailyToggleVisual(autoDailyOn)
	end
	if setRoeToggleVisual then
		setRoeToggleVisual(roeAutoOn)
	end
end

showTab("Artifacts")
