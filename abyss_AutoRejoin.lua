local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer

local CONFIG = {
	-- Script to execute again after rejoin
	SCRIPT_URL = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_QoL_gui.lua",
	REJOIN_DELAY = 2,
}

local function queueScriptOnTeleport(code)
	if type(queue_on_teleport) == "function" then
		queue_on_teleport(code)
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
	return ("pcall(function() loadstring(game:HttpGet(%q))() end)"):format(CONFIG.SCRIPT_URL)
end

local function rejoinNow()
	queueScriptOnTeleport(buildReexecCode())
	task.wait(CONFIG.REJOIN_DELAY)
	TeleportService:Teleport(game.PlaceId, lp)
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

