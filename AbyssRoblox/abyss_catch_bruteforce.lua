local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local targetRF = ReplicatedStorage.common.packages.Knit.Services.MinigameService.RF.Update
local playerGui = Players.LocalPlayer.PlayerGui
local PROGRESS_INCREMENT = 0.2
local currentForcedProgress = nil
local hookedBars = setmetatable({}, { __mode = "k" })

local function hookProgressBar(bar)
	if hookedBars[bar] then
		return
	end
	hookedBars[bar] = true

    bar:GetPropertyChangedSignal("Position"):Connect(function()
        local forced = currentForcedProgress
        if forced == nil then
            return
        end

        local y = 1 - forced
        if y < 0 then
            y = 0
        end

        local targetPos = UDim2.new(0.5, 0, y, 0)

        if bar.Position ~= targetPos then
            bar.Position = targetPos
        end
    end)
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
            local base = tonumber(args[2].progress) or 0
            local forced = math.clamp(base + PROGRESS_INCREMENT, 0, 1)
            currentForcedProgress = forced

            args[2].progress = forced

            if args[2].rewards then
                for _, reward in ipairs(args[2].rewards) do
                    if type(reward) == "table" and type(reward.progress) == "number" then
                        reward.progress = math.clamp(reward.progress + PROGRESS_INCREMENT, 0, 1)
                    end
                end
            end

            return oldNamecall(self, unpack(args))
        end
    end

    return oldNamecall(self, ...)
end)

print("[Minigame Hook] Active")