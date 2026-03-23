-- Adds value line to fish labels in backpack + hotbar.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local FishBaseValue = {}
local MutationPriceMultiplier = {}
local mutationCache = {}
local mutationsFolder = RS:WaitForChild("common")
	:WaitForChild("presets")
	:WaitForChild("fish")
	:WaitForChild("mutations")
local StarMultiplier = {
	[1] = 0.5,
	[2] = 0.75,
	[3] = 1,
}

local function stripTags(text)
	if type(text) ~= "string" then
		return ""
	end
	local cleaned = text:gsub("<[^>]->", "")
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
	cleaned = cleaned:gsub("%s+", " ")
	return cleaned
end

local function extractTagText(text)
	if type(text) ~= "string" then
		return ""
	end
	local out = {}
	for inner in text:gmatch("<[^>]->%s*([^<]-)%s*</") do
		if inner and inner ~= "" then
			out[#out + 1] = inner
		end
	end
	local s = table.concat(out, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

local function parseMutationAndFish(text, mutationMap)
	local cleaned = stripTags(text)
	if cleaned == "" then
		return nil, nil
	end

	-- Prefer tagged mutation if present
	local tagText = extractTagText(text)
	if tagText ~= "" and cleaned:sub(1, #tagText + 1) == tagText .. " " then
		local mutation = tagText
		local fish = cleaned:sub(#tagText + 2)
		return mutation, fish
	end

	-- Fallback: detect mutation prefix even without tags
	if type(mutationMap) == "table" then
		local lower = cleaned:lower()
		for name in pairs(mutationMap) do
			local n = name:lower()
			if lower:sub(1, #n + 1) == n .. " " then
				local fish = cleaned:sub(#name + 2)
				return name, fish
			end
		end
	end

	return nil, cleaned
end

local function getBaseText(label)
	local base = label:GetAttribute("AbyssBaseText")
	if type(base) == "string" and base ~= "" then
		return base
	end
	local text = label.Text or ""
	local firstLine = text:match("([^\n\r]+)") or text
	label:SetAttribute("AbyssBaseText", firstLine)
	return firstLine
end

local function resolveMutationMultiplier(name)
	if not name or name == "" then
		return 1
	end
	if mutationCache[name] then
		return mutationCache[name]
	end
	if MutationPriceMultiplier[name] then
		mutationCache[name] = MutationPriceMultiplier[name]
		return mutationCache[name]
	end
	-- try to load mutation module by name (case-insensitive)
	local target = name:lower()
	local mod = mutationsFolder:FindFirstChild(name) or nil
	if not mod then
		for _, child in ipairs(mutationsFolder:GetChildren()) do
			if child:IsA("ModuleScript") and child.Name:lower() == target then
				mod = child
				break
			end
		end
	end
	if mod and mod:IsA("ModuleScript") then
		local ok, data = pcall(require, mod)
		if ok and type(data) == "table" and data.price_multiplier then
			mutationCache[name] = data.price_multiplier
			return mutationCache[name]
		end
	end
	return 1
end

local function computeValue(frame, baseText)
	local fishName = frame:GetAttribute("name")
	local full = frame:GetAttribute("fullname")
	local mutation, parsedFish = parseMutationAndFish(type(full) == "string" and full or baseText, MutationPriceMultiplier)
	local fish = fishName or parsedFish
	if type(fish) ~= "string" or fish == "" then
		return nil
	end

	local base = FishBaseValue[fish]
	if not base then
		return nil
	end

	local weight = tonumber(frame:GetAttribute("weight")) or 1
	local mult = resolveMutationMultiplier(mutation)
	local stars = tonumber(frame:GetAttribute("stars")) or 3
	local starMult = StarMultiplier[stars] or 1
	local value = base * weight * mult * starMult
	if not value then
		return nil
	end
	return math.floor(value + 0.5)
end

local function formatValueLine(value)
	return "\n<font color='#7FFF9B'>$" .. tostring(value) .. "</font>"
end

local function hookFishFrame(frame)
	if frame:GetAttribute("class") ~= "fish" then
		return
	end

	local label = frame:FindFirstChild("Btn")
		and frame.Btn:FindFirstChild("Frame")
		and frame.Btn.Frame:FindFirstChild("Item")
	if not (label and label:IsA("TextLabel")) then
		return
	end

	label.RichText = true
	local updating = false

	local function apply()
		if updating then return end
		updating = true
		local baseText = getBaseText(label)
		local val = computeValue(frame, baseText)
		if val then
			label.Text = baseText .. formatValueLine(val)
		else
			label.Text = baseText
		end
		updating = false
	end

	frame:GetAttributeChangedSignal("weight"):Connect(apply)
	frame:GetAttributeChangedSignal("fullname"):Connect(apply)
	frame:GetAttributeChangedSignal("name"):Connect(apply)
	frame:GetAttributeChangedSignal("class"):Connect(apply)
	label:GetPropertyChangedSignal("Text"):Connect(function()
		if updating then return end
		label:SetAttribute("AbyssBaseText", nil)
		apply()
	end)

	apply()
end

local function scanContainer(container)
	if not container then return end
	for _, inst in ipairs(container:GetChildren()) do
		if inst:IsA("Frame") then
			hookFishFrame(inst)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Frame") then
			hookFishFrame(child)
		end
	end)
end

local function resolveData(data)
	if type(data) == "table" then
		if data.FishBaseValue or data.MutationPriceMultiplier then
			return data
		end
	end
	-- Fallback: fetch scan module from repo if available
	local ok, mod = pcall(function()
		local src = game:HttpGet("https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_FishValueScan.lua")
		local chunk = loadstring(src)
		return chunk and chunk() or nil
	end)
	if ok and type(mod) == "table" and type(mod.get) == "function" then
		local okGet, res = pcall(mod.get)
		if okGet and type(res) == "table" then
			return res
		end
	end
	return nil
end

local function init(data)
	local resolved = resolveData(data)
	if type(resolved) == "table" then
		FishBaseValue = resolved.FishBaseValue or {}
		MutationPriceMultiplier = resolved.MutationPriceMultiplier or {}
	end
	local main = pg:WaitForChild("Main")
	local backpack = main:WaitForChild("Backpack")
	local list = backpack.List.CanvasGroup.ScrollingFrame
	local hotbar = backpack.Hotbar
	scanContainer(list)
	scanContainer(hotbar)
end

return {
	init = init,
}
