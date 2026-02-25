local Players = game:GetService("Players")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local BASE = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/"

local function loadModule(name)
	local src = game:HttpGet(BASE .. name .. ".lua")
	local mod = loadstring(src)
	return mod()
end

local sellAll = loadModule("sellAll")
local portableStash = loadModule("portableStash")
local artifactSets = loadModule("artifactSets")
local antiAfk = loadModule("antiAfk")
local artifactScanner = loadModule("artifactScanner")

portableStash.init()

local old = pg:FindFirstChild("AbyssQoLGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "AbyssQoLGui"
sg.ResetOnSpawn = false
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size = UDim2.fromOffset(440, 320)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true
frame.Position = UDim2.fromOffset(100, 100)
frame.BorderSizePixel = 0

local function tabButton(text, x)
	local b = Instance.new("TextButton")
	b.Parent = frame
	b.Position = UDim2.fromOffset(x, 10)
	b.Size = UDim2.fromOffset(130, 26)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = text
	b.BorderSizePixel = 0
	return b
end

local function makeTabContainer()
	local t = Instance.new("Frame")
	t.Parent = frame
	t.Position = UDim2.fromOffset(10, 46)
	t.Size = UDim2.fromOffset(420, 264)
	t.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	t.BorderSizePixel = 0
	t.Visible = false
	return t
end

local function btn(parent, text, x, y, w, c)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, 34)
	b.BackgroundColor3 = c
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = text
	b.BorderSizePixel = 0
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

local tabArtifacts = tabButton("Artifacts", 10)
local tabCleanup = tabButton("Deletion / Clean Up", 155)
local tabMisc = tabButton("Misc", 300)

tabArtifacts.MouseButton1Click:Connect(function() showTab("Artifacts") end)
tabCleanup.MouseButton1Click:Connect(function() showTab("Deletion / Clean Up") end)
tabMisc.MouseButton1Click:Connect(function() showTab("Misc") end)

-- Artifacts tab
do
	local t = tabs["Artifacts"]
	btn(t, "Weight Set", 10, 10, 120, Color3.fromRGB(90, 110, 160)).MouseButton1Click:Connect(
		function() artifactSets.equipWeightSet() end
	)
	btn(t, "Damage Set", 140, 10, 120, Color3.fromRGB(160, 110, 90)).MouseButton1Click:Connect(
		function() artifactSets.equipDamageSet() end
	)
	btn(t, "Speed Set", 270, 10, 120, Color3.fromRGB(80, 130, 90)).MouseButton1Click:Connect(
		function() artifactSets.equipSpeedSet() end
	)

	local scanBtn = btn(t, "Scan Artifacts", 10, 54, 160, Color3.fromRGB(70, 94, 138))

	local list = Instance.new("ScrollingFrame")
	list.Parent = t
	list.Position = UDim2.fromOffset(10, 96)
	list.Size = UDim2.fromOffset(400, 150)
	list.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6

	local lo = Instance.new("UIListLayout", list)
	lo.Padding = UDim.new(0, 4)

	local pd = Instance.new("UIPadding", list)
	pd.PaddingTop = UDim.new(0, 6)
	pd.PaddingBottom = UDim.new(0, 6)
	pd.PaddingLeft = UDim.new(0, 6)
	pd.PaddingRight = UDim.new(0, 6)

	local function clearList()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
	end

	local function populateArtifacts()
		clearList()
		local names = artifactScanner.scanArtifactNames()
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

	scanBtn.MouseButton1Click:Connect(populateArtifacts)
end

-- Deletion / Clean Up tab
do
	local t = tabs["Deletion / Clean Up"]
	btn(t, "Deposit", 10, 10, 120, Color3.fromRGB(46, 140, 87)).MouseButton1Click:Connect(
		function()
			portableStash.rebuildHotbarFishCache()
			portableStash.depositFishByWeightDesc()
		end
	)
	btn(t, "Withdraw", 140, 10, 120, Color3.fromRGB(150, 62, 62)).MouseButton1Click:Connect(
		function() portableStash.withdrawAll() end
	)
end

-- Misc tab
do
	local t = tabs["Misc"]
	btn(t, "Sell All", 10, 10, 120, Color3.fromRGB(136, 108, 168)).MouseButton1Click:Connect(
		function() sellAll.sellAll() end
	)

	local antiBtn = btn(t, "Anti AFK: OFF", 140, 10, 160, Color3.fromRGB(95, 95, 95))
	local antiOn = false
	antiBtn.MouseButton1Click:Connect(function()
		antiOn = not antiOn
		if antiOn then
			antiBtn.Text = "Anti AFK: ON"
			antiBtn.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
			antiAfk.start(10)
		else
			antiBtn.Text = "Anti AFK: OFF"
			antiBtn.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
			antiAfk.stop()
		end
	end)
end

showTab("Artifacts")
