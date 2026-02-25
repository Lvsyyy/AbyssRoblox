local ChestsRoot = workspace:WaitForChild("Game"):WaitForChild("Chests")

-- =========================
-- BASELINES (from your dumps)
-- =========================
-- Tier 1
local T1_CLOSED = Vector3.new(0.0081, -0.0108, -1.7163)
local T1_OPEN   = Vector3.new(-3.5610, 0.0720, -1.7740)

-- Tier 2 (updated from your latest compare: chest1=closed, chest2=open)
local T2_CLOSED = Vector3.new(-0.012070, 2.585449, 0.032104)
local T2_OPEN   = Vector3.new(-0.059204, 2.753906, -4.522644)

-- tolerances
local T1_EPS = 0.35
local T2_EPS = 0.60

-- =========================
-- HELPERS
-- =========================
local function getTopBottom(chestContainer: Instance): (BasePart?, BasePart?)
	local chest = chestContainer:FindFirstChild("Chest")
	if not chest then return nil, nil end
	local main = chest:FindFirstChild("Main")
	if not main then return nil, nil end

	local top = main:FindFirstChild("TopChest")
	local bottom = main:FindFirstChild("BottomChest")
	if top and bottom and top:IsA("BasePart") and bottom:IsA("BasePart") then
		return top, bottom
	end
	return nil, nil
end

local function relPos(top: BasePart, bottom: BasePart): Vector3
	return bottom.CFrame:ToObjectSpace(top.CFrame).Position
end

local function isClosedByRel(top: BasePart, bottom: BasePart, closedRef: Vector3, openRef: Vector3, eps: number): boolean
	local p = relPos(top, bottom)
	local dClosed = (p - closedRef).Magnitude
	local dOpen = (p - openRef).Magnitude
	return dClosed <= eps and dClosed < dOpen
end

local function ensureHighlight(part: BasePart)
	local h = part:FindFirstChild("ChestCham")
	if h and h:IsA("Highlight") then return end

	h = Instance.new("Highlight")
	h.Name = "ChestCham"
	h.Adornee = part
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillTransparency = 0.25
	h.OutlineTransparency = 0
	h.Parent = part
end

local function removeHighlight(part: BasePart)
	local h = part:FindFirstChild("ChestCham")
	if h then h:Destroy() end
end

local function setPair(top: BasePart, bottom: BasePart, on: boolean)
	if on then
		ensureHighlight(top)
		ensureHighlight(bottom)
	else
		removeHighlight(top)
		removeHighlight(bottom)
	end
end

-- =========================
-- RULES
-- =========================
-- Tier 1: highlight CLOSED only
-- Tier 2: highlight CLOSED only (updated per your request)
-- Tier 3: highlight ALL for now (can change when you provide tier3 closed/open refs)
local function shouldHighlight(tierName: string, top: BasePart, bottom: BasePart): boolean
	if tierName == "Tier 1" then
		return isClosedByRel(top, bottom, T1_CLOSED, T1_OPEN, T1_EPS)
	elseif tierName == "Tier 2" then
		return isClosedByRel(top, bottom, T2_CLOSED, T2_OPEN, T2_EPS)
	elseif tierName == "Tier 3" then
		return true
	end
	return false
end

local function processChest(chestContainer: Instance, tierName: string)
	local top, bottom = getTopBottom(chestContainer)
	if not top or not bottom then return end
	setPair(top, bottom, shouldHighlight(tierName, top, bottom))
end

local function scan()
	for _, tier in ipairs(ChestsRoot:GetChildren()) do
		local tierName = tier.Name
		if tierName == "Tier 1" or tierName == "Tier 2" or tierName == "Tier 3" then
			for _, chestContainer in ipairs(tier:GetChildren()) do
				processChest(chestContainer, tierName)
			end
		end
	end
end

scan()
task.spawn(function()
	while true do
		scan()
		task.wait(0.25)
	end
end)
