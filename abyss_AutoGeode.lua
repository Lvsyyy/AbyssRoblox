local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

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

local function getItemId(inst)
	local id = inst:GetAttribute("id") or inst:GetAttribute("Id")
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
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

local function normalizeName(s)
	return string.lower(tostring(s or ""))
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

local function getSelectedGeodeKey(inst)
	local class = normalizeName(inst:GetAttribute("class"))
	if class ~= "geodes" then
		return nil
	end

	local name = normalizeName(inst:GetAttribute("name"))
	local full = normalizeName(inst:GetAttribute("fullname"))
	for key in pairs(nameSet) do
		if matchesGeodeName(name, key) or matchesGeodeName(full, key) then
			return key
		end
	end
	return nil
end

local function getRowAmount(inst)
	local attrAmount = toNum(inst:GetAttribute("amount"))
	if attrAmount and attrAmount > 0 then
		return math.floor(attrAmount)
	end

	local btn = inst:FindFirstChild("Btn")
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

local function getSelectedGeodeCounts()
	local main = pg:FindFirstChild("Main")
	if not main then return {} end
	local backpackGui = main:FindFirstChild("Backpack")
	if not backpackGui then return {} end

	local list = backpackGui:FindFirstChild("List")
		and backpackGui.List:FindFirstChild("CanvasGroup")
		and backpackGui.List.CanvasGroup:FindFirstChild("ScrollingFrame")
	local hotbar = backpackGui:FindFirstChild("Hotbar")
	local seenIds = {}
	local totals = {}
	for key in pairs(nameSet) do
		totals[key] = 0
	end

	local function scan(container)
		if not container then return end
		local kids = container:GetChildren()
		for i = 1, #kids do
			local inst = kids[i]
			if inst.ClassName == "Frame" then
				local id = getItemId(inst)
				if not (id and seenIds[id]) then
					local key = getSelectedGeodeKey(inst)
					if key then
						totals[key] = (totals[key] or 0) + getRowAmount(inst)
					end
					if id then
						seenIds[id] = true
					end
				end
			end
		end
	end

	scan(list)
	scan(hotbar)
	return totals
end

local enabled = false
local watching = false

local function openGeode()
	if #artifactFolder:GetChildren() > 0 then
		return
	end

	if #nameList == 0 then return end

	local counts = getSelectedGeodeCounts()
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

	artifactFolder.ChildRemoved:Connect(function()
		if #artifactFolder:GetChildren() == 0 then
			tryOpen()
		end
	end)
end

local function setEnabled(v)
	enabled = v == true
	if enabled then
		startWatching()
		tryOpen()
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

local function clearNames()
	table.clear(nameSet)
	table.clear(nameList)
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
	clearNames = clearNames,
	getNames = getNames,
}
