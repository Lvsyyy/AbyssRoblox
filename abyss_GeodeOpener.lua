local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local openRF = RS:WaitForChild("common")
	:WaitForChild("packages")
	:WaitForChild("Knit")
	:WaitForChild("Services")
	:WaitForChild("ArtifactsService")
	:WaitForChild("RF")
	:WaitForChild("Open")

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

local function getItemCount(inst)
	local count = inst:GetAttribute("count")
		or inst:GetAttribute("Count")
		or inst:GetAttribute("amount")
		or inst:GetAttribute("Amount")
		or inst:GetAttribute("quantity")
		or inst:GetAttribute("Quantity")
		or inst:GetAttribute("qty")
		or inst:GetAttribute("Qty")
		or inst:GetAttribute("stack")
		or inst:GetAttribute("Stack")

	if type(count) == "number" and count > 0 then
		return count
	end
	return 1
end

local function isCoconutGeodeName(name)
	local n = name:lower()
	if n:find("coconut", 1, true) and n:find("geode", 1, true) then
		return true
	end
	return n == "coconut"
end

local function countCoconutGeodes()
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

	local function scan(container, skipIfSeen)
		if not container then return end
		local kids = container:GetChildren()
		for i = 1, #kids do
			local inst = kids[i]
			if inst.ClassName == "Frame" then
				local id = getItemId(inst)
				if id and seenIds[id] then
					-- already counted from backpack
				else
					local name = getItemName(inst)
					if type(name) == "string" and name ~= "" and isCoconutGeodeName(name) then
						total = total + getItemCount(inst)
					end
					if id then
						seenIds[id] = true
					elseif skipIfSeen then
						-- hotbar entries without id might duplicate backpack entries
					end
				end
			end
		end
	end

	scan(list, false)
	scan(hotbar, true)

	return total
end

local function openGeode()
	local coconutCount = countCoconutGeodes()
	if coconutCount > 0 then
		local amt = math.min(coconutCount, 99)
		if amt > 0 then
			openRF:InvokeServer("Coconut", amt)
		end
	else
		openRF:InvokeServer("Rooted", 99)
	end
end

return {
	openGeode = openGeode,
}
