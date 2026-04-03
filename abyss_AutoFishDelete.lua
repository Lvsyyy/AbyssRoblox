local RS = game:GetService("ReplicatedStorage")

local S = RS.common.packages.Knit.Services
local BackpackRF = S.BackpackService.RF
local DeleteFishRF = BackpackRF.DeleteFish

local enabled = false

local nameSet = {}
local nameList = {}
local keyList = {}
local keyCount = 0
local g = (getgenv and getgenv()) or _G
local Framework = g and g.__abyss_framework
local normalizeName = (Framework and Framework.normalize) or function(s)
    return string.lower(s or "")
end
local isFishId = (Framework and Framework.isHexId32) or function(v)
    return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

local function rebuildKeyList()
    table.clear(keyList)
    for key in pairs(nameSet) do
        keyList[#keyList + 1] = key
    end
    keyCount = #keyList
end

local function isTargetDeleteName(name)
    if keyCount == 0 or type(name) ~= "string" or name == "" then
        return false
    end
    local n = normalizeName(name)
    for i = 1, keyCount do
        if n == keyList[i] then
            return true
        end
    end
    return false
end

local function deleteAllTargetFish(list)
    if keyCount == 0 then
        return
    end
    local seen = {}
    for _, item in ipairs(list) do
        local id = item and item.id
        local name = item and item.name
        if isFishId(id) and isTargetDeleteName(name) and not seen[id] then
            seen[id] = true
            DeleteFishRF:InvokeServer(id)
        end
    end
end

local inventoryList = {}

local function onInventoryChanged(list)
    inventoryList = type(list) == "table" and list or {}
    if enabled then
        deleteAllTargetFish(inventoryList)
    end
end

local function setEnabled(v)
    enabled = v == true
    if enabled then
        deleteAllTargetFish(inventoryList)
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
    rebuildKeyList()
    if enabled then
        deleteAllTargetFish(inventoryList)
    end
end

local function addName(name)
    if type(name) == "string" and name ~= "" then
        local key = normalizeName(name)
        if nameSet[key] then
            return false
        end
        nameSet[key] = true
        nameList[#nameList + 1] = name
        rebuildKeyList()
        if enabled then
            deleteAllTargetFish(inventoryList)
        end
        return true
    end
    return false
end

local function clearNames()
    table.clear(nameSet)
    table.clear(nameList)
    table.clear(keyList)
    keyCount = 0
end

local function getNames()
    local out = table.create(#nameList)
    for i = 1, #nameList do out[i] = nameList[i] end
    return out
end

return {
    onInventoryChanged = onInventoryChanged,
    setEnabled = setEnabled,
    getEnabled = getEnabled,
    setNames = setNames,
    addName = addName,
    clearNames = clearNames,
    getNames = getNames,
}
