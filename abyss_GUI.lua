local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")
local Common = RS:WaitForChild("common")

local BASE = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/"
local SAVE_PATH = "abyss_settings.json"
local _wait = (task and task.wait) or wait
local _spawn = (task and task.spawn) or spawn
local _defer = (task and task.defer) or function(fn, ...)
	_spawn(fn, ...)
end
local MODULE_SRC = {}
local MODULE_LOADING = {}
local LOADED_MODULES = {}

local function loadModule(name)
	if type(MODULE_SRC) ~= "table" then
		MODULE_SRC = {}
	end
	if type(MODULE_LOADING) ~= "table" then
		MODULE_LOADING = {}
	end
	if type(LOADED_MODULES) ~= "table" then
		LOADED_MODULES = {}
	end
	if type(name) ~= "string" or name == "" then
		error("Invalid module name: " .. tostring(name))
	end

	if LOADED_MODULES[name] then
		return LOADED_MODULES[name]
	end

	local src = MODULE_SRC[name]
	if not src and MODULE_LOADING[name] then
		for _ = 1, 50 do
			local cached = MODULE_SRC[name]
			if type(cached) == "string" and cached ~= "" then
				src = cached
				break
			end
			_wait()
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
		MODULE_SRC[name] = src
	end

	local mod, err = loadstring(src)
	if not mod then
		error("Failed to compile module: " .. tostring(name) .. " (" .. tostring(err) .. ")")
	end
	local ok, result = pcall(mod)
	if not ok then
		error("Failed to run module: " .. tostring(name) .. " (" .. tostring(result) .. ")")
	end
	LOADED_MODULES[name] = result
	return result
end

local function saveSettings(path, payload)
	if not (writefile and type(path) == "string" and type(payload) == "table") then
		return false
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok or type(encoded) ~= "string" then
		return false
	end
	return pcall(writefile, path, encoded)
end

local function parseLegacyFishList(data)
	local list = {}
	for line in data:gmatch("[^\r\n]+") do
		local s = line:gsub("^%s+", ""):gsub("%s+$", "")
		if s ~= "" then
			list[#list + 1] = s
		end
	end
	if #list > 0 then
		return { fishNames = list }
	end
	return nil
end

local function loadSettings(path)
	if not (isfile and readfile and type(path) == "string" and isfile(path)) then
		return nil
	end
	local okRead, data = pcall(readfile, path)
	if not okRead or type(data) ~= "string" then
		return nil
	end

	local decoded
	local okJson = pcall(function()
		decoded = HttpService:JSONDecode(data)
	end)
	if okJson and type(decoded) == "table" then
		return decoded
	end

	return parseLegacyFishList(data)
end

local function prefetchModules(list)
	for i = 1, #list do
		local name = list[i]
		if not MODULE_SRC[name] and not MODULE_LOADING[name] then
			MODULE_LOADING[name] = true
			_spawn(function()
				local ok, fetched = pcall(function()
					return game:HttpGet(BASE .. name .. ".lua")
				end)
				if ok and type(fetched) == "string" and fetched ~= "" then
					MODULE_SRC[name] = fetched
				end
				MODULE_LOADING[name] = false
			end)
		end
	end
end

local MODULE_LIST = {
	"abyss_Sell",
	"abyss_PortableStash",
	"abyss_ArtifactSets",
	"abyss_AntiAfk",
	"abyss_AutoShopBuyer",
	"abyss_ArtifactScan",
	"abyss_ArtifactUpdate",
	"abyss_ArtifactDelete",
	"abyss_AutoArtifactDelete",
	"abyss_AutoFishDelete",
	"abyss_AutoGeode",
	"abyss_GeodeOnly",
	"abyss_AutoDaily",
	"abyss_AutoRejoin",
	"abyss_AutoRoe",
}

prefetchModules(MODULE_LIST)

local sellAll = loadModule("abyss_Sell")
local portableStash = loadModule("abyss_PortableStash")
local artifactSets = loadModule("abyss_ArtifactSets")
local antiAfk = loadModule("abyss_AntiAfk")
local shopBuyer = loadModule("abyss_AutoShopBuyer")
local artifactScanner = loadModule("abyss_ArtifactScan")
local updateArtifacts = loadModule("abyss_ArtifactUpdate")
local deleteBadArtifacts = loadModule("abyss_ArtifactDelete")
local autoDelete = loadModule("abyss_AutoArtifactDelete")
local fishAutoDelete = loadModule("abyss_AutoFishDelete")
local geodeOpener = loadModule("abyss_AutoGeode")
local geodeOnly = loadModule("abyss_GeodeOnly")
local autoDaily = loadModule("abyss_AutoDaily")
local autoRejoin = loadModule("abyss_AutoRejoin")
local roe = loadModule("abyss_AutoRoe")

portableStash.init()
fishAutoDelete.init()

local antiOn = false
local autoDepositOn = false
local autoDepositNext = 0
local autoDepositToken = 0
local setAntiAfk
local setFishToggleVisual
local refreshFishList
local applyArtifactAutoDeleteList
local getArtifactAutoDeleteList
local setShopToggleVisual
local refreshShopList
local refreshGeodeList
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
local GeodeAssets = Common:FindFirstChild("assets")
GeodeAssets = GeodeAssets and GeodeAssets:FindFirstChild("geodes") or Common:WaitForChild("assets"):WaitForChild("geodes")

local autoDailyOn = autoDaily.getEnabled()
local geodeOnlyOn = geodeOnly.getEnabled()
local roeAutoOn = roe.getEnabled()

local function safeGeodeGetNames()
	if geodeOpener and type(geodeOpener.getNames) == "function" then
		local ok, res = pcall(geodeOpener.getNames)
		if ok and type(res) == "table" then
			return res
		end
	end
	return {}
end

local function safeGeodeAddName(name)
	if geodeOpener and type(geodeOpener.addName) == "function" then
		local ok, res = pcall(geodeOpener.addName, name)
		if ok then
			return res == true
		end
	end
	return false
end

local function safeGeodeSetNames(list)
	if geodeOpener and type(geodeOpener.setNames) == "function" then
		pcall(geodeOpener.setNames, list)
	end
end

local function setRoeAuto(on)
	roe.setEnabled(on == true)
	roeAutoOn = roe.getEnabled()
	if setRoeToggleVisual then
		setRoeToggleVisual(roeAutoOn)
	end
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

local function getStorageFolder()
	local gameFolder = workspace:FindFirstChild("Game")
	return gameFolder and gameFolder:FindFirstChild("Storage") or nil
end

local function setAutoDeposit(on, button)
	autoDepositOn = on == true
	autoDepositToken += 1
	if button then
		if autoDepositOn then
			button.Text = "Auto Deposit: ON"
			button.BackgroundColor3 = BTN_GREEN
		else
			button.Text = "Auto Deposit: OFF"
			button.BackgroundColor3 = BTN_RED
		end
	end
	if not autoDepositOn then
		return
	end

	local token = autoDepositToken
	_spawn(function()
		local storage = getStorageFolder()
		while autoDepositOn and token == autoDepositToken do
			local character = lp.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				storage = storage or getStorageFolder()
				if storage then
					local now = os.clock()
					if now >= autoDepositNext then
						local kids = storage:GetChildren()
						for i = 1, #kids do
							local stash = kids[i]
							local root = stash:FindFirstChild("RootPart") or stash.PrimaryPart
							if root and root:IsA("BasePart") then
								if (root.Position - hrp.Position).Magnitude <= 15 then
									portableStash.rebuildHotbarFishCache()
									portableStash.depositFishByWeightDesc()
									autoDepositNext = now + 2
									break
								end
							end
						end
					end
				end
			end
			_wait(0.5)
		end
	end)
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
credit.Text = "Made by @Lvsyyyyy on GitHub | Version: -- | Stash: --/-- | Next Geode: --:--"

local versionText = "--"
local stashText = "--/--"
local nextGeodeText = "--:--"

local function updateCredit()
	credit.Text = "Made by @Lvsyyyyy on GitHub | Version: " .. versionText .. " | Stash: " .. stashText .. " | Next Geode: " .. nextGeodeText
end

local function formatCommitVersion(isoDate)
	if type(isoDate) ~= "string" then
		return nil
	end
	local ok, dt = pcall(DateTime.fromIsoDate, isoDate)
	if not ok or not dt then
		return nil
	end
	local t = os.date("!*t", dt.UnixTimestamp)
	if type(t) ~= "table" then
		return nil
	end
	local day = t.yday
	local hour = t.hour
	local min = t.min
	if type(day) ~= "number" or type(hour) ~= "number" or type(min) ~= "number" then
		return nil
	end
	local hh = string.format("%02d", hour)
	local mm = string.format("%02d", min)
	return tostring(day) .. "-" .. hh .. "/" .. mm
end

local function fetchLatestCommitVersion()
	local ok, body = pcall(function()
		return game:HttpGet("https://api.github.com/repos/Lvsyyy/AbyssRoblox/commits?per_page=1")
	end)
	if not ok or type(body) ~= "string" then
		return nil
	end
	local okJson, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not okJson or type(data) ~= "table" then
		return nil
	end

	local item = data[1] or data
	local commit = item and item.commit
	local committer = commit and commit.committer
	local author = commit and commit.author
	local date = (committer and committer.date) or (author and author.date)
	return formatCommitVersion(date)
end

_spawn(function()
	local v = fetchLatestCommitVersion()
	if v then
		versionText = v
		updateCredit()
	end
end)

local function getStashText()
	local main = pg:FindFirstChild("Main")
	local cap = main
		and main:FindFirstChild("Center")
		and main.Center:FindFirstChild("Storage")
		and main.Center.Storage:FindFirstChild("Capacity")
		and main.Center.Storage.Capacity:FindFirstChild("Capacity")
	if not (cap and cap:IsA("TextLabel")) then
		return "--/--"
	end
	local text = cap.Text or ""
	local cleaned = tostring(text):gsub("[^%d/]", "")
	if cleaned == "" then
		return "--/--"
	end
	return cleaned
end

local artifactFolder = workspace:FindFirstChild("Game")
	and workspace.Game:FindFirstChild("ArtifactAnim")
	and workspace.Game.ArtifactAnim:FindFirstChild("Artifact")

local geodeLabel = nil
local geodeConn = nil

local function setNextGeodeText(text)
	local t = (type(text) == "string" and text ~= "" and text) or "--:--"
	if nextGeodeText ~= t then
		nextGeodeText = t
		updateCredit()
	end
end

local function resolveGeodeLabel()
	if not artifactFolder then
		return nil
	end
	local kids = artifactFolder:GetChildren()
	for i = 1, #kids do
		local model = kids[i]
		if model:IsA("Model") then
			local root = model:FindFirstChild("RootPart")
			local gp = (root and root:FindFirstChild("geodeProcess", true)) or model:FindFirstChild("geodeProcess", true)
			if gp then
				local frame = gp:FindFirstChild("Frame", true)
				local label = frame and frame:FindFirstChild("Label", true)
				if label and label:IsA("TextLabel") then
					return label
				end
			end
		end
	end
	return nil
end

local function disconnectGeode()
	if geodeConn then
		geodeConn:Disconnect()
		geodeConn = nil
	end
	geodeLabel = nil
	setNextGeodeText("--:--")
end

local function attachGeode(label)
	if not (label and label:IsA("TextLabel")) then
		return
	end
	if geodeConn then
		geodeConn:Disconnect()
	end
	geodeLabel = label
	setNextGeodeText(label.Visible and label.Text or "--:--")
	geodeConn = label:GetPropertyChangedSignal("Text"):Connect(function()
		if geodeLabel then
			setNextGeodeText(geodeLabel.Visible and geodeLabel.Text or "--:--")
		end
	end)
end

local function refreshGeodeLabel()
	local label = resolveGeodeLabel()
	if label then
		attachGeode(label)
	else
		disconnectGeode()
	end
end

if artifactFolder then
	artifactFolder.ChildAdded:Connect(function()
		refreshGeodeLabel()
	end)
	artifactFolder.ChildRemoved:Connect(function()
		refreshGeodeLabel()
	end)
end

_spawn(function()
	_wait(1)
	refreshGeodeLabel()
end)

_spawn(function()
	local last = nil
	while true do
		local t = getStashText()
		if t ~= last then
			last = t
			stashText = t
			updateCredit()
		end
		_wait(0.5)
	end
end)

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
	AFK = makeTabContainer(),
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
tabGrid.CellSize = UDim2.new(1 / 5, -8, 1, 0)

local tabArtifacts = tabButton(tabBar, "Artifacts")
local tabCleanup = tabButton(tabBar, "Deletion")
local tabShop = tabButton(tabBar, "Shop")
local tabMisc = tabButton(tabBar, "Misc")
local tabAfk = tabButton(tabBar, "AFK")

tabArtifacts.MouseButton1Click:Connect(function() showTab("Artifacts") end)
tabCleanup.MouseButton1Click:Connect(function() showTab("Deletion") end)
tabShop.MouseButton1Click:Connect(function() showTab("Shop") end)
tabMisc.MouseButton1Click:Connect(function() showTab("Misc") end)
tabAfk.MouseButton1Click:Connect(function() showTab("AFK") end)

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

		_defer(function()
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

		_defer(function()
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

	local raceEquipRF = RS:WaitForChild("common")
		:WaitForChild("packages")
		:WaitForChild("Knit")
		:WaitForChild("Services")
		:WaitForChild("RaceService")
		:WaitForChild("RF")
		:WaitForChild("EquipSlot")

	local row2 = makeRow(t, 3, 34)
	makeButton(row2, "Vamp", BTN_PURPLE).MouseButton1Click:Connect(function()
		raceEquipRF:InvokeServer("1")
	end)
	makeButton(row2, "Shark", BTN_PURPLE).MouseButton1Click:Connect(function()
		raceEquipRF:InvokeServer("2")
	end)
	makeButton(row2, "Angler", BTN_PURPLE).MouseButton1Click:Connect(function()
		raceEquipRF:InvokeServer("3")
	end)

	local row3 = makeRow(t, 3, 34)
	makeButton(row3, "Sell All", BTN_PURPLE).MouseButton1Click:Connect(
		function() sellAll.sellAll() end
	)
	makeButton(row3, "Collect Roe", BTN_PURPLE).MouseButton1Click:Connect(function()
		roe.collect()
	end)
	makeButton(row3, "Sell Roe", BTN_PURPLE).MouseButton1Click:Connect(function()
		roe.sell()
	end)

	local row4 = makeRow(t, 2, 34)
	local geodeOnlyBtn = makeButton(row4, "Geode only: OFF", BTN_RED)
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
	setGeodeOnlyToggleVisualImpl(geodeOnlyOn)

	makeButton(row4, "Save Settings", BTN_PURPLE).MouseButton1Click:Connect(function()
		local payload = {
			fishNames = fishAutoDelete.getNames(),
			fishEnabled = fishAutoDelete.getEnabled(),
			antiAfk = antiOn,
			artifactAutoDelete = getArtifactAutoDeleteList and getArtifactAutoDeleteList() or {},
			shopItems = shopBuyer.getItems(),
			shopEnabled = shopBuyer.getEnabled(),
			geodeEnabled = geodeOpener.getEnabled(),
			geodeNames = safeGeodeGetNames(),
			geodeOnly = geodeOnlyOn,
			autoDaily = autoDailyOn,
			roeAuto = roeAutoOn,
		}
		saveSettings(SAVE_PATH, payload)
	end)

	local row5 = makeRow(t, 3, 34)
	makeButton(row5, "Deposit", BTN_GREEN).MouseButton1Click:Connect(
		function()
			portableStash.rebuildHotbarFishCache()
			portableStash.depositFishByWeightDesc()
		end
	)
	makeButton(row5, "Withdraw", BTN_RED).MouseButton1Click:Connect(
		function() portableStash.withdrawAll() end
	)
	local autoDepositBtn = makeButton(row5, "Auto Deposit: OFF", BTN_RED)
	autoDepositBtn.MouseButton1Click:Connect(function()
		setAutoDeposit(not autoDepositOn, autoDepositBtn)
	end)
	setAutoDeposit(autoDepositOn, autoDepositBtn)
end

-- AFK tab
do
	local t = tabs["AFK"]

	local row1 = makeRow(t, 2, 34)
	local antiBtn = makeButton(row1, "Anti AFK: OFF", BTN_RED)
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

	local autoDailyBtn = makeButton(row1, "Auto Daily: OFF", BTN_RED)
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

	local row2 = makeRow(t, 2, 34)
	local openGeodeBtn = makeButton(row2, "Open Geode: OFF", BTN_RED)
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
	setGeodeToggleVisual = setGeodeToggleVisualImpl
	setGeodeToggleVisualImpl(geodeOpener.getEnabled())

	local roeToggleBtn = makeButton(row2, "Auto Roe: OFF", BTN_RED)
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

	local row3 = makeRow(t, 2, 34)
	local addBtn = makeButton(row3, "Add", BTN_GREEN)
	local removeBtn = makeButton(row3, "Remove", BTN_RED)

	local list, lo = makeScrollingList(t, getListHeight({ 34, 34, 34 }))
	local selectedGeode
	local rows = {}
	local enabledGeodes = {}

	local function rowColor(name)
		if enabledGeodes[string.lower(name)] then
			return Color3.fromRGB(58, 120, 66)
		end
		return (name == selectedGeode and Color3.fromRGB(70, 94, 138) or Color3.fromRGB(45, 45, 54))
	end

	local function paintRows()
		for name, b in pairs(rows) do
			if b.Parent then
				b.BackgroundColor3 = rowColor(name)
			end
		end
	end

	local function getGeodeModelNames()
		local out = {}
		local kids = GeodeAssets:GetChildren()
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

		table.clear(enabledGeodes)
		local enabledNames = safeGeodeGetNames()
		for i = 1, #enabledNames do
			enabledGeodes[string.lower(enabledNames[i])] = true
		end

		local names = getGeodeModelNames()
		for i = 1, #names do
			local name = names[i]
			local b = makeSelectableRow(list, name, rowColor(name), function()
				selectedGeode = name
				paintRows()
			end)
			rows[name] = b
		end

		_defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, lo.AbsoluteContentSize.Y + 12)
			paintRows()
		end)
	end
	refreshGeodeList = refreshList
	refreshList()

	addBtn.MouseButton1Click:Connect(function()
		if not selectedGeode then return end
		if safeGeodeAddName(selectedGeode) then
			refreshList()
		end
	end)

	removeBtn.MouseButton1Click:Connect(function()
		if not selectedGeode then return end
		local names = geodeOpener.getNames()
		local keep = {}
		local removed = false
		local target = string.lower(selectedGeode)
		for i = 1, #names do
			local n = names[i]
			if string.lower(n) ~= target then
				keep[#keep + 1] = n
			else
				removed = true
			end
		end
		if removed then
			safeGeodeSetNames(keep)
			refreshList()
		end
	end)
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

		_defer(function()
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
	local decoded = loadSettings(SAVE_PATH)
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
	if type(decoded.geodeNames) == "table" then
		safeGeodeSetNames(decoded.geodeNames)
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
	if refreshGeodeList then
		refreshGeodeList()
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
	if refreshGeodeList then
		refreshGeodeList()
	end
	if setAutoDailyToggleVisual then
		setAutoDailyToggleVisual(autoDailyOn)
	end
	if setRoeToggleVisual then
		setRoeToggleVisual(roeAutoOn)
	end
end

showTab("Artifacts")
