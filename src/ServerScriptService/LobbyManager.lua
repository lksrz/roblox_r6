-- Manages lobby countdown when 2+ players are present

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundService = require(script.Parent.Round.RoundService)

local LobbyManager = {}

local countdownConnection = nil
local isCountingDown = false
local countdownStartTime = nil

-- Get events for broadcasting
local function getEvents()
    local net = ReplicatedStorage:FindFirstChild("Net")
    if net and net:FindFirstChild("Events") then
        local ok, mod = pcall(require, net.Events)
        if ok and mod then return mod end
    end
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Remotes"
        folder.Parent = ReplicatedStorage
    end
    local function ensure(name, className)
        local obj = folder:FindFirstChild(name)
        if not obj then
            obj = Instance.new(className)
            obj.Name = name
            obj.Parent = folder
        end
        return obj
    end
    return {
        RoundChanged = ensure("RoundChanged", "RemoteEvent"),
    }
end

local Events = getEvents()

local function broadcast(message)
    Events.RoundChanged:FireAllClients({
        state = "Lobby",
        phase = "Lobby",
        message = message.text,
        timeRemaining = message.time,
        scores = { A = 0, B = 0 }  -- Include scores to avoid nil
    })
end

local function stopCountdown()
    if countdownConnection then
        countdownConnection:Disconnect()
        countdownConnection = nil
    end
    isCountingDown = false
    countdownStartTime = nil
    broadcast({ text = "Waiting for players..." })
end

local function startCountdown()
    -- Don't start if already counting or not in lobby
    if isCountingDown then return end
    if RoundService.IsInMatch() then return end

    -- Check player count
    if #Players:GetPlayers() < 2 then
        stopCountdown()
        return
    end

    isCountingDown = true
    countdownStartTime = os.clock()
    local countdownDuration = 10
    local lastBroadcast = -1

    countdownConnection = RunService.Heartbeat:Connect(function()
        -- Check if we still have enough players
        if #Players:GetPlayers() < 2 then
            stopCountdown()
            return
        end

        -- Check if round already started
        if RoundService.IsInMatch() then
            stopCountdown()
            return
        end

        local elapsed = os.clock() - countdownStartTime
        local remaining = math.ceil(countdownDuration - elapsed)

        if remaining ~= lastBroadcast and remaining >= 0 then
            broadcast({
                text = "Match starting in...",
                time = remaining
            })
            lastBroadcast = remaining
        end

        if elapsed >= countdownDuration then
            stopCountdown()
            -- Start the match
            if #Players:GetPlayers() >= 2 then
                task.spawn(function()
                    RoundService.StartLoop()
                end)
            end
        end
    end)
end

function LobbyManager.CheckAndStart()
    -- Only manage countdown if we're in lobby
    if RoundService.IsInMatch() then
        return
    end

    if #Players:GetPlayers() >= 2 then
        if not isCountingDown then
            startCountdown()
        end
    else
        stopCountdown()
    end
end

-- Monitor player changes
Players.PlayerAdded:Connect(function()
    task.wait(0.5) -- Let player load
    LobbyManager.CheckAndStart()
end)

Players.PlayerRemoving:Connect(function()
    task.defer(function() -- Check after player leaves
        LobbyManager.CheckAndStart()
    end)
end)

-- Also called when match ends
function LobbyManager.OnMatchEnd()
    task.wait(1) -- Brief pause after match
    LobbyManager.CheckAndStart()
end

-- Initial broadcast when server starts
task.spawn(function()
    task.wait(2)
    if #Players:GetPlayers() < 2 then
        broadcast({ text = "Waiting for players..." })
    end
end)

return LobbyManager