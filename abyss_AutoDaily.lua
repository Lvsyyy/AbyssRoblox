local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local Common = ReplicatedStorage:WaitForChild("common")
local Knit = require(Common:WaitForChild("packages"):WaitForChild("Knit"))
local DailyClaimRF = Common
	:WaitForChild("packages")
	:WaitForChild("Knit")
	:WaitForChild("Services")
	:WaitForChild("DailyRewardService")
	:WaitForChild("RF")
	:WaitForChild("Claim")

local DAILY_READY_TEXT = "Next reward in: <font color='#ffffff'><b>00:00</b></font>"

local enabled = false
local labelConn
local timeConn
local loopId = 0
local lastClaimAt = 0
local dataController

local function getDailyRewardsData()
	if not dataController then
		pcall(function()
			dataController = Knit.GetController("DataController")
		end)
	end
	if not dataController then return nil end

	local ok, replica = pcall(function()
		return dataController:GetReplica()
	end)
	if not ok or not replica or not replica.Data then
		return nil
	end
	return replica.Data.daily_rewards
end

local function isDailyReadyByData()
	local daily = getDailyRewardsData()
	if type(daily) ~= "table" then return nil end
	if type(daily.last_claim) ~= "number" then return nil end

	local timeNow = workspace:GetAttribute("TimeNow")
	if type(timeNow) ~= "number" then return nil end

	return (daily.last_claim + 86400 - timeNow) <= 0
end

local function getDailyLabel()
	local main = pg:FindFirstChild("Main")
	if not main then return nil end
	local center = main:FindFirstChild("Center")
	if not center then return nil end
	local daily = center:FindFirstChild("DailyReward")
	if not daily then return nil end
	local nextReward = daily:FindFirstChild("NextReward")
	if not nextReward then return nil end
	local label = nextReward:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function tryClaim()
	if not enabled then return end
	local readyByData = isDailyReadyByData()
	local label = getDailyLabel()
	local readyByLabel = (label and label.Text == DAILY_READY_TEXT) and true or false
	if (readyByData == true or readyByLabel) and os.clock() - lastClaimAt > 3 then
		lastClaimAt = os.clock()
		pcall(function()
			DailyClaimRF:InvokeServer()
		end)
	end
end

local function setEnabled(v)
	enabled = v == true

	if labelConn then
		labelConn:Disconnect()
		labelConn = nil
	end
	if timeConn then
		timeConn:Disconnect()
		timeConn = nil
	end

	loopId += 1
	if enabled then
		local label = getDailyLabel()
		if label then
			labelConn = label:GetPropertyChangedSignal("Text"):Connect(tryClaim)
		end
		timeConn = workspace:GetAttributeChangedSignal("TimeNow"):Connect(tryClaim)
		local thisLoop = loopId
		task.spawn(function()
			while enabled and loopId == thisLoop do
				tryClaim()
				task.wait(1)
			end
		end)
		tryClaim()
	end
end

local function getEnabled()
	return enabled
end

return {
	setEnabled = setEnabled,
	getEnabled = getEnabled,
}
