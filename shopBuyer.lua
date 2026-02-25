local RS = game:GetService("ReplicatedStorage")

local Buy = RS.common.packages.Knit.Services.MerchantService.RF.Buy
local T = workspace.Game.Merchants.Jeff.Folder.Table

local itemsSet = {}
local itemsList = {}

local enabled = false
local running = false
local stopFlag = false

local function normalize(s)
	return s:lower()
end

local function setItems(list)
	table.clear(itemsSet)
	table.clear(itemsList)
	for i = 1, #list do
		local name = list[i]
		if name ~= "" then
			local key = normalize(name)
			if not itemsSet[key] then
				itemsSet[key] = true
				itemsList[#itemsList + 1] = name
			end
		end
	end
end

local function addItem(name)
	if name ~= "" then
		local key = normalize(name)
		if not itemsSet[key] then
			itemsSet[key] = true
			itemsList[#itemsList + 1] = name
			return true
		end
	end
	return false
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

local function tickBuy()
	for id = 1, 2 do
		local n = T[id].Item.SurfaceGui.Label.Text:lower()
		for key in pairs(itemsSet) do
			if n:find(key, 1, true) then
				Buy:InvokeServer("Jeff", id, 1)
				break
			end
		end
	end
end

local function startLoop()
	if running then return end
	running = true
	stopFlag = false
	task.spawn(function()
		while not stopFlag do
			if enabled then
				pcall(tickBuy)
			end
			task.wait(10)
		end
		running = false
	end)
end

local function setEnabled(v)
	enabled = v == true
	if enabled then
		startLoop()
	end
end

local function getEnabled()
	return enabled
end

return {
	setItems = setItems,
	addItem = addItem,
	clearItems = clearItems,
	getItems = getItems,
	setEnabled = setEnabled,
	getEnabled = getEnabled,
}
