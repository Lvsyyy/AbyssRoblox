local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer

local CONFIG = {
	-- Script to execute again after rejoin
	SCRIPT_URL = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_QoL_gui.lua",
	REJOIN_DELAY = 2,
	REEXEC_DELAY = 8,
	REEXEC_RETRIES = 8,
	REEXEC_RETRY_DELAY = 3,
}

local function runConfiguredScript()
	if type(CONFIG.SCRIPT_URL) ~= "string" or CONFIG.SCRIPT_URL == "" then
		return
	end
	task.wait(CONFIG.REEXEC_DELAY)
	for _ = 1, CONFIG.REEXEC_RETRIES do
		local ok = pcall(function()
			loadstring(game:HttpGet(CONFIG.SCRIPT_URL))()
		end)
		if ok then
			return
		end
		task.wait(CONFIG.REEXEC_RETRY_DELAY)
	end
	warn("Abyss AutoRejoin: failed to re-execute script after retries.")
end

local function queueScriptOnTeleport(code)
	if type(queue_on_teleport) == "function" then
		queue_on_teleport(code)
		return true
	end
	if type(queueonteleport) == "function" then
		queueonteleport(code)
		return true
	end
	if syn and type(syn.queue_on_teleport) == "function" then
		syn.queue_on_teleport(code)
		return true
	end
	if fluxus and type(fluxus.queue_on_teleport) == "function" then
		fluxus.queue_on_teleport(code)
		return true
	end
	return false
end

local function buildReexecCode()
	return ([[
local url = %q
local startDelay = %d
local retries = %d
local retryDelay = %d
task.wait(startDelay)
for i = 1, retries do
	local ok = pcall(function()
		loadstring(game:HttpGet(url))()
	end)
	if ok then
		break
	end
	task.wait(retryDelay)
end
]]):format(CONFIG.SCRIPT_URL, CONFIG.REEXEC_DELAY, CONFIG.REEXEC_RETRIES, CONFIG.REEXEC_RETRY_DELAY)
end

task.spawn(function()
	local ok, teleportData = pcall(function()
		return TeleportService:GetLocalPlayerTeleportData()
	end)
if ok and type(teleportData) == "table" and teleportData.__abyss_reexec == true then
		runConfiguredScript()
	end
end)

local rejoining = false
local function rejoinNow()
	if rejoining then return end
	rejoining = true

	local queued = queueScriptOnTeleport(buildReexecCode())
	task.wait(CONFIG.REJOIN_DELAY)

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		__abyss_reexec = true,
	})

	local ok = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { lp }, options)
	end)

	if not ok then
		if not queued then
			warn("Abyss AutoRejoin: queue_on_teleport missing; re-exec may not run after rejoin.")
		end
		TeleportService:Teleport(game.PlaceId, lp)
	end
end

local function isKickPrompt(guiObj)
	if not guiObj or not guiObj:IsA("GuiObject") then
		return false
	end
	if guiObj.Name ~= "ErrorPrompt" then
		return false
	end
	local title = guiObj:FindFirstChild("Title", true)
	if title and title:IsA("TextLabel") then
		local t = string.lower(title.Text or "")
		if string.find(t, "kicked", 1, true) or string.find(t, "disconnected", 1, true) then
			return true
		end
	end
	return true
end

local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")

promptOverlay.ChildAdded:Connect(function(child)
	if isKickPrompt(child) then
		task.spawn(rejoinNow)
	end
end)
