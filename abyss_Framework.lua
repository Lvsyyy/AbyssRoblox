local Framework = {}

function Framework.normalize(s)
    return string.lower(tostring(s or "")):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function Framework.isHexId32(v)
    return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

function Framework.safeInvoke(rf, ...)
    if rf then
        local args = { ... }
        pcall(function()
            rf:InvokeServer(table.unpack(args))
        end)
    end
end

function Framework.setToggleVisual(button, on, onText, offText, onColor, offColor)
    if not button then return end
    if on then
        button.Text = onText
        button.BackgroundColor3 = onColor
    else
        button.Text = offText
        button.BackgroundColor3 = offColor
    end
end

function Framework.bindToggle(button, getState, setState, onText, offText, onColor, offColor)
    local function refresh()
        local on = getState()
        Framework.setToggleVisual(button, on, onText, offText, onColor, offColor)
    end

    button.MouseButton1Click:Connect(function()
        setState(not getState())
        refresh()
    end)

    refresh()
end

function Framework.createListController(opts)
    local list = opts.list
    local layout = opts.layout
    local makeRow = opts.makeRow
    local getItems = opts.getItems
    local isEnabled = opts.isEnabled
    local colorFor = opts.colorFor
    local onSelect = opts.onSelect
    local keyFn = opts.keyFn
    local enabledSet = opts.enabledSet

    local function isEnabledDefault(name)
        if enabledSet then
            local key = keyFn and keyFn(name) or name
            return enabledSet[key] == true
        end
        return false
    end

    local state = {
        selected = nil,
        rows = {},
    }

    local function rowColor(name)
        local enabled = isEnabled and isEnabled(name) or isEnabledDefault(name)
        return colorFor(name, state.selected == name, enabled)
    end

    local function paint()
        for name, b in pairs(state.rows) do
            if b.Parent then
                b.BackgroundColor3 = rowColor(name)
            end
        end
    end

    local function clear()
        for _, b in pairs(state.rows) do
            if b.Parent then b:Destroy() end
        end
        state.rows = {}
    end

    local function refresh()
        clear()
        local items = getItems and getItems() or {}
        for i = 1, #items do
            local name = items[i]
            local b = makeRow(list, name, rowColor(name), function()
                state.selected = name
                if onSelect then onSelect(name) end
                paint()
            end)
            state.rows[name] = b
        end
        task.defer(function()
            if layout then
                list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
            end
            paint()
        end)
    end

    return {
        refresh = refresh,
        paint = paint,
        clear = clear,
        setSelected = function(name) state.selected = name end,
        getSelected = function() return state.selected end,
        setEnabledSet = function(set) enabledSet = set end,
    }
end

function Framework.saveSettings(path, payload)
    local HttpService = game:GetService("HttpService")
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

function Framework.loadSettings(path)
    local HttpService = game:GetService("HttpService")
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

function Framework.createInventoryWatcher(pg, opts)
    opts = opts or {}
    local attrs = opts.attrs or { "id", "name", "class", "weight", "fullname", "stars", "amount" }
    local subscribers = {}
    local cache = {}
    local hooks = {}

    local function collect()
        local out = {}
        local main = pg:FindFirstChild("Main")
        local backpack = main and main:FindFirstChild("Backpack")
        if not backpack then return out end
        local list = backpack.List and backpack.List.CanvasGroup and backpack.List.CanvasGroup.ScrollingFrame
        local hotbar = backpack:FindFirstChild("Hotbar")

        local function addItem(frame, source)
            if not (frame and frame:IsA("Frame")) then return end
            local item = {
                frame = frame,
                id = frame:GetAttribute("id"),
                name = frame:GetAttribute("name"),
                class = frame:GetAttribute("class"),
                weight = frame:GetAttribute("weight"),
                fullname = frame:GetAttribute("fullname"),
                stars = frame:GetAttribute("stars"),
                amount = frame:GetAttribute("amount"),
                source = source,
            }
            if item.id or item.name or item.class then
                out[#out + 1] = item
            end
        end

        if list then
            for _, child in ipairs(list:GetChildren()) do
                addItem(child, "backpack")
            end
        end
        if hotbar then
            for _, child in ipairs(hotbar:GetChildren()) do
                if child:IsA("Frame") and tonumber(child.Name) then
                    addItem(child, "hotbar")
                end
            end
        end
        return out
    end

    local function notify()
        cache = collect()
        for i = 1, #subscribers do
            pcall(subscribers[i], cache)
        end
    end

    local function hookFrame(frame)
        if hooks[frame] then return end
        hooks[frame] = true
        local function onChange()
            notify()
        end
        for i = 1, #attrs do
            frame:GetAttributeChangedSignal(attrs[i]):Connect(onChange)
        end
        frame.AncestryChanged:Connect(function(_, parent)
            if not parent then
                hooks[frame] = nil
            end
        end)
    end

    local function start()
        local main = pg:WaitForChild("Main")
        local backpack = main:WaitForChild("Backpack")
        local list = backpack.List.CanvasGroup.ScrollingFrame
        local hotbar = backpack.Hotbar

        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") then
                hookFrame(child)
            end
        end
        for _, child in ipairs(hotbar:GetChildren()) do
            if child:IsA("Frame") then
                hookFrame(child)
            end
        end

        list.ChildAdded:Connect(function(child)
            if child:IsA("Frame") then
                hookFrame(child)
            end
            notify()
        end)
        list.ChildRemoved:Connect(function()
            notify()
        end)

        hotbar.ChildAdded:Connect(function(child)
            if child:IsA("Frame") then
                hookFrame(child)
            end
            notify()
        end)
        hotbar.ChildRemoved:Connect(function()
            notify()
        end)

        notify()
    end

    return {
        subscribe = function(fn)
            if type(fn) == "function" then
                subscribers[#subscribers + 1] = fn
            end
        end,
        getCache = function() return cache end,
        start = start,
    }
end

function Framework.startInventoryPipeline(pg, callbacks)
    callbacks = callbacks or {}
    local watcher = Framework.createInventoryWatcher(pg, callbacks.options)
    local function add(fn)
        if type(fn) == "function" then
            watcher.subscribe(fn)
        end
    end
    if type(callbacks.onList) == "function" then
        add(callbacks.onList)
    elseif type(callbacks.onList) == "table" then
        for i = 1, #callbacks.onList do
            add(callbacks.onList[i])
        end
    end
    if type(callbacks.onEach) == "function" then
        add(function(list)
            for i = 1, #list do
                callbacks.onEach(list[i], list)
            end
        end)
    end
    task.spawn(watcher.start)
    return watcher
end

function Framework.getStorageFolder()
    local gameFolder = workspace:FindFirstChild("Game")
    return gameFolder and gameFolder:FindFirstChild("Storage") or nil
end

function Framework.createAutoDepositRunner(opts)
    opts = opts or {}
    local enabled = false
    local token = 0
    local nextDeposit = 0
    local getCharacter = opts.getCharacter
    local getStorage = opts.getStorageFolder or Framework.getStorageFolder
    local depositFn = opts.depositFn
    local distance = tonumber(opts.distance) or 15
    local interval = tonumber(opts.interval) or 0.5
    local cooldown = tonumber(opts.cooldown) or 2

    local function setEnabled(on)
        enabled = on == true
        token += 1
        if not enabled then
            return
        end
        local myToken = token
        task.spawn(function()
            local storage = getStorage and getStorage() or nil
            while enabled and token == myToken do
                local character = getCharacter and getCharacter() or nil
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    storage = storage or (getStorage and getStorage() or nil)
                    if storage and type(depositFn) == "function" then
                        local now = os.clock()
                        if now >= nextDeposit then
                            for _, stash in ipairs(storage:GetChildren()) do
                                local root = stash:FindFirstChild("RootPart") or stash.PrimaryPart
                                if root and root:IsA("BasePart") then
                                    if (root.Position - hrp.Position).Magnitude <= distance then
                                        depositFn()
                                        nextDeposit = now + cooldown
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(interval)
            end
        end)
    end

    return {
        setEnabled = setEnabled,
        getEnabled = function() return enabled end,
    }
end

function Framework.formatCommitVersion(isoDate)
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

function Framework.fetchLatestCommitVersion(owner, repo)
    owner = owner or "Lvsyyy"
    repo = repo or "AbyssRoblox"
    local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/commits?per_page=1"
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end
    local HttpService = game:GetService("HttpService")
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
    return Framework.formatCommitVersion(date)
end

function Framework.formatStashText(text)
    local cleaned = tostring(text or ""):gsub("[^%d/]", "")
    if cleaned == "" then
        return "--/--"
    end
    return cleaned
end

function Framework.watchStashCapacity(pg, onChange)
    if type(onChange) ~= "function" then
        return nil
    end
    local main = pg:WaitForChild("Main")
    local center = main:WaitForChild("Center")
    local storage = center:WaitForChild("Storage")
    local capWrap = storage:WaitForChild("Capacity")
    local cap = capWrap:WaitForChild("Capacity")
    if not cap or not cap:IsA("TextLabel") then
        return nil
    end
    local function emit()
        onChange(Framework.formatStashText(cap.Text))
    end
    emit()
    return cap:GetPropertyChangedSignal("Text"):Connect(emit)
end

function Framework.watchGeodeTimer(onChange)
    if type(onChange) ~= "function" then
        return nil
    end
    local artifactFolder = workspace:FindFirstChild("Game")
        and workspace.Game:FindFirstChild("ArtifactAnim")
        and workspace.Game.ArtifactAnim:FindFirstChild("Artifact")
    local geodeLabel = nil
    local geodeConn = nil
    local addConn = nil
    local removeConn = nil

    local function setText(text)
        onChange((type(text) == "string" and text ~= "" and text) or "--:--")
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
                local gp = root and root:FindFirstChild("geodeProcess")
                local frame = gp and gp:FindFirstChild("Frame")
                local label = frame and frame:FindFirstChild("Label")
                if label and label:IsA("TextLabel") then
                    return label
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
        setText("--:--")
    end

    local function safeRef(inst)
        if inst and type(cloneref) == "function" then
            return cloneref(inst)
        end
        return inst
    end

    local function attachGeode(label)
        if not (label and label:IsA("TextLabel")) then
            return
        end
        if geodeConn then
            geodeConn:Disconnect()
        end
        geodeLabel = safeRef(label)
        setText(label.Visible and label.Text or "--:--")
        geodeConn = label:GetPropertyChangedSignal("Text"):Connect(function()
            if geodeLabel then
                setText(geodeLabel.Visible and geodeLabel.Text or "--:--")
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
        addConn = artifactFolder.ChildAdded:Connect(refreshGeodeLabel)
        removeConn = artifactFolder.ChildRemoved:Connect(refreshGeodeLabel)
    end

    task.spawn(function()
        task.wait(1)
        refreshGeodeLabel()
    end)

    return {
        disconnect = function()
            if addConn then addConn:Disconnect() end
            if removeConn then removeConn:Disconnect() end
            disconnectGeode()
        end,
    }
end

function Framework.bindAddRemoveButtons(opts)
    local addBtn = opts.addBtn
    local removeBtn = opts.removeBtn
    local getSelected = opts.getSelected
    local onAdd = opts.onAdd
    local onRemove = opts.onRemove
    local onRefresh = opts.onRefresh

    if addBtn and addBtn.MouseButton1Click then
        addBtn.MouseButton1Click:Connect(function()
            local sel = getSelected and getSelected() or nil
            if not sel then return end
            if onAdd then onAdd(sel) end
            if onRefresh then onRefresh() end
        end)
    end

    if removeBtn and removeBtn.MouseButton1Click then
        removeBtn.MouseButton1Click:Connect(function()
            local sel = getSelected and getSelected() or nil
            if not sel then return end
            if onRemove then onRemove(sel) end
            if onRefresh then onRefresh() end
        end)
    end
end

function Framework.listToSet(list, lower)
    local out = {}
    if type(list) ~= "table" then
        return out
    end
    for i = 1, #list do
        local v = list[i]
        if v ~= nil then
            if lower then
                v = string.lower(tostring(v))
            end
            out[v] = true
        end
    end
    return out
end

function Framework.makeEnabledColorFn(enabledColor, selectedColor, defaultColor)
    return function(_, selected, enabled)
        if enabled then
            return enabledColor
        end
        return (selected and selectedColor or defaultColor)
    end
end

function Framework.makeListRefresh(listCtrl, getEnabledList, lower)
    return function()
        local list = getEnabledList and getEnabledList() or nil
        listCtrl.setEnabledSet(Framework.listToSet(list, lower))
        listCtrl.refresh()
    end
end

function Framework.sellAll()
    local RS = game:GetService("ReplicatedStorage")
    local S = RS.common.packages.Knit.Services
    local InvRF = S.InventoryService.RF
    local SellRF = S.SellService.RF.SellInventory
    local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout
    local EquipRaceSlotRF = S.RaceService and S.RaceService.RF and S.RaceService.RF.EquipSlot or nil
    EquipArtifactsLoadoutRF:InvokeServer(4)
    if EquipRaceSlotRF then
        EquipRaceSlotRF:InvokeServer("2")
    end
    SellRF:InvokeServer()
end

function Framework.createAntiAfk()
    local VIM = game:GetService("VirtualInputManager")
    local running = false
    local stopFlag = false

    local function start(intervalSeconds)
        if running then return end
        running = true
        stopFlag = false

        task.spawn(function()
            while not stopFlag do
                VIM:SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
                task.wait()
                VIM:SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
                task.wait(intervalSeconds or 600)
            end
            running = false
        end)
    end

    local function stop()
        stopFlag = true
    end

    return {
        start = start,
        stop = stop,
    }
end

do
    local g = (getgenv and getgenv()) or _G
    if g then
        g.__abyss_framework = Framework
    end
end

return Framework
