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

local function equipTop3(key)
	local bestId, secondId, thirdId = pickTop3(key)

	UnequipRF:InvokeServer(1)
	UnequipRF:InvokeServer(2)
	UnequipRF:InvokeServer(3)

	if bestId then EquipRF:InvokeServer(bestId, 1) end
	if secondId then EquipRF:InvokeServer(secondId, 2) end
	if thirdId then EquipRF:InvokeServer(thirdId, 3) end
end

local function updateAllSets()
	local order = {
		{ slot = 1, key = "Weight" },
		{ slot = 2, key = "Damage" },
		{ slot = 3, key = "Speed" },
		{ slot = 4, key = "Cash" },
		{ slot = 5, key = "XP" },
	}

	for i = 1, #order do
		local entry = order[i]
		EquipLoadoutRF:InvokeServer(entry.slot)
		equipTop3(entry.key)
	end
end

return {
	updateAllSets = updateAllSets,
}
