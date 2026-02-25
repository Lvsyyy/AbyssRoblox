local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local S = RS.common.packages.Knit.Services
local DeleteRF = S.InventoryService.RF.DeleteArtifact

local artifactsScroll =
	pg.Main.TopLeft.Menus.Inventory.Frame.Scroll_Artifacts.Scroll

local ALLOWED = { Common = true, Uncommon = true, Rare = true, Epic = true }
local ROMAN_VAL = { I = 1, II = 2, III = 3, IV = 4, V = 5, VI = 6, VII = 7 }

local function getRarityText(artifactFrame)
	local main = artifactFrame:FindFirstChild("Main")
	local rarity = main and main:FindFirstChild("Rarity")
	return rarity and rarity.Text or nil
end

local function getTitleText(artifactFrame)
	local main = artifactFrame:FindFirstChild("Main")
	local tl = main and main:FindFirstChild("Title")
	if tl and tl.ClassName == "TextLabel" then return tl.Text end
	return nil
end

local function collectRatesAndAllBelow2(artifactFrame)
	local main = artifactFrame:FindFirstChild("Main")
	local stats = main and main:FindFirstChild("Stats")
	if not stats then return nil end

	local kids = stats:GetChildren()
	local rates, n = {}, 0
	local hadAny = false

	for i = 1, #kids do
		local stat = kids[i]
		if stat.ClassName == "Frame" then
			local rate = stat:FindFirstChild("Rate")
			if rate and rate.ClassName == "TextLabel" then
				hadAny = true
				local txt = rate.Text
				local val = ROMAN_VAL[txt]
				if not val then return nil end
				if val > 6 then return nil end
				n += 1
				rates[n] = txt
			end
		end
	end

	if not hadAny then return nil end
	return rates
end

local kids = artifactsScroll:GetChildren()
for i = 1, #kids do
	local a = kids[i]
	if a.ClassName == "Frame" then
		local rarityText = getRarityText(a)
		if rarityText and ALLOWED[rarityText] then
			local rates = collectRatesAndAllBelow2(a)
			if rates then
				print(getTitleText(a) or "(no title)")
				for j = 1, #rates do
					print(rates[j])
				end
				DeleteRF:InvokeServer(a.Name)
				a:Destroy()
			end
		end
	end
end
print("Done")