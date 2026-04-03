local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Common = ReplicatedStorage:WaitForChild("common")
local Knit = require(Common:WaitForChild("packages"):WaitForChild("Knit"))
local DailyClaimRF = Common
    :WaitForChild("packages")
    :WaitForChild("Knit")
    :WaitForChild("Services")
    :WaitForChild("DailyRewardService")
    :WaitForChild("RF")
    :WaitForChild("Claim")

local enabled = false
local timeConn
local replicaConn
local lastClaimAt = 0
local scheduleToken = 0
local dataController
local replica
local timeReady = false

local scheduleNext
local tryClaim

local function getReplica()
    if not dataController then
        pcall(function()
            dataController = Knit.GetController("DataController")
        end)
    end
    if not dataController then return nil end
    if not replica then
        local ok, res = pcall(function()
            return dataController:GetReplica()
        end)
        if ok then
            replica = res
        end
        if replica and type(replica.ListenToChange) == "function" and not replicaConn then
            replicaConn = replica:ListenToChange({ "daily_rewards" }, function()
                if enabled and scheduleNext then
                    scheduleNext()
                end
            end)
        end
    end
    return replica
end

local function getTimeLeft()
    local rep = getReplica()
    if not rep or not rep.Data then return nil end
    local daily = rep.Data.daily_rewards
    if type(daily) ~= "table" then return nil end
    if type(daily.last_claim) ~= "number" then return nil end
    local timeNow = workspace:GetAttribute("TimeNow")
    if type(timeNow) ~= "number" then return nil end
    timeReady = true
    return daily.last_claim + 86400 - timeNow
end

local function attachTimeProbe()
    if timeConn then return end
    timeConn = workspace:GetAttributeChangedSignal("TimeNow"):Connect(function()
        if not enabled then return end
        if not timeReady then
            local left = getTimeLeft()
            if type(left) == "number" then
                if timeConn then
                    timeConn:Disconnect()
                    timeConn = nil
                end
                scheduleNext()
            end
        end
    end)
end

scheduleNext = function()
    scheduleToken += 1
    local myToken = scheduleToken
    local timeLeft = getTimeLeft()
    if type(timeLeft) ~= "number" then
        timeReady = false
        attachTimeProbe()
        return
    end
    if timeLeft <= 0 then
        tryClaim()
        return
    end
    task.delay(timeLeft, function()
        if enabled and scheduleToken == myToken then
            tryClaim()
        end
    end)
end

tryClaim = function()
    if not enabled then return end
    local timeLeft = getTimeLeft()
    local readyByData = (type(timeLeft) == "number") and (timeLeft <= 0) or nil
    if readyByData and os.clock() - lastClaimAt > 3 then
        lastClaimAt = os.clock()
        pcall(function()
            DailyClaimRF:InvokeServer()
        end)
        task.delay(2, function()
            if enabled then
                scheduleNext()
            end
        end)
        return
    end
    if type(timeLeft) == "number" and timeLeft > 0 then
        scheduleNext()
    end
end

local function setEnabled(v)
    enabled = v == true

    if timeConn then
        timeConn:Disconnect()
        timeConn = nil
    end
    if replicaConn then
        replicaConn:Disconnect()
        replicaConn = nil
    end

    if enabled then
        tryClaim()
        scheduleNext()
    else
        scheduleToken += 1
    end
end

local function getEnabled()
    return enabled
end

return {
    setEnabled = setEnabled,
    getEnabled = getEnabled,
}
