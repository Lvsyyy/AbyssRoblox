local RS = game:GetService("ReplicatedStorage")

local function getSource(mod)
	if type(decompile) == "function" then
		local ok, src = pcall(decompile, mod, nil, 5)
		if ok and type(src) == "string" and src ~= "" then
			return src
		end
	end
	local ok, src = pcall(function()
		return mod.Source
	end)
	if ok and type(src) == "string" and src ~= "" then
		return src
	end
	return nil
end

local function extractNumber(src, key)
	if type(src) ~= "string" then
		return nil
	end
	local pat1 = key .. "%s*=%s*([%d%.]+)"
	local pat2 = "%[\"" .. key .. "\"%]%s*=%s*([%d%.]+)"
	local pat3 = "%['" .. key .. "'%]%s*=%s*([%d%.]+)"
	local num = src:match(pat1) or src:match(pat2) or src:match(pat3)
	if num then
		return tonumber(num)
	end
	return nil
end

local function normalizeMutationName(root, mod)
	if mod.Parent and mod.Parent ~= root and mod.Parent.Name == "Mushroom" then
		return mod.Name
	end
	return mod.Name
end

local function scanMutations()
	local out = {}
	local mutationsRoot = RS:WaitForChild("common")
		:WaitForChild("presets")
		:WaitForChild("fish")
		:WaitForChild("mutations")

	local mods = {}
	for _, inst in ipairs(mutationsRoot:GetDescendants()) do
		if inst:IsA("ModuleScript") then
			mods[#mods + 1] = inst
		end
	end
	table.sort(mods, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	for _, mod in ipairs(mods) do
		local src = getSource(mod)
		local mult = extractNumber(src, "price_multiplier")
		if mult then
			local name = normalizeMutationName(mutationsRoot, mod)
			out[name] = mult
		end
	end
	return out
end

local function scanFishBaseValues()
	local out = {}
	local fishRoot = RS:WaitForChild("common")
		:WaitForChild("presets")
		:WaitForChild("items")
		:WaitForChild("fish")

	local mods = {}
	for _, inst in ipairs(fishRoot:GetDescendants()) do
		if inst:IsA("ModuleScript") then
			mods[#mods + 1] = inst
		end
	end
	table.sort(mods, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	for _, mod in ipairs(mods) do
		local src = getSource(mod)
		local base = extractNumber(src, "basevalue") or extractNumber(src, "base_value")
		if base then
			out[mod.Name] = base
		end
	end
	return out
end

local cached = nil

local function scan()
	local data = {
		FishBaseValue = scanFishBaseValues(),
		MutationPriceMultiplier = scanMutations(),
	}
	cached = data
	return data
end

local function get()
	if cached then
		return cached
	end
	return scan()
end

return {
	get = get,
	scan = scan,
}
