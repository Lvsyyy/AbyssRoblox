local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local S = RS.common.packages.Knit.Services
local InvRF = S.InventoryService.RF
local EquipRF = InvRF.EquipArtifact
local UnequipRF = InvRF.UnequipArtifact
local EquipLoadoutRF = InvRF.EquipArtifactsLoadout

local Main = pg.Main
local artifactsScroll = Main.TopLeft.Menus.Inventory.Frame.Scroll_Artifacts.Scroll

local CFG = {
	Weight = { need = "Weight", prio = {"Weight", "Cooldown", "Oxygen", "Speed", "Damage", "Cash", "XP"} },
	Damage = { need = "Damage", prio = {"Damage", "Cooldown", "Speed", "Oxygen", "Weight", "Cash", "XP"} },
	Speed  = { need = "Speed",  prio = {"Speed", "Damage", "Cooldown", "Oxygen", "Weight", "Cash", "XP"} },
	Cash   = { need = "Cash",   prio = {"Cash", "Weight", "Damage", "Speed", "Cooldown", "Oxygen", "XP"} },
	XP     = { need = "XP",     prio = {"XP", "Cash", "Weight", "Damage", "Speed", "Cooldown", "Oxygen"} },
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

local function updateAllSets()
	local rows = {}
	local kids = artifactsScroll:GetChildren()
	for i = 1, #kids do
		local a = kids[i]
		if a.ClassName == "Frame" then
			local main = a:FindFirstChild("Main")
			local stats = main and main:FindFirstChild("Stats")
			if stats then
				rows[#rows + 1] = {
					id = a.Name,
					stats = stats,
				}
			end
		end
	end

	local statCache = {}
	local order = {
		{ slot = 1, key = "Weight" },
		{ slot = 2, key = "Damage" },
		{ slot = 3, key = "Speed" },
		{ slot = 4, key = "Cash" },
		{ slot = 5, key = "XP" },
	}

	for i = 1, #order do
		local entry = order[i]
		local bestId, secondId, thirdId = pickTop3(entry.key, rows, statCache)
		EquipLoadoutRF:InvokeServer(entry.slot)
		UnequipRF:InvokeServer(1)
		UnequipRF:InvokeServer(2)
		UnequipRF:InvokeServer(3)

		if bestId then EquipRF:InvokeServer(bestId, 1) end
		if secondId then EquipRF:InvokeServer(secondId, 2) end
		if thirdId then EquipRF:InvokeServer(thirdId, 3) end
	end
end

return {
	updateAllSets = updateAllSets,
}
