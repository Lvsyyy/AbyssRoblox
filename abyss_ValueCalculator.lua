local RS = game:GetService("ReplicatedStorage")

local cached = nil

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

local function scanMutations()
    local out = {}
    local root = RS:WaitForChild("common")
        :WaitForChild("presets")
        :WaitForChild("fish")
        :WaitForChild("mutations")
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            local src = getSource(inst)
            local mult = extractNumber(src, "price_multiplier")
            if mult then
                out[inst.Name] = mult
            end
        end
    end
    return out
end

local function scanFishBaseValues()
    local out = {}
    local root = RS:WaitForChild("common")
        :WaitForChild("presets")
        :WaitForChild("items")
        :WaitForChild("fish")
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            local src = getSource(inst)
            local base = extractNumber(src, "basevalue") or extractNumber(src, "base_value")
            if base then
                out[inst.Name] = base
            end
        end
    end
    return out
end

local function getTables()
    if cached then
        return cached
    end
    cached = {
        FishBaseValue = scanFishBaseValues(),
        MutationPriceMultiplier = scanMutations(),
    }
    return cached
end

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

    local tagText = extractTagText(text)
    if tagText ~= "" and cleaned:sub(1, #tagText + 1) == tagText .. " " then
        local mutation = tagText
        local fish = cleaned:sub(#tagText + 2)
        return mutation, fish
    end

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

local StarMultiplier = {
    [1] = 0.5,
    [2] = 0.75,
    [3] = 1,
}

local function computeValue(info, baseText)
    if type(info) ~= "table" then
        return nil
    end
    local tables = getTables()
    local fishName = info.name
    local full = info.fullname
    local mutation, parsedFish = parseMutationAndFish(type(full) == "string" and full or baseText or "", tables.MutationPriceMultiplier)
    local fish = fishName or parsedFish
    if type(fish) ~= "string" or fish == "" then
        return nil
    end
    local base = tables.FishBaseValue[fish]
    if not base then
        return nil
    end
    local weight = tonumber(info.weight) or 1
    local stars = tonumber(info.stars) or 3
    local starMult = StarMultiplier[stars] or 1
    local mutMult = tables.MutationPriceMultiplier[mutation] or 1
    local value = base * weight * mutMult * starMult
    if not value then
        return nil
    end
    return math.floor(value + 0.5)
end

return {
    getTables = getTables,
    parseMutationAndFish = parseMutationAndFish,
    computeValue = computeValue,
}
