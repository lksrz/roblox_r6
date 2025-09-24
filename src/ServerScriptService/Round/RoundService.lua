local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Simple config - avoid dependency on ConfigLoader
local Config = {
    ROUND = {
        LENGTH_SEC = 180,
        WIN_TARGET = 3,
        SWITCH_SIDES_EVERY = 2,
        OBJECTIVE_TIME_LIMIT = 60  -- Time limit for objective capture
    },
}
local function getEvents()
    -- Prefer module if present, otherwise ensure Remotes directly
    local net = ReplicatedStorage:FindFirstChild("Net")
    if net and net:FindFirstChild("Events") then
        local ok, mod = pcall(require, net.Events)
        if ok and mod then return mod end
    end
    local function ensure(name, className)
        local folder = ReplicatedStorage:FindFirstChild("Remotes")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "Remotes"
            folder.Parent = ReplicatedStorage
        end
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
        RequestSpawn = ensure("RequestSpawn", "RemoteFunction"),
        UseGadget = ensure("UseGadget", "RemoteEvent"),
        FireWeapon = ensure("FireWeapon", "RemoteEvent"),
        HitConfirm = ensure("HitConfirm", "RemoteEvent"),
        Objective = ensure("ObjectiveEvent", "RemoteEvent"),
    }
end

local Events = getEvents()
local State = require(script.Parent.RoundState)
local ObjectiveService = require(script.Parent.Parent.Gameplay.ObjectiveService)

local RoundService = {}
local scores = { A = 0, B = 0 }
local state: State.State = State.Lobby
local roundId = 0
local loopRunning = false

-- Public function to check if currently in a match
function RoundService.IsInMatch()
    return state ~= State.Lobby
end

local function broadcast(extra)
    local payload = { state = state, scores = scores, roundId = roundId }
    if extra then
        for k,v in pairs(extra) do payload[k] = v end
    end
    Events.RoundChanged:FireAllClients(payload)
end

function RoundService.StartLoop()
    if loopRunning then return end  -- Prevent multiple loops
    if state ~= State.Lobby then return end

    loopRunning = true
    roundId += 1
    scores = { A = 0, B = 0 }  -- Reset scores for new match

    while scores.A < Config.ROUND.WIN_TARGET and scores.B < Config.ROUND.WIN_TARGET do
        -- Start objective round - find red spawn position
        local redSpawn = workspace:FindFirstChild("RedSpawn")
        local redSpawnPos = redSpawn and redSpawn.Position or Vector3.new(-200, 1.5, -200)

        -- Prep countdown
        state = State.Prep
        local prepDur = 5
        local prepEnd = os.clock() + prepDur
        local lastRemain = -1

        -- Spawn objective at the start of prep phase
        ObjectiveService.StartRound(redSpawnPos)

        repeat
            local remain = math.max(0, math.ceil(prepEnd - os.clock()))
            if remain ~= lastRemain then
                broadcast({ timeRemaining = remain, phase = "Prep" })
                lastRemain = remain
            end
            task.wait(0.2)
        until os.clock() >= prepEnd

        -- Live (round) countdown handled inside PlayRound via callback
        state = State.Live
        broadcast({ phase = "Live" })

        -- Start the objective timer NOW (when live phase begins)
        ObjectiveService.StartTimer()

        -- Run the round with proper win conditions
        local liveLast = -1
        local roundResult = RoundService.PlayRound(function(remain)
            if remain ~= liveLast then
                broadcast({ timeRemaining = remain, phase = "Live" })
                liveLast = remain
            end
        end)

        if roundResult == "AttackWin" then
            scores.A += 1
            print("[RoundService] Attack wins! Red team delivered. Score:", scores.A, "-", scores.B)
        elseif roundResult == "DefenseWin" then
            scores.B += 1
            print("[RoundService] Defense wins! Time expired. Score:", scores.A, "-", scores.B)
        else
            print("[RoundService] Round ended with no result:", roundResult)
        end

        -- Clean up objective when round ends
        ObjectiveService.CleanupObjective()

        -- End screen countdown
        state = State.End
        local endDur = 4
        local endAt = os.clock() + endDur
        lastRemain = -1
        repeat
            local remain = math.max(0, math.ceil(endAt - os.clock()))
            if remain ~= lastRemain then
                broadcast({ timeRemaining = remain, phase = "End" })
                lastRemain = remain
            end
            task.wait(0.2)
        until os.clock() >= endAt
    end
    state = State.Lobby
    loopRunning = false  -- Reset flag when match ends
    broadcast({ phase = "MatchComplete" })

    -- Notify lobby manager to handle countdown
    local LobbyManager = require(script.Parent.Parent.LobbyManager)
    LobbyManager.OnMatchEnd()
end

function RoundService.PlayRound(onUpdate)
    local startTime = os.clock()
    local timeLimit = Config.ROUND.OBJECTIVE_TIME_LIMIT or 60

    while true do
        local elapsed = os.clock() - startTime

        -- Check if time limit reached
        if elapsed >= timeLimit then return "DefenseWin" end

        -- Update clients with remaining time occasionally
        if onUpdate then
            local remain = math.max(0, math.ceil(timeLimit - elapsed))
            onUpdate(remain)
        end

        -- Check objective service for win conditions
        local objectiveResult = ObjectiveService.Tick()
        if objectiveResult then
            print("[RoundService] ObjectiveService returned:", objectiveResult)
            return objectiveResult
        end

        -- Small delay to prevent excessive CPU usage
        task.wait(0.25)
    end
end

return RoundService
