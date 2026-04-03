local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

local BuyRF = RS.common.packages.Knit.Services.MerchantService.RF.Buy
local MerchantsRoot = WS.Game.Merchants
local AssetsRoot = RS:WaitForChild("common"):WaitForChild("assets")
local OtherAssets = AssetsRoot:WaitForChild("other")
local FishFeedAssets = AssetsRoot:WaitForChild("fish_feed")

local enabled = false
local started = false

local itemsSet = {}
local itemsList = {}
local itemKeys = {}
local selectedCount = 0

local availableItems = {}
local connections = {}
local slotState = {}

local g = (getgenv and getgenv()) or _G
local Framework = g and g.__abyss_framework
local normalize = (Framework and Framework.normalize) or function(s)
    if type(s) ~= "string" then
        return ""
    end
    return string.lower(s):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function addAvailableName(name, seen)
    if type(name) ~= "string" or name == "" then
        return
    end
    local key = normalize(name)
    if key ~= "" and not seen[key] then
        seen[key] = true
        availableItems[#availableItems + 1] = name
    end
end

local function buildAvailableItems()
    table.clear(availableItems)
    local seen = {}

    for _, inst in ipairs(OtherAssets:GetChildren()) do
        if inst:IsA("Model") then
            local lower = normalize(inst.Name)
            if lower:find("shard", 1, true)
                or lower:find("pod", 1, true)
                or lower:find("potion", 1, true)
            then
                addAvailableName(inst.Name, seen)
            end
        end
    end

    for _, inst in ipairs(FishFeedAssets:GetChildren()) do
        if inst:IsA("Model") or inst:IsA("Folder") then
            addAvailableName(inst.Name, seen)
        end
    end

    table.sort(availableItems)
end

local function rebuildItemKeys()
    table.clear(itemKeys)
    for key in pairs(itemsSet) do
        itemKeys[#itemKeys + 1] = key
    end
    selectedCount = #itemKeys
end

local function getItemLabel(slot)
    if not slot then return nil end
    local item = slot:FindFirstChild("Item")
    local surface = item and item:FindFirstChild("SurfaceGui")
    local label = surface and surface:FindFirstChild("Label")
    if label and label:IsA("TextLabel") then
        return label
    end
    return nil
end

local function getStockLabel(slot)
    if not slot then return nil end
    local stock = slot:FindFirstChild("Stock")
    local surface = stock and stock:FindFirstChild("SurfaceGui")
    local label = surface and surface:FindFirstChild("Label")
    if label and label:IsA("TextLabel") then
        return label
    end
    return nil
end

local function shouldBuy(text)
    if selectedCount == 0 then
        return false
    end
    local lower = normalize(text)
    if lower == "" then
        return false
    end
    for i = 1, selectedCount do
        if lower:find(itemKeys[i], 1, true) then
            return true
        end
    end
    return false
end

local function parseStockAmount(text)
    if type(text) ~= "string" then
        return 0
    end
    if text:find("Out of Stock", 1, true) then
        return 0
    end
    local num = text:match("(%d+)%s*in%s*Stock")
    if num then
        return tonumber(num) or 0
    end
    return 0
end

local function tryBuy(merchant, slotId, label, stockLabel)
    if not enabled or selectedCount == 0 then return end
    if not merchant or not slotId then return end
    local text = label and label.Text or ""
    if not shouldBuy(text) then return end
    local amount = parseStockAmount(stockLabel and stockLabel.Text or "")
    if amount <= 0 then return end

    pcall(function()
        BuyRF:InvokeServer(merchant.Name, slotId, amount)
    end)
end

local function watchSlot(merchant, slot)
    local id = tonumber(slot.Name)
    if not id then return end
    local label = getItemLabel(slot)
    if not label then return end
    local stockLabel = getStockLabel(slot)

    if stockLabel then
        local conn2 = stockLabel:GetPropertyChangedSignal("Text"):Connect(function()
            local newStock = stockLabel.Text
            if enabled and selectedCount > 0 then
                if parseStockAmount(newStock) > 0 then
                    tryBuy(merchant, id, label, stockLabel)
                end
            end
        end)
        connections[#connections + 1] = conn2
    end

    if enabled then
        tryBuy(merchant, id, label, stockLabel)
    end
end

local function tryBuyMerchantSlots(merchant)
    if not (merchant and merchant:IsA("Instance")) then return end
    local folder = merchant:FindFirstChild("Folder")
    local tableRoot = folder and folder:FindFirstChild("Table")
    if not tableRoot then return end
    for _, slot in ipairs(tableRoot:GetChildren()) do
        local id = tonumber(slot.Name)
        if id then
            local label = getItemLabel(slot)
            if label then
                local stockLabel = getStockLabel(slot)
                tryBuy(merchant, id, label, stockLabel)
            end
        end
    end
end

local function watchMerchant(merchant)
    if not (merchant and merchant:IsA("Instance")) then return end
    local folder = merchant:FindFirstChild("Folder")
    local tableRoot = folder and folder:FindFirstChild("Table")
    if not tableRoot then return end

    for _, slot in ipairs(tableRoot:GetChildren()) do
        watchSlot(merchant, slot)
    end
end

local function scanAllMerchants()
    for _, merchant in ipairs(MerchantsRoot:GetChildren()) do
        watchMerchant(merchant)
    end
end

local function tryBuyAllMerchants()
    for _, merchant in ipairs(MerchantsRoot:GetChildren()) do
        tryBuyMerchantSlots(merchant)
    end
end

local function startWatching()
    if started then return false end
    started = true
    scanAllMerchants()
    return true
end

local function setItems(list)
    table.clear(itemsSet)
    table.clear(itemsList)
    for i = 1, #list do
        local name = list[i]
        if type(name) == "string" and name ~= "" then
            local key = normalize(name)
            if key ~= "" and not itemsSet[key] then
                itemsSet[key] = true
                itemsList[#itemsList + 1] = name
            end
        end
    end
    rebuildItemKeys()
end

local function addItem(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local key = normalize(name)
    if key == "" or itemsSet[key] then
        return false
    end
    itemsSet[key] = true
    itemsList[#itemsList + 1] = name
    rebuildItemKeys()
    return true
end

local function hasItem(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local key = normalize(name)
    return key ~= "" and itemsSet[key] == true
end

local function removeItem(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local key = normalize(name)
    if not itemsSet[key] then
        return false
    end
    itemsSet[key] = nil
    for i = #itemsList, 1, -1 do
        if normalize(itemsList[i]) == key then
            table.remove(itemsList, i)
            break
        end
    end
    rebuildItemKeys()
    return true
end

local function getItems()
    local out = table.create(#itemsList)
    for i = 1, #itemsList do out[i] = itemsList[i] end
    return out
end

local function getAvailableItems()
    buildAvailableItems()
    local out = table.create(#availableItems)
    for i = 1, #availableItems do out[i] = availableItems[i] end
    return out
end

local function setEnabled(v)
    enabled = v == true
    if enabled then
        local didScan = startWatching()
        if not didScan then
            tryBuyAllMerchants()
        end
    end
end

local function getEnabled()
    return enabled
end

buildAvailableItems()

return {
    setItems = setItems,
    addItem = addItem,
    hasItem = hasItem,
    removeItem = removeItem,
    getItems = getItems,
    getAvailableItems = getAvailableItems,
    setEnabled = setEnabled,
    getEnabled = getEnabled,
}
