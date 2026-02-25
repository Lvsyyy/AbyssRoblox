local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local targetRF = ReplicatedStorage.common.packages.Knit.Services.MinigameService.RF.Update
local playerGui = Players.LocalPlayer.PlayerGui

-- Tuned from your captures
local START_PROGRESS = 0.25
local PROGRESS_STEP = 0.05      -- ~1/20
local OVERRIDE_INTERVAL = 0.205
local END_PROGRESS_CAP = 0.99

local currentForcedProgress = nil
local hookedBars = setmetatable({}, { __mode = "k" })

local lastOverrideTime = 0
local stagedProgress = nil

local function shouldOverrideNow()
	local t = os.clock()
	if (t - lastOverrideTime) >= OVERRIDE_INTERVAL then
		lastOverrideTime = t
		return true
	end
	return false
end

local function hookProgressBar(bar)
	if hookedBars[bar] then
		return
	end
	hookedBars[bar] = true

	local function onBarChanged()
		-- Do not force while hidden; reset progression state
		if not bar.Visible then
			currentForcedProgress = nil
			stagedProgress = nil
			lastOverrideTime = 0
			return
		end

		local forced = currentForcedProgress
		if forced == nil then
			return
		end

		local y = 1 - forced
		if y <= 0 then
			y = 0.001
		end

		local targetPos = UDim2.new(0.5, 0, y, 0)
		if bar.Position ~= targetPos then
			bar.Position = targetPos
		end
	end

	bar:GetPropertyChangedSignal("Position"):Connect(onBarChanged)
	bar:GetPropertyChangedSignal("Visible"):Connect(onBarChanged)
end

local function checkForProgressBar(obj)
	if obj and obj.Name == "Bar" then
		hookProgressBar(obj)
	end
end

for _, obj in ipairs(playerGui:GetDescendants()) do
	checkForProgressBar(obj)
end

playerGui.DescendantAdded:Connect(function(obj)
	checkForProgressBar(obj)
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod()
	local args = { ... }

	if self == targetRF and method == "InvokeServer" then
		if args[1] == "ProgressUpdate" and type(args[2]) == "table" then
			if shouldOverrideNow() then
				local outgoing = tonumber(args[2].progress) or 0

				-- Staged progression (mimics captured behavior)
				if stagedProgress == nil then
					stagedProgress = math.max(START_PROGRESS, outgoing)
				else
					stagedProgress = math.min(stagedProgress + PROGRESS_STEP, END_PROGRESS_CAP)
				end

				currentForcedProgress = stagedProgress
				args[2].progress = stagedProgress

				if args[2].rewards then
					for _, reward in ipairs(args[2].rewards) do
						if type(reward) == "table" and type(reward.progress) == "number" then
							reward.progress = math.min(reward.progress + PROGRESS_STEP, 1)
						end
					end
				end

				return oldNamecall(self, unpack(args))
			end
		end
	end

	return oldNamecall(self, ...)
end)

print("[Minigame Hook] Active | start =", START_PROGRESS, "step =", PROGRESS_STEP, "interval =", OVERRIDE_INTERVAL, "cap =", END_PROGRESS_CAP)