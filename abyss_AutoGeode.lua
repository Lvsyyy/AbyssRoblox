local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

local openRF = RS:WaitForChild("common")
    :WaitForChild("packages")
    :WaitForChild("Knit")
    :WaitForChild("Services")
    :WaitForChild("ArtifactsService")
    :WaitForChild("RF")
    :WaitForChild("Open")

local artifactFolder = WS:WaitForChild("Game"):WaitForChild("ArtifactAnim"):WaitForChild("Artifact")

local nameSet = { ["coconut"] = true }
local nameList = { "Coconut" }

local g = (getgenv and getgenv()) or _G
local Framework = g and g.__abyss_framework
local normalizeName = (Framework and Framework.normalize) or function(s)
    return string.lower(tostring(s or ""))
end

local function toNum(v)
    if type(v) == "number" then
        return v
    end
    if type(v) == "string" then
        local n = tonumber(v)
        if n then
            return n
        end
    end
    return nil
end

local function parseAmountText(s)
    if type(s) ~= "string" then
        return nil
    end
    local n = tonumber((s:gsub("[^%d]", "")))
    if n and n > 0 then
        return n
    end
    return nil
end

local function matchesGeodeName(value, key)
    if value == "" then return false end
    if value == key then return true end
    if value == (key .. " geode") or value == ("geode " .. key) then
        return true
    end
    if value:find(key, 1, true) and value:find("geode", 1, true) then
        return true
    end
    return false
end

local function getSelectedGeodeKey(item)
    local class = normalizeName(item.class)
    if class ~= "geodes" then
        return nil
    end

    local name = normalizeName(item.name)
    local full = normalizeName(item.fullname)
    for key in pairs(nameSet) do
        if matchesGeodeName(name, key) or matchesGeodeName(full, key) then
            return key
        end
    end
    return nil
end

local function getRowAmount(item)
    local attrAmount = toNum(item.amount)
    if attrAmount and attrAmount > 0 then
        return math.floor(attrAmount)
    end

    local frame = item.frame
    local btn = frame and frame:FindFirstChild("Btn")
    local frame = btn and btn:FindFirstChild("Frame")
    local amountObj = frame and frame:FindFirstChild("Amount")
    if amountObj and amountObj:IsA("TextLabel") then
        local n = parseAmountText(amountObj.Text)
        if n and n > 0 then
            return n
        end
    end

    return 1
end

local inventoryList = {}

local function getSelectedGeodeCounts(list)
    local seenIds = {}
    local totals = {}
    for key in pairs(nameSet) do
        totals[key] = 0
    end

    for _, item in ipairs(list) do
        local id = item.id
        if not (id and seenIds[id]) then
            local key = getSelectedGeodeKey(item)
            if key then
                totals[key] = (totals[key] or 0) + getRowAmount(item)
            end
            if id then
                seenIds[id] = true
            end
        end
    end
    return totals
end

local enabled = false
local watching = false

local function openGeode()
    if #artifactFolder:GetChildren() > 0 then
        return
    end

    if #nameList == 0 then return end

    local counts = getSelectedGeodeCounts(inventoryList)
    for i = 1, #nameList do
        local name = nameList[i]
        local key = normalizeName(name)
        local count = counts[key] or 0
        if count > 0 then
            openRF:InvokeServer(name, math.min(99, count))
            return
        end
    end
end

local function tryOpen()
    if not enabled then return end
    pcall(openGeode)
end

local function startWatching()
    if watching then return end
    watching = true

    local function checkEmpty()
        if enabled and #artifactFolder:GetChildren() == 0 then
            tryOpen()
        end
    end

    artifactFolder.ChildRemoved:Connect(checkEmpty)
    artifactFolder.ChildAdded:Connect(checkEmpty)
    checkEmpty()
end

local function setEnabled(v)
    enabled = v == true
    if enabled then
        startWatching()
        if #artifactFolder:GetChildren() == 0 then
            tryOpen()
        end
    end
end

local function getEnabled()
    return enabled
end

local function setNames(list)
    table.clear(nameSet)
    table.clear(nameList)
    for i = 1, #list do
        local name = list[i]
        if type(name) == "string" and name ~= "" then
            local key = normalizeName(name)
            if not nameSet[key] then
                nameSet[key] = true
                nameList[#nameList + 1] = name
            end
        end
    end
end

local function addName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local key = normalizeName(name)
    if nameSet[key] then
        return false
    end
    nameSet[key] = true
    nameList[#nameList + 1] = name
    return true
end

local function onInventoryChanged(list)
    inventoryList = type(list) == "table" and list or {}
    if enabled and #artifactFolder:GetChildren() == 0 then
        tryOpen()
    end
end


local function getNames()
    local out = table.create(#nameList)
    for i = 1, #nameList do
        out[i] = nameList[i]
    end
    return out
end

return {
    openGeode = openGeode,
    setEnabled = setEnabled,
    getEnabled = getEnabled,
    setNames = setNames,
    addName = addName,
    onInventoryChanged = onInventoryChanged,
    getNames = getNames,
}
