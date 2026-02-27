local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local BASE = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/"
local SAVE_PATH = "abyss_settings.json"

local function loadModule(name)
	local src = game:HttpGet(BASE .. name .. ".lua")
	local mod = loadstring(src)
	return mod()
end

local sellAll = loadModule("sellAll")
local portableStash = loadModule("portableStash")
local artifactSets = loadModule("artifactSets")
local antiAfk = loadModule("antiAfk")
local shopBuyer = loadModule("shopBuyer")
local artifactScanner = loadModule("artifactScanner")
local updateArtifacts = loadModule("abyss_UpdateArtifacts")
local deleteBadArtifacts = loadModule("abyss_DeleteBadArtifacts")
local autoDelete = loadModule("artifactAutoDelete")
local fishAutoDelete = loadModule("fishAutoDelete")
local geodeOpener = loadModule("abyss_GeodeOpener")
local autoRejoin = loadModule("abyss_AutoRejoin")

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

local function tabButton(parent, text)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Size = UDim2.new(1, 0, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 12
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
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = text
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end


local tabs = {
	Artifacts = makeTabContainer(),
	["Deletion / Clean Up"] = makeTabContainer(),
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
tabGrid.CellSize = UDim2.new(1 / 3, -8, 1, 0)

local tabArtifacts = tabButton(tabBar, "Artifacts")
local tabCleanup = tabButton(tabBar, "Deletion / Clean Up")
local tabMisc = tabButton(tabBar, "Misc")

tabArtifacts.MouseButton1Click:Connect(function() showTab("Artifacts") end)
tabCleanup.MouseButton1Click:Connect(function() showTab("Deletion / Clean Up") end)
tabMisc.MouseButton1Click:Connect(function() showTab("Misc") end)

-- Artifacts tab
do
	local t = tabs["Artifacts"]

	local row1 = makeRow(t, 3, 34)
	makeButton(row1, "Weight Set", Color3.fromRGB(90, 110, 160)).MouseButton1Click:Connect(
		function() artifactSets.equipWeightSet() end
	)
	makeButton(row1, "Damage Set", Color3.fromRGB(160, 110, 90)).MouseButton1Click:Connect(
		function() artifactSets.equipDamageSet() end
	)
	makeButton(row1, "Speed Set", Color3.fromRGB(80, 130, 90)).MouseButton1Click:Connect(
		function() artifactSets.equipSpeedSet() end
	)

	local row2 = makeRow(t, 2, 34)
	makeButton(row2, "Update Sets", Color3.fromRGB(70, 94, 138)).MouseButton1Click:Connect(
		function() updateArtifacts.updateAllSets() end
	)
	makeButton(row2, "Delete Bad Artifacts", Color3.fromRGB(120, 62, 62)).MouseButton1Click:Connect(
		function() deleteBadArtifacts.deleteBadArtifacts() end
	)

	local list = Instance.new("ScrollingFrame")
	list.Parent = t
	list.Position = UDim2.fromOffset(0, 0)
	list.Size = UDim2.new(1, 0, 0, 150)
	list.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

	local lo = Instance.new("UIListLayout", list)
	lo.Padding = UDim.new(0, 4)

	local pd = Instance.new("UIPadding", list)
	pd.PaddingTop = UDim.new(0, 6)
	pd.PaddingBottom = UDim.new(0, 6)
	pd.PaddingLeft = UDim.new(0, 6)
	pd.PaddingRight = UDim.new(0, 6)

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
			local b = Instance.new("TextButton")
			b.Parent = list
			b.Size = UDim2.new(1, -8, 0, 24)
			b.Text = name
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Font = Enum.Font.Gotham
			b.TextSize = 13
			b.TextColor3 = Color3.new(1, 1, 1)
			b.BackgroundColor3 = rowColor(name)
			b.BorderSizePixel = 0
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
			local p = Instance.new("UIPadding", b)
			p.PaddingLeft = UDim.new(0, 8)

			b.MouseButton1Click:Connect(function()
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
	local enableDeleteBtn = makeButton(row3, "Enable Delete", Color3.fromRGB(58, 120, 66))
	enableDeleteBtn.MouseButton1Click:Connect(
		function()
			if not sel then return end
			autoDelete.setAutoDelete(sel, true)
			autoDeleteEnabled[sel] = true
			paint()
		end
	)
	local disableDeleteBtn = makeButton(row3, "Disable Delete", Color3.fromRGB(120, 62, 62))
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

-- Deletion / Clean Up tab
do
	local t = tabs["Deletion / Clean Up"]
	local row1 = makeRow(t, 2, 34)
	makeButton(row1, "Deposit", Color3.fromRGB(46, 140, 87)).MouseButton1Click:Connect(
		function()
			portableStash.rebuildHotbarFishCache()
			portableStash.depositFishByWeightDesc()
		end
	)
	makeButton(row1, "Withdraw", Color3.fromRGB(150, 62, 62)).MouseButton1Click:Connect(
		function() portableStash.withdrawAll() end
	)

	local row2 = makeRow(t, 2, 34)
	local toggleBtn = makeButton(row2, "Auto Delete: OFF", Color3.fromRGB(95, 95, 95))
	local clearBtn = makeButton(row2, "Clear List", Color3.fromRGB(120, 62, 62))

	local inputRow = makeRow(t, 2, 34)
	local nameBox = Instance.new("TextBox")
	nameBox.Parent = inputRow
	nameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	nameBox.Font = Enum.Font.Gotham
	nameBox.TextSize = 13
	nameBox.TextColor3 = Color3.new(1, 1, 1)
	nameBox.PlaceholderText = ""
	nameBox.ClearTextOnFocus = false
	nameBox.Text = ""
	nameBox.BorderSizePixel = 0
	Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

	local addBtn = makeButton(inputRow, "Add", Color3.fromRGB(58, 120, 66))

	local list = Instance.new("ScrollingFrame")
	list.Parent = t
	list.Position = UDim2.fromOffset(0, 0)
	list.Size = UDim2.new(1, 0, 0, 150)
	list.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

	local lo = Instance.new("UIListLayout", list)
	lo.Padding = UDim.new(0, 4)

	local pd = Instance.new("UIPadding", list)
	pd.PaddingTop = UDim.new(0, 6)
	pd.PaddingBottom = UDim.new(0, 6)
	pd.PaddingLeft = UDim.new(0, 6)
	pd.PaddingRight = UDim.new(0, 6)

	local function refreshList()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		local names = fishAutoDelete.getNames()
		for i = 1, #names do
			local label = Instance.new("TextLabel")
			label.Parent = list
			label.Size = UDim2.new(1, -8, 0, 22)
			label.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
			label.BorderSizePixel = 0
			label.Font = Enum.Font.Gotham
			label.TextSize = 12
			label.TextColor3 = Color3.fromRGB(240, 240, 240)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = names[i]
			local lp = Instance.new("UIPadding", label)
			lp.PaddingLeft = UDim.new(0, 6)
		end
		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, lo.AbsoluteContentSize.Y + 12)
		end)
	end
	refreshFishList = refreshList

	local function setToggleVisual(on)
		if on then
			toggleBtn.Text = "Auto Delete: ON"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
		else
			toggleBtn.Text = "Auto Delete: OFF"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
		end
	end
	setFishToggleVisual = setToggleVisual

	toggleBtn.MouseButton1Click:Connect(function()
		local on = not fishAutoDelete.getEnabled()
		fishAutoDelete.setEnabled(on)
		setToggleVisual(on)
	end)

	addBtn.MouseButton1Click:Connect(function()
		local name = nameBox.Text
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" then return end
		if fishAutoDelete.addName(name) then
			nameBox.Text = ""
			refreshList()
		end
	end)

	clearBtn.MouseButton1Click:Connect(function()
		fishAutoDelete.clearNames()
		refreshList()
	end)

	setToggleVisual(fishAutoDelete.getEnabled())
	refreshList()
end

-- Misc tab
do
	local t = tabs["Misc"]
	local row1 = makeRow(t, 3, 34)
	makeButton(row1, "Sell All", Color3.fromRGB(136, 108, 168)).MouseButton1Click:Connect(
		function() sellAll.sellAll() end
	)

	local antiBtn = makeButton(row1, "Anti AFK: OFF", Color3.fromRGB(95, 95, 95))
	setAntiAfk = function(on)
		antiOn = on == true
		if antiOn then
			antiBtn.Text = "Anti AFK: ON"
			antiBtn.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
			antiAfk.start(10)
		else
			antiBtn.Text = "Anti AFK: OFF"
			antiBtn.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
			antiAfk.stop()
		end
	end
	antiBtn.MouseButton1Click:Connect(function()
		setAntiAfk(not antiOn)
	end)

	makeButton(row1, "Save Settings", Color3.fromRGB(70, 94, 138)).MouseButton1Click:Connect(function()
		if not writefile then return end
		local payload = {
			fishNames = fishAutoDelete.getNames(),
			fishEnabled = fishAutoDelete.getEnabled(),
			antiAfk = antiOn,
			artifactAutoDelete = getArtifactAutoDeleteList and getArtifactAutoDeleteList() or {},
			shopItems = shopBuyer.getItems(),
			shopEnabled = shopBuyer.getEnabled(),
			geodeEnabled = geodeOpener.getEnabled(),
		}
		local ok, data = pcall(function() return HttpService:JSONEncode(payload) end)
		if ok and type(data) == "string" then
			pcall(writefile, SAVE_PATH, data)
		end
	end)

	local row2 = makeRow(t, 2, 34)
	local shopToggleBtn = makeButton(row2, "Shop Buyer: OFF", Color3.fromRGB(95, 95, 95))
	local openGeodeBtn = makeButton(row2, "Open Geode: OFF", Color3.fromRGB(95, 95, 95))
	local function setGeodeToggleVisualImpl(on)
		if on then
			openGeodeBtn.Text = "Open Geode: ON"
			openGeodeBtn.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
		else
			openGeodeBtn.Text = "Open Geode: OFF"
			openGeodeBtn.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
		end
	end
	openGeodeBtn.MouseButton1Click:Connect(function()
		local on = not geodeOpener.getEnabled()
		geodeOpener.setEnabled(on)
		setGeodeToggleVisualImpl(on)
	end)
	setGeodeToggleVisual = setGeodeToggleVisualImpl
	setGeodeToggleVisualImpl(geodeOpener.getEnabled())

	local inputRow = makeRow(t, 3, 34)
	local itemBox = Instance.new("TextBox")
	itemBox.Parent = inputRow
	itemBox.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	itemBox.Font = Enum.Font.Gotham
	itemBox.TextSize = 13
	itemBox.TextColor3 = Color3.new(1, 1, 1)
	itemBox.PlaceholderText = ""
	itemBox.ClearTextOnFocus = false
	itemBox.Text = ""
	itemBox.BorderSizePixel = 0
	Instance.new("UICorner", itemBox).CornerRadius = UDim.new(0, 6)

	local addBtn = makeButton(inputRow, "Add", Color3.fromRGB(58, 120, 66))
	local shopClearBtn = makeButton(inputRow, "Clear List", Color3.fromRGB(120, 62, 62))

	local list = Instance.new("ScrollingFrame")
	list.Parent = t
	list.Position = UDim2.fromOffset(0, 0)
	list.Size = UDim2.new(1, 0, 0, 150)
	list.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

	local lo = Instance.new("UIListLayout", list)
	lo.Padding = UDim.new(0, 4)

	local pd = Instance.new("UIPadding", list)
	pd.PaddingTop = UDim.new(0, 6)
	pd.PaddingBottom = UDim.new(0, 6)
	pd.PaddingLeft = UDim.new(0, 6)
	pd.PaddingRight = UDim.new(0, 6)

	local function refreshList()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		local names = shopBuyer.getItems()
		for i = 1, #names do
			local label = Instance.new("TextLabel")
			label.Parent = list
			label.Size = UDim2.new(1, -8, 0, 22)
			label.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
			label.BorderSizePixel = 0
			label.Font = Enum.Font.Gotham
			label.TextSize = 12
			label.TextColor3 = Color3.fromRGB(240, 240, 240)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = names[i]
			local lp = Instance.new("UIPadding", label)
			lp.PaddingLeft = UDim.new(0, 6)
		end
		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, lo.AbsoluteContentSize.Y + 12)
		end)
	end
	refreshShopList = refreshList

	local function setToggleVisual(on)
		if on then
			shopToggleBtn.Text = "Shop Buyer: ON"
			shopToggleBtn.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
		else
			shopToggleBtn.Text = "Shop Buyer: OFF"
			shopToggleBtn.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
		end
	end
	setShopToggleVisual = setToggleVisual

	shopToggleBtn.MouseButton1Click:Connect(function()
		local on = not shopBuyer.getEnabled()
		shopBuyer.setEnabled(on)
		setToggleVisual(on)
	end)

	addBtn.MouseButton1Click:Connect(function()
		local name = itemBox.Text
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" then return end
		if shopBuyer.addItem(name) then
			itemBox.Text = ""
			refreshList()
		end
	end)

	shopClearBtn.MouseButton1Click:Connect(function()
		shopBuyer.clearItems()
		refreshList()
	end)

	setToggleVisual(shopBuyer.getEnabled())
	refreshList()
end

local function loadSavedSettings()
	if not (isfile and readfile and isfile(SAVE_PATH)) then return end
	local ok, data = pcall(readfile, SAVE_PATH)
	if not ok or type(data) ~= "string" then return end

	local decoded
	local okDecode = pcall(function()
		decoded = HttpService:JSONDecode(data)
	end)

	if okDecode and type(decoded) == "table" then
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
		if setShopToggleVisual then
			setShopToggleVisual(shopBuyer.getEnabled())
		end
		if setGeodeToggleVisual then
			setGeodeToggleVisual(geodeOpener.getEnabled())
		end
		if refreshShopList then
			refreshShopList()
		end
	else
		local list = {}
		for line in data:gmatch("[^\r\n]+") do
			local s = line:gsub("^%s+", ""):gsub("%s+$", "")
			if s ~= "" then list[#list + 1] = s end
		end
		if #list > 0 then
			fishAutoDelete.setNames(list)
		end
		if refreshFishList then
			refreshFishList()
		end
	end
end

loadSavedSettings()

showTab("Artifacts")
