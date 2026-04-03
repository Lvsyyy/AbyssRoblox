local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

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
local g = (getgenv and getgenv()) or _G
local MODULE_CACHE_VERSION = "2026-04-03-1"
local sharedCache = g and g.__abyss_module_cache
if not sharedCache or (g and g.__abyss_module_cache_version ~= MODULE_CACHE_VERSION) then
    sharedCache = { src = {}, loading = {} }
    if g then
        g.__abyss_module_cache = sharedCache
        g.__abyss_module_cache_version = MODULE_CACHE_VERSION
    end
end
local MODULE_SRC = sharedCache.src
local MODULE_LOADING = sharedCache.loading
local LOADED_MODULES = {}
local CACHE_BUST = tostring(math.floor((os.clock() * 1000) % 1000000000))

local function fetchModuleSource(name, cacheBust)
    local url = BASE .. name .. ".lua"
    if cacheBust then
        url = url .. "?cb=" .. CACHE_BUST
    end
    local ok, fetched = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(fetched) == "string" and fetched ~= "" then
        MODULE_SRC[name] = fetched
        return fetched
    end
    return nil
end

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
        src = fetchModuleSource(name, false)
        if not src then
            error("Failed to load module: " .. tostring(name))
        end
    end

    local mod, err = loadstring(src)
    if not mod then
        -- Cache-bust and retry once in case the CDN served stale content.
        src = fetchModuleSource(name, true) or src
        mod, err = loadstring(src)
    end
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

local function prefetchModules(list)
    for i = 1, #list do
        local name = list[i]
        if not MODULE_SRC[name] and not MODULE_LOADING[name] then
            MODULE_LOADING[name] = true
            _spawn(function()
                fetchModuleSource(name, true)
                MODULE_LOADING[name] = false
            end)
        end
    end
end

local MODULE_LIST = {
    "abyss_PortableStash",
    "abyss_ArtifactManager",
    "abyss_AutoShopBuyer",
    "abyss_AutoFishDelete",
    "abyss_AutoGeode",
    "abyss_GeodeOnly",
    "abyss_AutoDaily",
    "abyss_AutoRejoin",
    "abyss_AutoRoe",
    "abyss_ValueCalculator",
    "abyss_FishPond",
    "abyss_Framework",
}

prefetchModules(MODULE_LIST)

local Framework = loadModule("abyss_Framework")
local portableStash = loadModule("abyss_PortableStash")
local artifactManager = loadModule("abyss_ArtifactManager")
local antiAfk = Framework.createAntiAfk()
local shopBuyer = loadModule("abyss_AutoShopBuyer")
local artifactScanner = artifactManager
local updateArtifacts = artifactManager
local deleteBadArtifacts = artifactManager
local setAutoDeleteRF = RS.common.packages.Knit.Services.ArtifactsService.RF.SetAutoDelete
local fishAutoDelete = loadModule("abyss_AutoFishDelete")
local geodeOpener = loadModule("abyss_AutoGeode")
local geodeOnly = loadModule("abyss_GeodeOnly")
local autoDaily = loadModule("abyss_AutoDaily")
local autoRejoin = loadModule("abyss_AutoRejoin")
local roe = loadModule("abyss_AutoRoe")
local valueCalc = loadModule("abyss_ValueCalculator")
local fishPond = loadModule("abyss_FishPond")

portableStash.init()

if fishPond and fishPond.setValueCalculator then
    fishPond.setValueCalculator(valueCalc)
end

if valueCalc and valueCalc.getTables then
    _spawn(function()
        pcall(function()
            valueCalc.getTables()
        end)
    end)
end

local valueHooked = setmetatable({}, { __mode = "k" })

local function getValueLabel(frame)
    if not frame then return nil end
    local btn = frame:FindFirstChild("Btn")
    local f = btn and btn:FindFirstChild("Frame")
    local label = f and f:FindFirstChild("Item")
    if label and label:IsA("TextLabel") then
        return label
    end
    return nil
end

local function getBaseText(label)
    local base = label:GetAttribute("AbyssBaseText")
    if type(base) == "string" and base ~= "" then
        return base
    end
    local text = label.Text or ""
    local firstLine = text:match("([^\n\r]+)") or text
    label:SetAttribute("AbyssBaseText", firstLine)
    return firstLine
end

local function formatValueLine(value)
    return "\n<font color='#7FFF9B'>$" .. tostring(value) .. "</font>"
end

local function hookValueFrame(frame)
    if valueHooked[frame] then return end
    valueHooked[frame] = true

    local label = getValueLabel(frame)
    if not label then return end
    label.RichText = true
    local updating = false

    local function apply()
        if updating then return end
        updating = true
        local baseText = getBaseText(label)
        local info = {
            name = frame:GetAttribute("name"),
            fullname = frame:GetAttribute("fullname"),
            weight = frame:GetAttribute("weight"),
            stars = frame:GetAttribute("stars"),
            class = frame:GetAttribute("class"),
        }
        local val = valueCalc and valueCalc.computeValue and valueCalc.computeValue(info, baseText) or nil
        if val then
            label.Text = baseText .. formatValueLine(val)
        else
            label.Text = baseText
        end
        updating = false
    end

    frame:GetAttributeChangedSignal("weight"):Connect(apply)
    frame:GetAttributeChangedSignal("fullname"):Connect(apply)
    frame:GetAttributeChangedSignal("name"):Connect(apply)
    frame:GetAttributeChangedSignal("class"):Connect(apply)
    frame:GetAttributeChangedSignal("stars"):Connect(apply)
    frame.AncestryChanged:Connect(function(_, parent)
        if not parent then
            valueHooked[frame] = nil
        end
    end)
    label:GetPropertyChangedSignal("Text"):Connect(function()
        if updating then return end
        label:SetAttribute("AbyssBaseText", nil)
        apply()
    end)

    apply()
end

Framework.startInventoryPipeline(pg, {
    onList = function(list)
        if fishAutoDelete and fishAutoDelete.onInventoryChanged then
            fishAutoDelete.onInventoryChanged(list)
        end
        if geodeOpener and geodeOpener.onInventoryChanged then
            geodeOpener.onInventoryChanged(list)
        end
        if portableStash and portableStash.onInventoryChanged then
            portableStash.onInventoryChanged(list)
        end
        if fishPond and fishPond.setInventory then
            fishPond.setInventory(list)
        end
    end,
    onEach = function(item)
        if item.class == "fish" and item.frame then
            hookValueFrame(item.frame)
        end
    end,
})

local antiOn = false
local autoDepositOn = false
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
local EquipArtifactsLoadoutRF = RS.common.packages.Knit.Services.InventoryService.RF.EquipArtifactsLoadout
local GeodeAssets = Common:FindFirstChild("assets")
GeodeAssets = GeodeAssets and GeodeAssets:FindFirstChild("geodes") or Common:WaitForChild("assets"):WaitForChild("geodes")


local function bindToggle(button, getState, setState, onText, offText)
    Framework.bindToggle(button, getState, setState, onText, offText, BTN_GREEN, BTN_RED)
    return function(on, skipState)
        if not skipState then
            setState(on)
        end
        Framework.setToggleVisual(button, on, onText, offText, BTN_GREEN, BTN_RED)
    end
end

local autoDailyOn = autoDaily.getEnabled()
local geodeOnlyOn = geodeOnly.getEnabled()
local roeAutoOn = roe.getEnabled()

local function geodeNames(op, arg)
    if not geodeOpener then
        return op == "get" and {} or false
    end
    local fn
    if op == "get" then
        fn = geodeOpener.getNames
    elseif op == "add" then
        fn = geodeOpener.addName
    elseif op == "set" then
        fn = geodeOpener.setNames
    end
    if type(fn) ~= "function" then
        return op == "get" and {} or false
    end
    local ok, res = pcall(fn, arg)
    if not ok then
        return op == "get" and {} or false
    end
    if op == "get" then
        return type(res) == "table" and res or {}
    end
    if op == "add" then
        return res == true
    end
    return true
end

local function setRoeAuto(on)
    roe.setEnabled(on == true)
    roeAutoOn = roe.getEnabled()
    if setRoeToggleVisual then
        setRoeToggleVisual(roeAutoOn, true)
    end
end

local function setAutoDaily(on)
    autoDaily.setEnabled(on == true)
    autoDailyOn = autoDaily.getEnabled()
    if setAutoDailyToggleVisual then
        setAutoDailyToggleVisual(autoDailyOn, true)
    end
end

local function setGeodeOnly(on)
    geodeOnlyOn = on == true
    geodeOnly.setEnabled(geodeOnlyOn)
    geodeOnlyOn = geodeOnly.getEnabled()
    if setGeodeOnlyToggleVisual then
        setGeodeOnlyToggleVisual(geodeOnlyOn, true)
    end
end

local autoDepositRunner = Framework.createAutoDepositRunner({
    getCharacter = function() return lp.Character end,
    depositFn = portableStash.depositFishByWeightDesc,
    distance = 15,
    interval = 0.5,
    cooldown = 2,
})

local function setAutoDeposit(on)
    autoDepositRunner.setEnabled(on == true)
    autoDepositOn = autoDepositRunner.getEnabled()
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

_spawn(function()
    local v = Framework.fetchLatestCommitVersion("Lvsyyy", "AbyssRoblox")
    if v then
        versionText = v
        updateCredit()
    end
end)

Framework.watchStashCapacity(pg, function(text)
    stashText = text or "--/--"
    updateCredit()
end)

Framework.watchGeodeTimer(function(text)
    nextGeodeText = text or "--:--"
    updateCredit()
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

local TAB_NAMES = { "Artifacts", "Deletion", "Shop", "Misc", "AFK" }
local tabs = {}
for i = 1, #TAB_NAMES do
    tabs[TAB_NAMES[i]] = makeTabContainer()
end

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
tabGrid.CellSize = UDim2.new(1 / #TAB_NAMES, -8, 1, 0)

local tabButtons = {}
for i = 1, #TAB_NAMES do
    local name = TAB_NAMES[i]
    local btn = tabButton(tabBar, name)
    tabButtons[name] = btn
    btn.MouseButton1Click:Connect(function() showTab(name) end)
end

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
    local autoDeleteEnabled = {}


    local function getArtifactNames()
        local ok, names = pcall(artifactScanner.scanArtifactNames)
        if not ok or type(names) ~= "table" then
            return {}
        end
        return names
    end

    local artifactListCtrl = Framework.createListController({
        list = list,
        layout = lo,
        makeRow = makeSelectableRow,
        getItems = getArtifactNames,
        colorFor = Framework.makeEnabledColorFn(
            Color3.fromRGB(150, 62, 62),
            Color3.fromRGB(70, 94, 138),
            Color3.fromRGB(45, 45, 54)
        ),
        onSelect = function() end,
    })

    local function getEnabledArtifactsList()
        local out = {}
        for name in pairs(autoDeleteEnabled) do
            out[#out + 1] = name
        end
        table.sort(out)
        return out
    end

    local refreshArtifacts = Framework.makeListRefresh(artifactListCtrl, getEnabledArtifactsList)
    refreshArtifacts()

    local row3 = makeRow(t, 2, 34)
    local enableDeleteBtn = makeButton(row3, "Add", BTN_GREEN)
    local disableDeleteBtn = makeButton(row3, "Remove", BTN_RED)
    Framework.bindAddRemoveButtons({
        addBtn = enableDeleteBtn,
        removeBtn = disableDeleteBtn,
        getSelected = artifactListCtrl.getSelected,
        onAdd = function(sel)
            pcall(function() setAutoDeleteRF:InvokeServer(sel, true) end)
            autoDeleteEnabled[sel] = true
        end,
        onRemove = function(sel)
            pcall(function() setAutoDeleteRF:InvokeServer(sel, false) end)
            autoDeleteEnabled[sel] = nil
        end,
        onRefresh = refreshArtifacts,
    })

    local function applyArtifactAutoDeleteListImpl(list)
        for i = 1, #list do
            local name = list[i]
            pcall(function() setAutoDeleteRF:InvokeServer(name, true) end)
            autoDeleteEnabled[name] = true
        end
        refreshArtifacts()
    end
    local function getArtifactAutoDeleteListImpl()
        return getEnabledArtifactsList()
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

    local fishListCtrl = Framework.createListController({
        list = list,
        layout = lo,
        makeRow = makeSelectableRow,
        getItems = getFishModelNames,
        colorFor = Framework.makeEnabledColorFn(
            BTN_RED,
            Color3.fromRGB(70, 94, 138),
            Color3.fromRGB(45, 45, 54)
        ),
        onSelect = function(name)
            -- nothing extra
        end,
    })

    local refreshList = Framework.makeListRefresh(fishListCtrl, fishAutoDelete.getNames)
    refreshFishList = refreshList

    setFishToggleVisual = bindToggle(
        toggleBtn,
        fishAutoDelete.getEnabled,
        function(on) fishAutoDelete.setEnabled(on) end,
        "Delete Fish: ON",
        "Delete Fish: OFF"
    )

    Framework.bindAddRemoveButtons({
        addBtn = addBtn,
        removeBtn = delBtn,
        getSelected = fishListCtrl.getSelected,
        onAdd = function(selectedFish)
            if fishAutoDelete.addName(selectedFish) then
                refreshList()
            end
        end,
        onRemove = function(selectedFish)
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
        end,
        onRefresh = function() end,
    })

end

-- Misc tab
do
    local t = tabs["Misc"]
    local row1 = makeRow(t, 3, 34)
    makeButton(row1, "Weight Set", BTN_PURPLE).MouseButton1Click:Connect(
        function() EquipArtifactsLoadoutRF:InvokeServer(1) end
    )
    makeButton(row1, "Damage Set", BTN_PURPLE).MouseButton1Click:Connect(
        function() EquipArtifactsLoadoutRF:InvokeServer(2) end
    )
    makeButton(row1, "Speed Set", BTN_PURPLE).MouseButton1Click:Connect(
        function() EquipArtifactsLoadoutRF:InvokeServer(3) end
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
            function() Framework.sellAll() end
        )
    makeButton(row3, "Collect Roe", BTN_PURPLE).MouseButton1Click:Connect(function()
        roe.collect()
    end)
    makeButton(row3, "Sell Roe", BTN_PURPLE).MouseButton1Click:Connect(function()
        roe.sell()
    end)

    local row4 = makeRow(t, 2, 34)
    local geodeOnlyBtn = makeButton(row4, "Geode only: OFF", BTN_RED)
    setGeodeOnlyToggleVisual = bindToggle(
        geodeOnlyBtn,
        function() return geodeOnlyOn end,
        function(on) setGeodeOnly(on) end,
        "Geode only: ON",
        "Geode only: OFF"
    )
    setGeodeOnlyToggleVisual(geodeOnlyOn, true)

    makeButton(row4, "Save Settings", BTN_PURPLE).MouseButton1Click:Connect(function()
        local payload = {
            fishNames = fishAutoDelete.getNames(),
            fishEnabled = fishAutoDelete.getEnabled(),
            antiAfk = antiOn,
            artifactAutoDelete = getArtifactAutoDeleteList and getArtifactAutoDeleteList() or {},
            shopItems = shopBuyer.getItems(),
            shopEnabled = shopBuyer.getEnabled(),
            geodeEnabled = geodeOpener.getEnabled(),
            geodeNames = geodeNames("get"),
            geodeOnly = geodeOnlyOn,
            autoDaily = autoDailyOn,
            roeAuto = roeAutoOn,
        }
        Framework.saveSettings(SAVE_PATH, payload)
    end)

    local row5 = makeRow(t, 2, 34)
    makeButton(row5, "Pond Deposit", BTN_GREEN).MouseButton1Click:Connect(function()
        if fishPond and fishPond.depositBest then
            fishPond.depositBest()
        end
    end)
    makeButton(row5, "Pond Withdraw", BTN_RED).MouseButton1Click:Connect(function()
        if fishPond and fishPond.withdrawAll then
            fishPond.withdrawAll()
        end
    end)

    local row6 = makeRow(t, 3, 34)
    makeButton(row6, "Deposit", BTN_GREEN).MouseButton1Click:Connect(
        function()
            portableStash.depositFishByWeightDesc()
        end
    )
    makeButton(row6, "Withdraw", BTN_RED).MouseButton1Click:Connect(
        function() portableStash.withdrawAll() end
    )
    local autoDepositBtn = makeButton(row6, "Auto Deposit: OFF", BTN_RED)
    bindToggle(
        autoDepositBtn,
        function() return autoDepositOn end,
        setAutoDeposit,
        "Auto Deposit: ON",
        "Auto Deposit: OFF"
    )
end

-- AFK tab
do
    local t = tabs["AFK"]

    local row1 = makeRow(t, 2, 34)
    local antiBtn = makeButton(row1, "Anti AFK: OFF", BTN_RED)
    local function setAntiAfkImpl(on)
        antiOn = on == true
        if antiOn then
            antiAfk.start(600)
        else
            antiAfk.stop()
        end
    end
    setAntiAfk = bindToggle(
        antiBtn,
        function() return antiOn end,
        setAntiAfkImpl,
        "Anti AFK: ON",
        "Anti AFK: OFF"
    )

    local autoDailyBtn = makeButton(row1, "Auto Daily: OFF", BTN_RED)
    setAutoDailyToggleVisual = bindToggle(
        autoDailyBtn,
        function() return autoDailyOn end,
        function(on) setAutoDaily(on) end,
        "Auto Daily: ON",
        "Auto Daily: OFF"
    )
    setAutoDailyToggleVisual(autoDailyOn, true)

    local row2 = makeRow(t, 2, 34)
    local openGeodeBtn = makeButton(row2, "Open Geode: OFF", BTN_RED)
    setGeodeToggleVisual = bindToggle(
        openGeodeBtn,
        function() return geodeOpener.getEnabled() end,
        function(on) geodeOpener.setEnabled(on) end,
        "Open Geode: ON",
        "Open Geode: OFF"
    )
    setGeodeToggleVisual(geodeOpener.getEnabled())

    local roeToggleBtn = makeButton(row2, "Auto Roe: OFF", BTN_RED)
    setRoeToggleVisual = bindToggle(
        roeToggleBtn,
        function() return roeAutoOn end,
        function(on) setRoeAuto(on) end,
        "Auto Roe: ON",
        "Auto Roe: OFF"
    )
    setRoeToggleVisual(roeAutoOn, true)

    local row3 = makeRow(t, 2, 34)
    local addBtn = makeButton(row3, "Add", BTN_GREEN)
    local removeBtn = makeButton(row3, "Remove", BTN_RED)

    local list, lo = makeScrollingList(t, getListHeight({ 34, 34, 34 }))

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
    local geodeListCtrl = Framework.createListController({
        list = list,
        layout = lo,
        makeRow = makeSelectableRow,
        getItems = getGeodeModelNames,
        keyFn = string.lower,
        colorFor = Framework.makeEnabledColorFn(
            Color3.fromRGB(58, 120, 66),
            Color3.fromRGB(70, 94, 138),
            Color3.fromRGB(45, 45, 54)
        ),
        onSelect = function() end,
    })

    local refreshList = Framework.makeListRefresh(geodeListCtrl, function()
        return geodeNames("get")
    end, true)
    refreshGeodeList = refreshList
    refreshList()

    Framework.bindAddRemoveButtons({
        addBtn = addBtn,
        removeBtn = removeBtn,
        getSelected = geodeListCtrl.getSelected,
        onAdd = function(selectedGeode)
            if geodeNames("add", selectedGeode) then
                refreshList()
            end
        end,
        onRemove = function(selectedGeode)
            local names = geodeNames("get")
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
                geodeNames("set", keep)
                refreshList()
            end
        end,
        onRefresh = function() end,
    })
end

-- Shop tab
do
    local t = tabs["Shop"]
    local row1 = makeRow(t, 3, 34)
    local addBtn = makeButton(row1, "Add", BTN_GREEN)
    local removeBtn = makeButton(row1, "Remove", BTN_RED)
    local shopToggleBtn = makeButton(row1, "Shop Buyer: OFF", BTN_RED)

    local list, lo = makeScrollingList(t, getListHeight({ 34 }))
    local shopListCtrl = Framework.createListController({
        list = list,
        layout = lo,
        makeRow = makeSelectableRow,
        getItems = shopBuyer.getAvailableItems,
        isEnabled = shopBuyer.hasItem,
        keyFn = string.lower,
        colorFor = Framework.makeEnabledColorFn(
            Color3.fromRGB(58, 120, 66),
            Color3.fromRGB(70, 94, 138),
            Color3.fromRGB(45, 45, 54)
        ),
        onSelect = function() end,
    })

    local refreshList = function()
        shopListCtrl.refresh()
    end
    refreshShopList = refreshList

    setShopToggleVisual = bindToggle(
        shopToggleBtn,
        function() return shopBuyer.getEnabled() end,
        function(on) shopBuyer.setEnabled(on) end,
        "Shop Buyer: ON",
        "Shop Buyer: OFF"
    )

    Framework.bindAddRemoveButtons({
        addBtn = addBtn,
        removeBtn = removeBtn,
        getSelected = shopListCtrl.getSelected,
        onAdd = function(selectedName)
            if shopBuyer.addItem(selectedName) then
                refreshList()
            end
        end,
        onRemove = function(selectedName)
            if shopBuyer.removeItem(selectedName) then
                refreshList()
            end
        end,
        onRefresh = function() end,
    })
end

local function updateSettingsUI()
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
        setGeodeOnlyToggleVisual(geodeOnlyOn, true)
    end
    if refreshGeodeList then
        refreshGeodeList()
    end
    if setAutoDailyToggleVisual then
        setAutoDailyToggleVisual(autoDailyOn, true)
    end
    if setRoeToggleVisual then
        setRoeToggleVisual(roeAutoOn, true)
    end
end

local function loadSavedSettings()
    local decoded = Framework.loadSettings(SAVE_PATH)
    if type(decoded) ~= "table" then
        return false
    end

    if type(decoded.fishNames) == "table" then
        fishAutoDelete.setNames(decoded.fishNames)
    end
    if decoded.fishEnabled ~= nil then
        fishAutoDelete.setEnabled(decoded.fishEnabled == true)
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
        geodeNames("set", decoded.geodeNames)
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
    updateSettingsUI()
    return true
end

local hasLoadedSettings = loadSavedSettings()
if not hasLoadedSettings then
    updateSettingsUI()
end

showTab("Artifacts")
