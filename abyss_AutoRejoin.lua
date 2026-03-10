local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer

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

local function getLowestPublicServerJobId()
local cursor = nil

while true do
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
					return id
				end
			end
		end

		cursor = decoded.nextPageCursor
		if type(cursor) ~= "string" or cursor == "" then
			break
		end
end

return nil
end

local rejoining = false

local function tryRejoinOnce()
	local options = Instance.new("TeleportOptions")
	local ok = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { lp }, options)
	end)
	if ok then
		return true
	end

	-- Only scan for a specific server every 3rd failure to reduce latency.
	if math.random(1, 3) == 1 then
		local targetJobId = getLowestPublicServerJobId()
		if targetJobId then
			local okLowest = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, lp)
			end)
			if okLowest then
				return true
			end
		end
	end

	local okFallback = pcall(function()
		TeleportService:Teleport(game.PlaceId, lp)
	end)
	return okFallback
end

local function rejoinNow()
	if rejoining then return end
	rejoining = true
	task.wait(0.1)

	local delay = 0.2
	while true do
		if tryRejoinOnce() then
			return
		end
		task.wait(delay)
		delay = math.min(5, delay * 1.2)
	end
end

local function hasDisconnectText(root)
	local texts = root:GetDescendants()
	for i = 1, #texts do
		local inst = texts[i]
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			local t = string.lower(inst.Text or "")
			if t:find("kicked", 1, true)
				or t:find("disconnected", 1, true)
				or t:find("lost connection", 1, true)
				or t:find("connection error", 1, true)
				or t:find("failed to connect", 1, true)
				or t:find("please check your internet connection", 1, true)
				or t:find("error code 277", 1, true)
				or t:find("server shutdown", 1, true)
				or t:find("session expired", 1, true)
				or t:find("error code", 1, true)
			then
				return true
			end
		end
	end
	return false
end

local function findReconnectButton(root)
	local buttons = root:GetDescendants()
	for i = 1, #buttons do
		local inst = buttons[i]
		if inst:IsA("TextButton") then
			local t = string.lower(inst.Text or "")
			if t:find("rejoin", 1, true)
				or t:find("reconnect", 1, true)
				or t:find("retry", 1, true)
				or t:find("reconnect", 1, true)
			then
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
	local ok = pcall(function()
		if firesignal and btn.MouseButton1Click then
			firesignal(btn.MouseButton1Click)
		end
	end)
	if ok then
		return true
	end
	return pcall(function()
		btn:Activate()
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
