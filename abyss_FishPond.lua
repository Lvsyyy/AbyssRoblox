local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local PondRF = RS.common.packages.Knit.Services.FishPondService.RF
local DepositRF = PondRF.Deposit
local WithdrawRF = PondRF.Withdraw

local inventoryList = {}
local valueCalc = nil

local g = (getgenv and getgenv()) or _G
local Framework = g and g.__abyss_framework
local isId = (Framework and Framework.isHexId32) or function(str)
    return type(str) == "string" and #str == 32 and str:match("^[a-f0-9]+$") ~= nil
end

local function setInventory(list)
    inventoryList = type(list) == "table" and list or {}
end

local function setValueCalculator(calc)
    valueCalc = calc
end

local function getItemLabel(frame)
    if not frame then return nil end
    local btn = frame:FindFirstChild("Btn")
    local f = btn and btn:FindFirstChild("Frame")
    local label = f and f:FindFirstChild("Item")
    if label and label:IsA("TextLabel") then
        return label
    end
    return nil
end

local function valueFromLabel(frame)
    local label = getItemLabel(frame)
    if not label then return nil end
    local text = tostring(label.Text or "")
    local valText = text:match("%$([%d,]+)")
    if not valText then return nil end
    local num = tonumber(valText:gsub(",", ""), 10)
    return num
end

local function computeValue(item)
    if not item or item.class ~= "fish" then
        return nil
    end
    local label = getItemLabel(item.frame)
    local baseText = label and (label:GetAttribute("AbyssBaseText") or label.Text) or nil
    if valueCalc and valueCalc.computeValue then
        local v = valueCalc.computeValue(item, baseText)
        if v then return v end
    end
    return valueFromLabel(item.frame)
end

local function getSortedFishIdsByValue()
    local rows = {}
    local seen = {}
    for _, item in ipairs(inventoryList) do
        local id = item.id
        if isId(id) and not seen[id] and item.class == "fish" then
            seen[id] = true
            rows[#rows + 1] = { id = id, value = computeValue(item) or 0 }
        end
    end
    table.sort(rows, function(a, b) return a.value > b.value end)
    local out = {}
    for i = 1, #rows do
        out[i] = rows[i].id
    end
    return out
end

local function getPondFishIds()
    local pondList = pg:FindFirstChild("Main")
        and pg.Main:FindFirstChild("Center")
        and pg.Main.Center:FindFirstChild("FishPond")
        and pg.Main.Center.FishPond:FindFirstChild("Main")
        and pg.Main.Center.FishPond.Main:FindFirstChild("fishStorage")
        and pg.Main.Center.FishPond.Main.fishStorage:FindFirstChild("List")
    if not pondList then
        return {}
    end
    local ids = {}
    for _, inst in ipairs(pondList:GetChildren()) do
        if isId(inst.Name) then
            ids[#ids + 1] = inst.Name
        end
    end
    return ids
end

local function depositBest()
    local ids = getSortedFishIdsByValue()
    if #ids == 0 then return end
    for i = 1, #ids do
        local args = { { ids[i] } }
        DepositRF:InvokeServer(unpack(args))
    end
end

local function withdrawAll()
    local pondIds = getPondFishIds()
    if #pondIds == 0 then return end
    for i = 1, #pondIds do
        local args = { pondIds[i] }
        WithdrawRF:InvokeServer(unpack(args))
    end
end

return {
    setInventory = setInventory,
    setValueCalculator = setValueCalculator,
    depositBest = depositBest,
    withdrawAll = withdrawAll,
}
