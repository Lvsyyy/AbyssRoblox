local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local artifactsScroll = pg.Main.TopLeft.Menus.Inventory.Frame.Scroll_Artifacts.Scroll

local CFG = {
	Weight = { need = "Weight", prio = {"Weight", "Cooldown", "Oxygen", "Speed", "Damage", "Cash", "XP"} },
	Damage = { need = "Damage", prio = {"Damage", "Cooldown", "Speed", "Oxygen", "Weight", "Cash", "XP"} },
	Speed  = { need = "Speed",  prio = {"Speed", "Damage", "Cooldown", "Oxygen", "Weight", "Cash", "XP"} },
	Cash   = { need = "Cash",   prio = {"Cash", "Weight", "Damage", "Speed", "Cooldown", "Oxygen", "XP"} },
	XP     = { need = "XP",     prio = {"XP", "Cash", "Weight", "Damage", "Speed", "Cooldown", "Oxygen"} },
	Cooldown = { need = "Cooldown", prio = {"Cooldown", "Damage", "Speed", "Oxygen", "Weight", "Cash", "XP"} },
}

for _, cfg in pairs(CFG) do
	cfg.prio.n = #cfg.prio
end

local function statNum(stats, name)
	local v = stats:FindFirstChild(name)
	if v == nil and name == "XP" then
		v = stats:FindFirstChild("Xp") or stats:FindFirstChild("EXP") or stats:FindFirstChild("Exp")
	end
	if v ~= nil then
		local s = v.Value.Text
		if s:find("âˆ’", 1, true) then s = s:gsub("âˆ’", "-") end
		if s:find(",", 1, true) then s = s:gsub(",", ".") end
		return tonumber(s:match("[+-]?%d*%.?%d+"))
	end
end

local function betterPair(aId, aStats, bId, bStats, prio)
	for i = 1, prio.n or #prio do
		local stat = prio[i]
		local av = statNum(aStats, stat)
		local bv = statNum(bStats, stat)

		if av ~= bv then
			if av == nil then return false end
			if bv == nil then return true end
			if stat == "Cooldown" then
				return av < bv
			else
				return av > bv
			end
		end
	end
	return aId < bId
end

local function pickTop3(key)
	local cfg = CFG[key]
	local prio = cfg.prio
	local needStat = cfg.need

	local bestId, bestStats
	local secondId, secondStats
	local thirdId, thirdStats

	local kids = artifactsScroll:GetChildren()
	for i = 1, #kids do
		local a = kids[i]
		if a.ClassName == "Frame" then
			local stats = a.Main.Stats
			local id = a.Name
			if statNum(stats, needStat) ~= nil then
				if not bestStats or betterPair(id, stats, bestId, bestStats, prio) then
					thirdId, thirdStats = secondId, secondStats
					secondId, secondStats = bestId, bestStats
					bestId, bestStats = id, stats
				elseif not secondStats or betterPair(id, stats, secondId, secondStats, prio) then
					thirdId, thirdStats = secondId, secondStats
					secondId, secondStats = id, stats
				elseif not thirdStats or betterPair(id, stats, thirdId, thirdStats, prio) then
					thirdId, thirdStats = id, stats
				end
			end
		end
	end

	return bestId, secondId, thirdId
end

local function getRarityText(artifactFrame)
	local main = artifactFrame:FindFirstChild("Main")
	local rarity = main and main:FindFirstChild("Rarity")
	return rarity and rarity.Text or "Unknown"
end

local function isProtectedRarity(rarity)
	return rarity == "Mythical" or rarity == "Event" or rarity == "Secret"
end

local function getStatLines(stats)
	local lines = {}
	for _, child in ipairs(stats:GetChildren()) do
		if child.ClassName == "Frame" then
			local name = child:FindFirstChild("Name")
			local value = child:FindFirstChild("Value")
			if name and value and name.ClassName == "TextLabel" and value.ClassName == "TextLabel" then
				lines[#lines + 1] = name.Text .. ": " .. value.Text
			end
		end
	end
	table.sort(lines)
	return lines
end

local keep = {}
for key in pairs(CFG) do
	local a, b, c = pickTop3(key)
	if a then keep[a] = true end
	if b then keep[b] = true end
	if c then keep[c] = true end
end

print("=== TOP 3 PER CATEGORY ===")
for key in pairs(CFG) do
	local a, b, c = pickTop3(key)
	print(key .. ":", a or "nil", b or "nil", c or "nil")
end

print("=== DELETE CANDIDATES (NOT PROTECTED) ===")
local kids = artifactsScroll:GetChildren()
for i = 1, #kids do
	local a = kids[i]
	if a.ClassName == "Frame" then
		local id = a.Name
		local rarity = getRarityText(a)
		if not keep[id] and not isProtectedRarity(rarity) then
			local title = a.Main.Title and a.Main.Title.Text or "(no title)"
			print(title .. " [" .. id .. "] - " .. rarity)
			local stats = a.Main.Stats
			local lines = getStatLines(stats)
			for j = 1, #lines do
				print("  " .. lines[j])
			end
		end
	end
end

print("Done")
