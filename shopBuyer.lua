local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

local BuyRF = RS.common.packages.Knit.Services.MerchantService.RF.Buy
local MerchantsRoot = WS.Game.Merchants
local OtherAssets = RS.common.assets.other

local itemsSet = {}
local itemsList = {}
local availableItems = {}

local enabled = false
local started = false
local connections = {}

local function normalize(s)
	return string.lower(s)
end

local function buildAvailableItems()
	table.clear(availableItems)
	local kids = OtherAssets:GetChildren()
	for i = 1, #kids do
		local inst = kids[i]
		if inst:IsA("Model") then
			local name = inst.Name
			local lower = string.lower(name)
			if lower:find("shard", 1, true)
				or lower:find("pod", 1, true)
				or lower:find("potion", 1, true)
			then
				availableItems[#availableItems + 1] = name
			end
		end
	end
	table.sort(availableItems)
end

local function isStocked(merchant)
	local label = merchant:FindFirstChild("Folder")
		and merchant.Folder:FindFirstChild("Sign")
		and merchant.Folder.Sign:FindFirstChild("Time")
		and merchant.Folder.Sign.Time:FindFirstChild("SurfaceGui")
		and merchant.Folder.Sign.Time.SurfaceGui:FindFirstChild("Label")

	return label and label:IsA("TextLabel") and label.Text == "00:00"
end

local function tryBuyFromMerchant(merchant)
	if not enabled then return end
	if not merchant or merchant.Name == "Bob" then return end

	local tableRoot = merchant:FindFirstChild("Folder")
		and merchant.Folder:FindFirstChild("Table")
	if not tableRoot then return end

	local slots = tableRoot:GetChildren()
	for i = 1, #slots do
		local slot = slots[i]
		local id = tonumber(slot.Name)
		if id then
			local label = slot:FindFirstChild("Item")
				and slot.Item:FindFirstChild("SurfaceGui")
				and slot.Item.SurfaceGui:FindFirstChild("Label")

			if label and label:IsA("TextLabel") then
				local text = normalize(label.Text or "")
				for key in pairs(itemsSet) do
					if text:find(key, 1, true) then
						pcall(function()
							BuyRF:InvokeServer(merchant.Name, id, 1)
						end)
						break
					end
				end
			end
		end
	end
end

local function scanStockedMerchants()
	local merchants = MerchantsRoot:GetChildren()
	for i = 1, #merchants do
		local merchant = merchants[i]
		if merchant:IsA("Model") and merchant.Name ~= "Bob" and isStocked(merchant) then
			task.delay(1, function()
				tryBuyFromMerchant(merchant)
			end)
		end
	end
end

local function watchMerchant(merchant)
	if not merchant:IsA("Model") or merchant.Name == "Bob" then return end

	local label = merchant:FindFirstChild("Folder")
		and merchant.Folder:FindFirstChild("Sign")
		and merchant.Folder.Sign:FindFirstChild("Time")
		and merchant.Folder.Sign.Time:FindFirstChild("SurfaceGui")
		and merchant.Folder.Sign.Time.SurfaceGui:FindFirstChild("Label")

	if not (label and label:IsA("TextLabel")) then return end

	local lastText = label.Text
	local conn = label:GetPropertyChangedSignal("Text"):Connect(function()
		local newText = label.Text
		if newText == "00:00" and lastText ~= "00:00" then
			task.delay(1, function()
				tryBuyFromMerchant(merchant)
			end)
		end
		lastText = newText
	end)
	connections[#connections + 1] = conn
end

local function startWatching()
	if started then return end
	started = true

	local merchants = MerchantsRoot:GetChildren()
	for i = 1, #merchants do
		watchMerchant(merchants[i])
	end

	local addConn = MerchantsRoot.ChildAdded:Connect(function(child)
		watchMerchant(child)
		if enabled and child:IsA("Model") and child.Name ~= "Bob" and isStocked(child) then
			task.delay(1, function()
				tryBuyFromMerchant(child)
			end)
		end
	end)
	connections[#connections + 1] = addConn
end

local function setItems(list)
	table.clear(itemsSet)
	table.clear(itemsList)
	for i = 1, #list do
		local name = list[i]
		if type(name) == "string" and name ~= "" then
			local key = normalize(name)
			if not itemsSet[key] then
				itemsSet[key] = true
				itemsList[#itemsList + 1] = name
			end
		end
	end
end

local function addItem(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	local key = normalize(name)
	if itemsSet[key] then
		return false
	end
	itemsSet[key] = true
	itemsList[#itemsList + 1] = name
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
	return true
end

local function clearItems()
	table.clear(itemsSet)
	table.clear(itemsList)
end

local function getItems()
	local out = table.create(#itemsList)
	for i = 1, #itemsList do out[i] = itemsList[i] end
	return out
end

local function getAvailableItems()
	local out = table.create(#availableItems)
	for i = 1, #availableItems do out[i] = availableItems[i] end
	return out
end

local function setEnabled(v)
	enabled = v == true
	startWatching()
	if enabled then
		scanStockedMerchants()
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
