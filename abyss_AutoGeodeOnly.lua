local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnitServices = ReplicatedStorage
	:WaitForChild("common")
	:WaitForChild("packages")
	:WaitForChild("Knit")
	:WaitForChild("Services")

local MinigameRF = KnitServices:WaitForChild("MinigameService"):WaitForChild("RF")
local MinigameUpdateRF = MinigameRF:WaitForChild("Update")
local CancelMinigameRF = MinigameRF:WaitForChild("CancelMinigame")

local enabled = false
local hookInstalled = false

local function installHook()
	if hookInstalled then
		return true
	end
	if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
		return false
	end

	local wrap = type(newcclosure) == "function" and newcclosure or function(f) return f end
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
		local method = getnamecallmethod()
		if enabled and method == "InvokeServer" and self == MinigameUpdateRF then
			local args = { ... }
			if args[1] == "ProgressUpdate" and type(args[2]) == "table" then
				local rewards = args[2].rewards
				if type(rewards) == "table" and next(rewards) == nil then
					task.defer(function()
						pcall(function()
							CancelMinigameRF:InvokeServer()
						end)
					end)
				end
			end
		end
		return oldNamecall(self, ...)
	end))

	hookInstalled = true
	return true
end

local function setEnabled(v)
	enabled = v == true
	if enabled then
		installHook()
	end
end

local function getEnabled()
	return enabled
end

return {
	setEnabled = setEnabled,
	getEnabled = getEnabled,
}
