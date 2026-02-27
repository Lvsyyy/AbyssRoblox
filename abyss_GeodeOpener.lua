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

local function getItemName(inst)
	local name = inst:GetAttribute("name") or inst:GetAttribute("Name")
	if type(name) == "string" and name ~= "" then
		return name
	end

	local main = inst:FindFirstChild("Main")
	if main then
		local label = main:FindFirstChild("Name") or main:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			return label.Text
		end
	end

	local directLabel = inst:FindFirstChild("Name") or inst:FindFirstChild("Label")
	if directLabel and directLabel:IsA("TextLabel") then
		return directLabel.Text
	end

	return nil
end

local function getItemId(inst)
	local id = inst:GetAttribute("id") or inst:GetAttribute("Id")
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

local function isCoconutGeodeName(name)
	local n = string.lower(name)
	if n:find("coconut", 1, true) and n:find("geode", 1, true) then
		return true
	end
	return n == "coconut"
end

local function hasCoconutGeode()
	local main = pg:FindFirstChild("Main")
	if not main then return false end
	local backpackGui = main:FindFirstChild("Backpack")
	if not backpackGui then return false end

	local list = backpackGui:FindFirstChild("List")
		and backpackGui.List:FindFirstChild("CanvasGroup")
		and backpackGui.List.CanvasGroup:FindFirstChild("ScrollingFrame")

	local hotbar = backpackGui:FindFirstChild("Hotbar")
	local seenIds = {}

	local function scan(container)
		if not container then return false end
		local kids = container:GetChildren()
		for i = 1, #kids do
			local inst = kids[i]
			if inst.ClassName == "Frame" then
				local id = getItemId(inst)
				if id and seenIds[id] then
					-- skip duplicate from hotbar/backpack
				else
					local name = getItemName(inst)
					if type(name) == "string" and name ~= "" and isCoconutGeodeName(name) then
						return true
					end
					if id then
						seenIds[id] = true
					end
				end
			end
		end
		return false
	end

	if scan(list) then return true end
	if scan(hotbar) then return true end
	return false
end

local enabled = false
local watching = false

local function openGeode()
	if #artifactFolder:GetChildren() > 0 then
		return
	end

	if hasCoconutGeode() then
		openRF:InvokeServer("Coconut", 99)
	else
		openRF:InvokeServer("Rooted", 99)
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

	artifactFolder.ChildAdded:Connect(function()
		-- no-op; remove event drives the next open attempt
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
