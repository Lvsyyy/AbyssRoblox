local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer

local CONFIG = {
	-- Script to execute again after rejoin
	SCRIPT_URL = "https://raw.githubusercontent.com/Lvsyyy/AbyssRoblox/main/abyss_QoL_gui.lua",
	REJOIN_DELAY = 2,
	REEXEC_DELAY = 8,
	REEXEC_RETRIES = 8,
	REEXEC_RETRY_DELAY = 3,
	SERVER_SCAN_PAGES = 3,
}

local IN_PROGRESS = Enum.TeleportState.InProgress
local rejoinArmed = false
local queuedThisTeleport = false
local g = getgenv and getgenv() or _G

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

local function httpGet(url)
	local funcs = {
		syn and syn.request,
		http and http.request,
		http_request,
		request,
		fluxus and fluxus.request,
		KRNL_LOADED and getgenv and getgenv().http_request,
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

local function getLowestPublicServerJobId()
	local cursor = nil
	local bestId = nil
	local bestPlaying = nil

	for _ = 1, CONFIG.SERVER_SCAN_PAGES do
		local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
		if type(cursor) == "string" and cursor ~= "" then
			url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
		end

		local body = httpGet(url)
		if not body then
			break
		end

		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if not ok or type(decoded) ~= "table" then
			break
		end

		local list = decoded.data
		if type(list) == "table" then
			for i = 1, #list do
				local srv = list[i]
				local id = srv and srv.id
				local playing = srv and srv.playing
				local maxPlayers = srv and srv.maxPlayers
				if type(id) == "string"
					and id ~= ""
					and id ~= game.JobId
					and type(playing) == "number"
					and type(maxPlayers) == "number"
					and playing > 0
					and playing < maxPlayers
				then
					if bestPlaying == nil or playing < bestPlaying then
						bestPlaying = playing
						bestId = id
					end
				end
			end
		end

		cursor = decoded.nextPageCursor
		if type(cursor) ~= "string" or cursor == "" then
			break
		end
	end

	return bestId
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
	if ok
		and type(teleportData) == "table"
		and teleportData.__abyss_reexec == true
		and not g.__abyss_reexec_consumed
	then
		g.__abyss_reexec_consumed = true
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

	local teleportData = {
		__abyss_reexec = true,
	}

	local targetJobId = getLowestPublicServerJobId()
	if targetJobId then
		local okLowest = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, lp, nil, teleportData)
		end)
		if okLowest then
			return
		end
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(teleportData)

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
