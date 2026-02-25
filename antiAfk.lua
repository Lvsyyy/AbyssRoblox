local VIM = game:GetService("VirtualInputManager")

local running = false
local stopFlag = false

local function start(intervalSeconds)
	if running then return end
	running = true
	stopFlag = false

	task.spawn(function()
		while not stopFlag do
			VIM:SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
			task.wait()
			VIM:SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
			task.wait(intervalSeconds or 10)
		end
		running = false
	end)
end

local function stop()
	stopFlag = true
end

return {
	start = start,
	stop = stop,
}
