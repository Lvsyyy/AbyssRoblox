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

local function isCoconutGeodeRow(inst)
	local class = string.lower(tostring(inst:GetAttribute("class") or ""))
	local name = string.lower(tostring(inst:GetAttribute("name") or ""))
	local full = string.lower(tostring(inst:GetAttribute("fullname") or ""))

	if class ~= "geodes" then
		return false
	end
	if name == "coconut" then
		return true
	end
	return full == "coconut geode" or (full:find("coconut", 1, true) and full:find("geode", 1, true))
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

local function getCoconutGeodeCount()
	local main = pg:FindFirstChild("Main")
	if not main then return 0 end
	local backpackGui = main:FindFirstChild("Backpack")
	if not backpackGui then return 0 end

	local list = backpackGui:FindFirstChild("List")
		and backpackGui.List:FindFirstChild("CanvasGroup")
		and backpackGui.List.CanvasGroup:FindFirstChild("ScrollingFrame")
	local hotbar = backpackGui:FindFirstChild("Hotbar")
	local seenIds = {}
	local total = 0

	local function scan(container)
		if not container then return end
		local kids = container:GetChildren()
		for i = 1, #kids do
			local inst = kids[i]
			if inst.ClassName == "Frame" then
				local id = getItemId(inst)
				if id and seenIds[id] then
				else
					if isCoconutGeodeRow(inst) then
						total += getRowAmount(inst)
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
	return total
end

local enabled = false
local watching = false

local function openGeode()
	if #artifactFolder:GetChildren() > 0 then
		return
	end

	local count = getCoconutGeodeCount()
	if count > 0 then
		openRF:InvokeServer("Coconut", math.min(99, count))
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

return {
	openGeode = openGeode,
	setEnabled = setEnabled,
	getEnabled = getEnabled,
}
