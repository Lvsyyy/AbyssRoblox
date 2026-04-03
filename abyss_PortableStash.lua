local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local sort = table.sort

local S = RS.common.packages.Knit.Services
local StorageRF = S.StorageService.RF

local DepositRF, WithdrawRF = StorageRF.Deposit, StorageRF.Withdraw

local Main
local storageRoot

local _ids, _ws, _ord = table.create(256), table.create(256), table.create(256)
local _lastW, _lastD = 0, 0
local _tmp = table.create(256)
local _lastTmp = 0
local _seen = {}
local _seenKeys = table.create(256)
local _seenCount = 0

local inventoryList = {}

local initialized = false

local g = (getgenv and getgenv()) or _G
local Framework = g and g.__abyss_framework
local isFishId = (Framework and Framework.isHexId32) or function(v)
    return type(v) == "string" and #v == 32 and v:match("^[a-f0-9]+$") ~= nil
end

local function withdrawAll()
    local kids = storageRoot:GetChildren()
    local n = 0
    for i = 1, #kids do
        local inst = kids[i]
        if inst.ClassName == "Frame" and inst.Name ~= "Placeholder" then
            n += 1
            _ids[n] = inst.Name
        end
    end
    for i = n + 1, _lastW do _ids[i] = nil end
    _lastW = n
    if n > 0 then WithdrawRF:InvokeServer(_ids) end
end

local function depositFishByWeightDesc()
    local n = 0

    for _, item in ipairs(inventoryList) do
        local id = item.id
        local w = item.weight
        local cls = item.class
        if isFishId(id) and (cls == "fish" or type(w) == "number") then
            if not _seen[id] then
                n += 1
                _ids[n], _ws[n] = id, w or 0
                _seen[id] = true
                _seenCount += 1
                _seenKeys[_seenCount] = id
            end
        end
    end

    for i = 1, _seenCount do
        local id = _seenKeys[i]
        _seen[id] = nil
        _seenKeys[i] = nil
    end
    _seenCount = 0

    for i = n + 1, _lastD do
        _ids[i], _ws[i], _ord[i] = nil, nil, nil
    end
    _lastD = n
    if n == 0 then return end

    for i = 1, n do _ord[i] = i end
    sort(_ord, function(a, b) return (_ws[a] or 0) > (_ws[b] or 0) end)

    for i = 1, n do _tmp[i] = _ids[_ord[i]] end
    for i = 1, n do _ids[i] = _tmp[i] end
    for i = n + 1, _lastTmp do _tmp[i] = nil end
    _lastTmp = n

    DepositRF:InvokeServer(_ids)
end

local function onInventoryChanged(list)
    inventoryList = type(list) == "table" and list or {}
end
local function init()
    if initialized then return end
    initialized = true

    Main = pg.Main
    storageRoot = Main.Center.Storage.CanvasGroup.Storage
end

return {
    init = init,
    depositFishByWeightDesc = depositFishByWeightDesc,
    withdrawAll = withdrawAll,
    onInventoryChanged = onInventoryChanged,
}
