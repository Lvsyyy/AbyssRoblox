local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local S = RS.common.packages.Knit.Services
local DeleteRF = S.InventoryService.RF.DeleteArtifact

local artifactsScroll = pg.Main.TopLeft.Menus.Inventory.Frame.Scroll_Artifacts.Scroll

local CFG = {
	Weight = { need = "Weight", prio = {"Weight", "Cooldown", "Damage", "Oxygen", "Speed", "Cash", "XP"} },
	Damage = { need = "Damage", prio = {"Damage", "Cooldown", "Weight", "Speed", "Oxygen", "Cash", "XP"} },
	Speed  = { need = "Speed",  prio = {"Speed", "Damage", "Cooldown", "Oxygen", "Weight", "Cash", "XP"} },
	Cash   = { need = "Cash",   prio = {"Cash", "Weight", "Damage", "Speed", "Cooldown", "Oxygen", "XP"} },
	XP     = { need = "XP",     prio = {"XP", "Damage", "Weight", "Speed", "Cooldown", "Oxygen", "Cash"} },
	Cooldown = { need = "Cooldown", prio = {"Cooldown", "Damage", "Speed", "Oxygen", "Weight", "Cash", "XP"} },
}

for _, cfg in pairs(CFG) do
	cfg.prio.n = #cfg.prio
end

local function statNumRaw(stats, name)
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

local function statNumCached(stats, name, cache)
	local byName = cache[stats]
	if not byName then
		byName = {}
		cache[stats] = byName
	end

	local cached = byName[name]
	if cached ~= nil then
		return cached == false and nil or cached
	end

	local n = statNumRaw(stats, name)
	byName[name] = n == nil and false or n
	return n
end

local function betterPair(aId, aStats, bId, bStats, prio, cache)
	for i = 1, prio.n or #prio do
		local stat = prio[i]
		local av = statNumCached(aStats, stat, cache)
		local bv = statNumCached(bStats, stat, cache)

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

local function pickTop3(key, rows, cache)
	local cfg = CFG[key]
	local prio = cfg.prio
	local needStat = cfg.need

	local bestId, bestStats
	local secondId, secondStats
	local thirdId, thirdStats

	for i = 1, #rows do
		local row = rows[i]
		local stats = row.stats
		local id = row.id
		if statNumCached(stats, needStat, cache) ~= nil then
			if not bestStats or betterPair(id, stats, bestId, bestStats, prio, cache) then
				thirdId, thirdStats = secondId, secondStats
				secondId, secondStats = bestId, bestStats
				bestId, bestStats = id, stats
			elseif not secondStats or betterPair(id, stats, secondId, secondStats, prio, cache) then
				thirdId, thirdStats = secondId, secondStats
				secondId, secondStats = id, stats
			elseif not thirdStats or betterPair(id, stats, thirdId, thirdStats, prio, cache) then
				thirdId, thirdStats = id, stats
			end
		end
	end

	return bestId, secondId, thirdId
end

local function isProtectedRarity(rarity)
	return rarity == "Mythical" or rarity == "Event" or rarity == "Secret"
end

local function deleteBadArtifacts()
	local rows = {}
	local kids = artifactsScroll:GetChildren()
	for i = 1, #kids do
		local a = kids[i]
		if a.ClassName == "Frame" then
			local main = a:FindFirstChild("Main")
			local stats = main and main:FindFirstChild("Stats")
			if stats then
				local rarity = main:FindFirstChild("Rarity")
				rows[#rows + 1] = {
					frame = a,
					id = a.Name,
					stats = stats,
					rarity = rarity and rarity.Text or nil,
				}
			end
		end
	end

	local statCache = {}
	local keep = {}

	for key in pairs(CFG) do
		local a, b, c = pickTop3(key, rows, statCache)
		if a then keep[a] = true end
		if b then keep[b] = true end
		if c then keep[c] = true end
	end

	for i = 1, #rows do
		local row = rows[i]
		if not keep[row.id] and not isProtectedRarity(row.rarity) then
			DeleteRF:InvokeServer(row.id)
			row.frame:Destroy()
		end
	end
end

return {
	deleteBadArtifacts = deleteBadArtifacts,
}
