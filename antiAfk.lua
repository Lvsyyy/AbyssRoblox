local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local running = false
local stopFlag = false
local idleConn = nil

local function sendInput()
	if VirtualUser then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	elseif VIM then
		VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
		VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
	end
end

local function start(intervalSeconds)
	if running then return end
	running = true
	stopFlag = false

	if lp and lp.Idled then
		idleConn = lp.Idled:Connect(function()
			sendInput()
		end)
	end

	task.spawn(function()
		while not stopFlag do
			sendInput()
			task.wait(intervalSeconds or 300)
		end
		running = false
	end)
end

local function stop()
	stopFlag = true
	if idleConn then
		idleConn:Disconnect()
		idleConn = nil
	end
end

return {
	start = start,
	stop = stop,
}
