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

local IN_PROGRESS = Enum.TeleportState.InProgress
local rejoinArmed = false
local queuedThisTeleport = false

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
	local funcs = {
		queue_on_teleport,
		queueonteleport,
		syn and syn.queue_on_teleport,
		syn and syn.queue_on_teleport,
		fluxus and fluxus.queue_on_teleport,
		KRNL_LOADED and getgenv and getgenv().queue_on_teleport,
	}
	for i = 1, #funcs do
		local fn = funcs[i]
		if type(fn) == "function" then
			local ok = pcall(fn, code)
			if ok then
				return true
			end
		end
	end
	return false
end

local function buildReexecCode()
	return ("local u=%q local d=%d local r=%d local rd=%d task.wait(d) for i=1,r do local ok=pcall(function() loadstring(game:HttpGet(u))() end) if ok then break end task.wait(rd) end"):format(
		CONFIG.SCRIPT_URL,
		CONFIG.REEXEC_DELAY,
		CONFIG.REEXEC_RETRIES,
		CONFIG.REEXEC_RETRY_DELAY
	)
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
	rejoinArmed = true
	queuedThisTeleport = false

	local queued = queueScriptOnTeleport(buildReexecCode())
	if queued then
		queuedThisTeleport = true
	end
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

lp.OnTeleport:Connect(function(state)
	if not rejoinArmed then return end
	if state ~= IN_PROGRESS then return end
	if queuedThisTeleport then return end
	if queueScriptOnTeleport(buildReexecCode()) then
		queuedThisTeleport = true
	end
end)

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
