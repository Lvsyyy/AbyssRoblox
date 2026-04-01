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

local function normalize(s)
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
	-- fallback: any label under slot
	return slot:FindFirstChildWhichIsA("TextLabel", true)
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

local function tryBuy(merchant, slotId, label)
	if not enabled or selectedCount == 0 then return end
	if not merchant or not slotId then return end
	local text = label and label.Text or ""
	if not shouldBuy(text) then return end

	local stateKey = merchant.Name .. ":" .. tostring(slotId)
	local now = os.clock()
	local last = slotState[stateKey] or 0
	if now - last < 0.75 then
		return
	end
	slotState[stateKey] = now

	pcall(function()
		BuyRF:InvokeServer(merchant.Name, slotId, 1)
	end)
end

local function watchSlot(merchant, slot)
	local id = tonumber(slot.Name)
	if not id then return end
	local label = getItemLabel(slot)
	if not label then return end

	local lastText = label.Text
	local conn = label:GetPropertyChangedSignal("Text"):Connect(function()
		local newText = label.Text
		if enabled and selectedCount > 0 and newText ~= lastText then
			tryBuy(merchant, id, label)
		end
		lastText = newText
	end)
	connections[#connections + 1] = conn

	if enabled then
		tryBuy(merchant, id, label)
	end
end

local function watchMerchant(merchant)
	if not (merchant and merchant:IsA("Model")) then return end
	local folder = merchant:FindFirstChild("Folder")
	local tableRoot = folder and folder:FindFirstChild("Table")
	if not tableRoot then return end

	for _, slot in ipairs(tableRoot:GetChildren()) do
		watchSlot(merchant, slot)
	end

	local conn = tableRoot.ChildAdded:Connect(function(slot)
		watchSlot(merchant, slot)
	end)
	connections[#connections + 1] = conn
end

local function scanAllMerchants()
	for _, merchant in ipairs(MerchantsRoot:GetChildren()) do
		watchMerchant(merchant)
	end
end

local function startWatching()
	if started then return end
	started = true

	scanAllMerchants()

	local addConn = MerchantsRoot.ChildAdded:Connect(function(child)
		watchMerchant(child)
	end)
	local removeConn = MerchantsRoot.ChildRemoved:Connect(function(child)
		slotState[child] = nil
	end)
	connections[#connections + 1] = addConn
	connections[#connections + 1] = removeConn
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

local function clearItems()
	table.clear(itemsSet)
	table.clear(itemsList)
	table.clear(itemKeys)
	selectedCount = 0
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
	startWatching()
	if enabled then
		scanAllMerchants()
	end
end

local function getEnabled()
	return enabled
end

buildAvailableItems()

return {
	setItems = setItems,
	addItem = addItem,
	removeItem = removeItem,
	clearItems = clearItems,
	getItems = getItems,
	getAvailableItems = getAvailableItems,
	setEnabled = setEnabled,
	getEnabled = getEnabled,
}
