local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local g = getgenv and getgenv() or _G
local GUI_URL = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_GUI.lua"
local REJOIN_URL = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_AutoRejoin.lua"

if g and g.__abyss_auto_rejoin_loaded then
	return
end
if g then
	g.__abyss_auto_rejoin_loaded = true
end

local function runConfiguredScript()
	if type(GUI_URL) ~= "string" or GUI_URL == "" then
		return
	end
	task.wait(5)
	for _ = 1, 12 do
		local ok = pcall(function()
			loadstring(game:HttpGet(GUI_URL))()
		end)
		if ok then
			return
		end
		task.wait(2)
	end
end

local function queueScriptOnTeleport(code)
	if type(queue_on_teleport) == "function" then
		local ok = pcall(queue_on_teleport, code)
		if ok then
			return true
		end
	end
	if type(queueonteleport) == "function" then
		local ok = pcall(queueonteleport, code)
		if ok then
			return true
		end
	end
	return false
end

local function buildGuiReexecCode()
	return ("local u=%q task.wait(5) for i=1,12 do local ok=pcall(function() loadstring(game:HttpGet(u))() end) if ok then break end task.wait(2) end"):format(GUI_URL)
end

local function buildAutoRejoinCode()
	return ("pcall(function() loadstring(game:HttpGet(%q))() end)"):format(REJOIN_URL)
end

local function buildQueueCode()
	return buildAutoRejoinCode() .. " " .. buildGuiReexecCode()
end

-- Queue reexec immediately so any teleport (including reconnect) runs it.
do
	local ok = queueScriptOnTeleport(buildQueueCode())
	if g then
		g.__abyss_reexec_queued = ok and true or false
	end
end

local function httpGet(url)
	local funcs = {
		http and http.request,
		http_request,
		request,
	}

	for i = 1, #funcs do
		local fn = funcs[i]
		if type(fn) == "function" then
			local ok, resp = pcall(fn, {
				Url = url,
				Method = "GET",
			})
			if ok and type(resp) == "table" and tonumber(resp.StatusCode) == 200 and type(resp.Body) == "string" then
				return resp.Body
			end
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and body ~= "" then
		return body
	end

	return nil
end

local PROBE_URL = ("https://games.roblox.com/v1/games?placeIds=%d"):format(game.PlaceId)

local function probeOnline()
	local body = httpGet(PROBE_URL)
	return type(body) == "string" and body ~= ""
end

local function probeDelay(elapsed)
	if elapsed < 10 then
		return 0.5
	end
	if elapsed < 30 then
		return 2
	end
	return 10
end

local function waitForConnectivity()
	local start = os.clock()
	while true do
		if probeOnline() then
			return true
		end
		task.wait(probeDelay(os.clock() - start))
	end
end

local rejoining = false
local rejoinArmed = false
local queuedThisTeleport = false
local pendingTeleport = false
local pendingTeleportAt = 0
local PENDING_TIMEOUT = 8
local nextPromptTpAt = 0
local postProbeCooldownUntil = 0
local rejoinNow

local function markPendingTeleport()
	pendingTeleport = true
	pendingTeleportAt = os.clock()
end

local function clearPendingTeleport()
	pendingTeleport = false
	pendingTeleportAt = 0
end

local function tryRejoinOnce()
	local teleportData = { __abyss_reexec = true }
	local ok = pcall(function()
		TeleportService:Teleport(game.PlaceId, lp, teleportData)
	end)
	if ok then
		markPendingTeleport()
	end
	return ok
end

local function hasDisconnectText(root)
	local texts = root:GetDescendants()
	for i = 1, #texts do
		local inst = texts[i]
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			local t = string.lower(inst.Text or "")
			if t:find("kicked", 1, true) or t:find("disconnected", 1, true) or t:find("lost connection", 1, true) or t:find("connection error", 1, true) or t:find("failed to connect", 1, true) or t:find("please check your internet connection", 1, true) or t:find("error code 277", 1, true) or t:find("server shutdown", 1, true) or t:find("session expired", 1, true) or t:find("error code", 1, true) then
				return true
			end
		end
	end
	return false
end

local function findReconnectButton(root)
	local byName = root:FindFirstChild("ReconnectButton", true)
	if byName and byName:IsA("GuiButton") then
		return byName
	end
	local buttons = root:GetDescendants()
	for i = 1, #buttons do
		local inst = buttons[i]
		if inst:IsA("GuiButton") then
			local t = ""
			if inst:IsA("TextButton") then
				t = inst.Text or ""
			end
			if t == "" then
				local kids = inst:GetDescendants()
				for k = 1, #kids do
					local kid = kids[k]
					if kid:IsA("TextLabel") and kid.Text and kid.Text ~= "" then
						t = kid.Text
						break
					end
				end
			end
			local lower = string.lower(t)
			if lower:find("rejoin", 1, true) or lower:find("reconnect", 1, true) or lower:find("retry", 1, true) then
				return inst
			end
		end
	end
	return nil
end

local function pressButton(btn)
	if not btn then
		return false
	end
	if not VirtualInputManager then
		return false
	end
	return pcall(function()
		GuiService.SelectedObject = btn
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	end)
end

local function isKickPrompt(guiObj)
	if not guiObj or not guiObj:IsA("GuiObject") then
		return false
	end
	local name = string.lower(guiObj.Name or "")
	if name:find("error", 1, true) or name:find("prompt", 1, true) or name:find("disconnect", 1, true) or name:find("kick", 1, true) then
		return hasDisconnectText(guiObj)
	end
	return false
end

local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")

local function hasKickPrompt()
	local kids = promptOverlay:GetChildren()
	for i = 1, #kids do
		if isKickPrompt(kids[i]) then
			return true
		end
	end
	return false
end

local lastPromptPress = 0
local function tryPressReconnect()
	local now = os.clock()
	if now - lastPromptPress < 1 then
		return false
	end
	local btn = findReconnectButton(promptOverlay)
	if btn and pressButton(btn) then
		lastPromptPress = now
		return true
	end
	return false
end

local promptVisibleSince = 0

rejoinNow = function()
	if rejoining then return end
	rejoining = true
	rejoinArmed = true
	queuedThisTeleport = false
	nextPromptTpAt = 0
	postProbeCooldownUntil = 0
	task.wait(0.1)

	if queueScriptOnTeleport(buildQueueCode()) then
		queuedThisTeleport = true
	end

	local delay = 0.2
	while true do
		local stepWait = delay
		local bumpDelay = false
		if pendingTeleport then
			if os.clock() - pendingTeleportAt > PENDING_TIMEOUT then
				clearPendingTeleport()
			end
		else
			if hasKickPrompt() then
				clearPendingTeleport()
				if promptVisibleSince == 0 then
					promptVisibleSince = os.clock()
					nextPromptTpAt = promptVisibleSince + 10
				end
				if not probeOnline() then
					waitForConnectivity()
				end
				tryPressReconnect()
				if os.clock() >= nextPromptTpAt then
					nextPromptTpAt = os.clock() + 10
					tryRejoinOnce()
				end
				stepWait = 1
			else
				promptVisibleSince = 0
				nextPromptTpAt = 0
				if not probeOnline() then
					waitForConnectivity()
				end
				if postProbeCooldownUntil == 0 then
					postProbeCooldownUntil = os.clock() + 10
				end
				if os.clock() >= postProbeCooldownUntil then
					postProbeCooldownUntil = 0
					tryRejoinOnce()
					bumpDelay = true
				else
					stepWait = 1
				end
			end
		end
		task.wait(stepWait)
		if bumpDelay then
			delay = math.min(2, delay * 1.2)
		end
	end
end

promptOverlay.ChildAdded:Connect(function(child)
	if isKickPrompt(child) then
		task.spawn(rejoinNow)
	end
end)

do
	local kids = promptOverlay:GetChildren()
	for i = 1, #kids do
		if isKickPrompt(kids[i]) then
			task.spawn(rejoinNow)
			break
		end
	end
end

task.spawn(function()
	while true do
		local btn = findReconnectButton(promptOverlay)
		if btn then
			pressButton(btn)
		end
		task.wait(1)
	end
end)

GuiService.ErrorMessageChanged:Connect(function(msg)
	if type(msg) == "string" and msg ~= "" then
		local t = string.lower(msg)
		if t:find("kicked", 1, true) or t:find("disconnected", 1, true) or t:find("lost connection", 1, true) or t:find("connection error", 1, true) or t:find("failed to connect", 1, true) or t:find("error code 277", 1, true) then
			task.spawn(rejoinNow)
		end
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player)
	if player == lp then
		clearPendingTeleport()
		task.spawn(rejoinNow)
	end
end)

LogService.MessageOut:Connect(function(msg)
	local t = string.lower(tostring(msg))
	if t:find("error code 277", 1, true) or t:find("disconnected", 1, true) then
		task.spawn(rejoinNow)
	end
end)

pcall(function()
	local nc = game:GetService("NetworkClient")
	nc.ChildRemoved:Connect(function()
		task.spawn(rejoinNow)
	end)
end)

task.spawn(function()
	local ok, teleportData = pcall(function()
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	if ok
		and type(teleportData) == "table"
		and teleportData.__abyss_reexec == true
		and not g.__abyss_reexec_consumed
	then
		g.__abyss_reexec_consumed = true
		runConfiguredScript()
	end
end)

lp.OnTeleport:Connect(function(state)
	if not rejoinArmed then return end
	if state == Enum.TeleportState.Failed then
		clearPendingTeleport()
	elseif state == Enum.TeleportState.InProgress or state == Enum.TeleportState.Started or state == Enum.TeleportState.WaitingForServer then
		markPendingTeleport()
	end
	if state ~= Enum.TeleportState.InProgress then return end
	if queuedThisTeleport then return end
	if queueScriptOnTeleport(buildQueueCode()) then
		queuedThisTeleport = true
	end
end)

if g then
	g.__abyss_rejoin_now = rejoinNow
end
