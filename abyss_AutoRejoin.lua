local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local g = getgenv and getgenv() or _G
local _wait = (task and task.wait) or wait
local _spawn = (task and task.spawn) or spawn
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
	_wait(5)
	for _ = 1, 12 do
		local ok = pcall(function()
			loadstring(game:HttpGet(GUI_URL))()
		end)
		if ok then
			return
		end
		_wait(2)
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
local SERVER_MIN_PLAYERS = 4
local SERVER_MAX_PLAYERS = 7
local SERVER_URL = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)

local function probeOnline()
	local body = httpGet(PROBE_URL)
	return type(body) == "string" and body ~= ""
end

local probeCount = 0
local function nextProbeDelay()
	probeCount = probeCount + 1
	if probeCount <= 3 then
		return 0.5
	end
	if probeCount <= 8 then
		return 2
	end
	return 60
end

local function waitForConnectivity()
	while true do
		if probeOnline() then
			probeCount = 0
			return true
		end
		_wait(nextProbeDelay())
	end
end

local function ensureOnline()
	if not connReady then
		waitForConnectivity()
		connReady = true
	end
end

local rejoining = false
local rejoinArmed = false
local queuedThisTeleport = false
local pendingTeleport = false
local pendingTeleportAt = 0
local PENDING_TIMEOUT = 8
local nextPromptTpAt = 0
local rejoinNow
local connReady = false

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
	local ok = false
	local serverId = nil

	local function pickServer()
		local cursor = nil
		for _ = 1, 5 do
			local url = SERVER_URL
			if cursor then
				url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
			end
			local body = httpGet(url)
			if type(body) ~= "string" then
				return nil
			end
			local okJson, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if not okJson or type(data) ~= "table" then
				return nil
			end
			local list = data.data
			if type(list) == "table" then
				for i = 1, #list do
					local srv = list[i]
					local playing = tonumber(srv and srv.playing)
					local id = srv and srv.id
					if id and id ~= game.JobId and playing and playing >= SERVER_MIN_PLAYERS and playing <= SERVER_MAX_PLAYERS then
						return id
					end
				end
			end
			cursor = data.nextPageCursor
			if not cursor then
				break
			end
		end
		return nil
	end

	serverId = pickServer()
	if serverId then
		ok = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, lp, teleportData)
		end)
	else
		ok = pcall(function()
			TeleportService:Teleport(game.PlaceId, lp, teleportData)
		end)
	end
	if ok then
		markPendingTeleport()
	end
	return ok
end

local function findReconnectButton(root)
	local btn = root:FindFirstChild("ReconnectButton", true)
	if btn and btn:IsA("GuiButton") then
		return btn
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

local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")

local function hasReconnectButtonVisible()
	local btn = findReconnectButton(promptOverlay)
	return btn ~= nil and btn.Visible == true
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
	probeCount = 0
	connReady = probeOnline()
	_wait(0.1)

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
				if hasReconnectButtonVisible() then
					clearPendingTeleport()
					if promptVisibleSince == 0 then
						promptVisibleSince = os.clock()
					end
				ensureOnline()
				tryPressReconnect()
				if not pendingTeleport then
					tryRejoinOnce()
				end
				stepWait = 1
			else
				promptVisibleSince = 0
				nextPromptTpAt = 0
				ensureOnline()
				if not pendingTeleport then
					tryRejoinOnce()
					bumpDelay = true
				end
				stepWait = 1
			end
		end
		_wait(stepWait)
		if bumpDelay then
			delay = math.min(2, delay * 1.2)
		end
	end
end

promptOverlay.ChildAdded:Connect(function()
	_spawn(rejoinNow)
end)

_spawn(function()
	while true do
		local btn = findReconnectButton(promptOverlay)
		if btn then
			pressButton(btn)
		end
		_wait(1)
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player)
	if player == lp then
		clearPendingTeleport()
		_spawn(rejoinNow)
	end
end)

pcall(function()
	local nc = game:GetService("NetworkClient")
	nc.ChildRemoved:Connect(function()
		_spawn(rejoinNow)
	end)
end)

_spawn(function()
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
