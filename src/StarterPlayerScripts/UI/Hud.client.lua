-- Enhanced HUD with clear score display, timer, and team assignment

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local function getEvents()
    local ok, mod = pcall(function() return require(ReplicatedStorage.Net.Events) end)
    if ok and mod then return mod end
    local folder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
    local function get(name)
        return folder and (folder:FindFirstChild(name) or folder:WaitForChild(name, 5)) or nil
    end
    return {
        RoundChanged = get("RoundChanged"),
        Objective = get("ObjectiveEvent"),
    }
end

local Events = getEvents()

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Wait for PlayerGui to be ready and avoid conflicts
local playerGui = player:WaitForChild("PlayerGui")

-- Clean up any existing HUD
local existingHUD = playerGui:FindFirstChild("HUD")
if existingHUD then
    existingHUD:Destroy()
end

-- Add GUI to PlayerGui after a brief delay to avoid styling conflicts
task.wait(0.5)
gui.Parent = playerGui

-- Main container (wider, more prominent)
local container = Instance.new("Frame")
container.Size = UDim2.new(0, 460, 0, 100)
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 20)
container.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
container.BackgroundTransparency = 0.05
container.BorderSizePixel = 0
container.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = container

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.9
stroke.Parent = container

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28,28,35)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(22,22,28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18,18,24))
}
gradient.Rotation = 90
gradient.Parent = container

-- Score display section
local scoreSection = Instance.new("Frame")
scoreSection.Size = UDim2.new(1, -40, 0, 40)
scoreSection.Position = UDim2.new(0, 20, 0, 12)
scoreSection.BackgroundTransparency = 1
scoreSection.Parent = container

-- Attack team score
local attackFrame = Instance.new("Frame")
attackFrame.Size = UDim2.new(0, 160, 1, 0)
attackFrame.Position = UDim2.new(0, 0, 0, 0)
attackFrame.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
attackFrame.BackgroundTransparency = 0.7
attackFrame.BorderSizePixel = 0
attackFrame.Parent = scoreSection

local attackCorner = Instance.new("UICorner")
attackCorner.CornerRadius = UDim.new(0, 10)
attackCorner.Parent = attackFrame

local attackGradient = Instance.new("UIGradient")
attackGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200))
}
attackGradient.Rotation = 90
attackGradient.Parent = attackFrame

local attackTeamLabel = Instance.new("TextLabel")
attackTeamLabel.Size = UDim2.new(0.55, 0, 0.5, 0)
attackTeamLabel.Position = UDim2.new(0, 12, 0, 0)
attackTeamLabel.BackgroundTransparency = 1
attackTeamLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
attackTeamLabel.TextXAlignment = Enum.TextXAlignment.Left
attackTeamLabel.Font = Enum.Font.SourceSansSemibold
attackTeamLabel.TextSize = 12
attackTeamLabel.Text = "ATTACK"
attackTeamLabel.Parent = attackFrame

local attackScoreLabel = Instance.new("TextLabel")
attackScoreLabel.Size = UDim2.new(0.45, -12, 1, 0)
attackScoreLabel.Position = UDim2.new(0.55, 0, 0, 0)
attackScoreLabel.BackgroundTransparency = 1
attackScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
attackScoreLabel.TextXAlignment = Enum.TextXAlignment.Right
attackScoreLabel.Font = Enum.Font.SourceSansBold
attackScoreLabel.TextSize = 28
attackScoreLabel.Text = "0"
attackScoreLabel.Parent = attackFrame

local attackIcon = Instance.new("TextLabel")
attackIcon.Size = UDim2.new(0.55, 0, 0.5, 0)
attackIcon.Position = UDim2.new(0, 12, 0.5, 0)
attackIcon.BackgroundTransparency = 1
attackIcon.TextColor3 = Color3.fromRGB(160, 180, 200)
attackIcon.TextXAlignment = Enum.TextXAlignment.Left
attackIcon.Font = Enum.Font.SourceSansSemibold
attackIcon.TextSize = 11
attackIcon.Text = "⚔️ OFFENSIVE"
attackIcon.Parent = attackFrame

-- Defense team score
local defenseFrame = Instance.new("Frame")
defenseFrame.Size = UDim2.new(0, 160, 1, 0)
defenseFrame.AnchorPoint = Vector2.new(1, 0)
defenseFrame.Position = UDim2.new(1, 0, 0, 0)
defenseFrame.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
defenseFrame.BackgroundTransparency = 0.7
defenseFrame.BorderSizePixel = 0
defenseFrame.Parent = scoreSection

local defenseCorner = Instance.new("UICorner")
defenseCorner.CornerRadius = UDim.new(0, 10)
defenseCorner.Parent = defenseFrame

local defenseGradient = Instance.new("UIGradient")
defenseGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200))
}
defenseGradient.Rotation = 90
defenseGradient.Parent = defenseFrame

local defenseScoreLabel = Instance.new("TextLabel")
defenseScoreLabel.Size = UDim2.new(0.45, -12, 1, 0)
defenseScoreLabel.Position = UDim2.new(0, 12, 0, 0)
defenseScoreLabel.BackgroundTransparency = 1
defenseScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
defenseScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
defenseScoreLabel.Font = Enum.Font.SourceSansBold
defenseScoreLabel.TextSize = 28
defenseScoreLabel.Text = "0"
defenseScoreLabel.Parent = defenseFrame

local defenseTeamLabel = Instance.new("TextLabel")
defenseTeamLabel.Size = UDim2.new(0.55, 0, 0.5, 0)
defenseTeamLabel.AnchorPoint = Vector2.new(1, 0)
defenseTeamLabel.Position = UDim2.new(1, -12, 0, 0)
defenseTeamLabel.BackgroundTransparency = 1
defenseTeamLabel.TextColor3 = Color3.fromRGB(220, 180, 180)
defenseTeamLabel.TextXAlignment = Enum.TextXAlignment.Right
defenseTeamLabel.Font = Enum.Font.SourceSansSemibold
defenseTeamLabel.TextSize = 12
defenseTeamLabel.Text = "DEFENSE"
defenseTeamLabel.Parent = defenseFrame

local defenseIcon = Instance.new("TextLabel")
defenseIcon.Size = UDim2.new(0.55, 0, 0.5, 0)
defenseIcon.AnchorPoint = Vector2.new(1, 0)
defenseIcon.Position = UDim2.new(1, -12, 0.5, 0)
defenseIcon.BackgroundTransparency = 1
defenseIcon.TextColor3 = Color3.fromRGB(200, 160, 160)
defenseIcon.TextXAlignment = Enum.TextXAlignment.Right
defenseIcon.Font = Enum.Font.SourceSansSemibold
defenseIcon.TextSize = 11
defenseIcon.Text = "DEFENSIVE 🛡️"
defenseIcon.Parent = defenseFrame

-- VS divider
local vsFrame = Instance.new("Frame")
vsFrame.Size = UDim2.new(0, 60, 0, 30)
vsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
vsFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
vsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
vsFrame.BorderSizePixel = 0
vsFrame.Parent = scoreSection

local vsCorner = Instance.new("UICorner")
vsCorner.CornerRadius = UDim.new(0.5, 0)
vsCorner.Parent = vsFrame

local vsStroke = Instance.new("UIStroke")
vsStroke.Thickness = 2
vsStroke.Color = Color3.fromRGB(255, 255, 255)
vsStroke.Transparency = 0.8
vsStroke.Parent = vsFrame

local vsLabel = Instance.new("TextLabel")
vsLabel.Size = UDim2.new(1, 0, 1, 0)
vsLabel.BackgroundTransparency = 1
vsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
vsLabel.Font = Enum.Font.SourceSansBold
vsLabel.TextSize = 16
vsLabel.Text = "VS"
vsLabel.Parent = vsFrame

-- Bottom info section
local infoSection = Instance.new("Frame")
infoSection.Size = UDim2.new(1, -40, 0, 36)
infoSection.Position = UDim2.new(0, 20, 1, -44)
infoSection.BackgroundTransparency = 1
infoSection.Parent = container

-- Team indicator
local teamCard = Instance.new("Frame")
teamCard.Size = UDim2.new(0, 120, 1, 0)
teamCard.Position = UDim2.new(0, 0, 0, 0)
teamCard.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
teamCard.BackgroundTransparency = 0.3
teamCard.BorderSizePixel = 0
teamCard.Parent = infoSection

local teamCardCorner = Instance.new("UICorner")
teamCardCorner.CornerRadius = UDim.new(0, 10)
teamCardCorner.Parent = teamCard

local teamCardStroke = Instance.new("UIStroke")
teamCardStroke.Thickness = 2
teamCardStroke.Color = Color3.fromRGB(100, 100, 100)
teamCardStroke.Transparency = 0.5
teamCardStroke.Parent = teamCard

local teamDot = Instance.new("Frame")
teamDot.Size = UDim2.new(0, 8, 0, 8)
teamDot.Position = UDim2.new(0, 12, 0.5, -4)
teamDot.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
teamDot.BorderSizePixel = 0
teamDot.Parent = teamCard

local teamDotCorner = Instance.new("UICorner")
teamDotCorner.CornerRadius = UDim.new(0.5, 0)
teamDotCorner.Parent = teamDot

local teamName = Instance.new("TextLabel")
teamName.Size = UDim2.new(1, -28, 1, 0)
teamName.Position = UDim2.new(0, 28, 0, 0)
teamName.BackgroundTransparency = 1
teamName.TextColor3 = Color3.fromRGB(220, 220, 220)
teamName.TextXAlignment = Enum.TextXAlignment.Left
teamName.Font = Enum.Font.SourceSansBold
teamName.TextSize = 14
teamName.Text = "SPECTATOR"
teamName.Parent = teamCard

-- Timer display
local timerCard = Instance.new("Frame")
timerCard.Size = UDim2.new(0, 140, 1, 0)
timerCard.AnchorPoint = Vector2.new(1, 0)
timerCard.Position = UDim2.new(1, 0, 0, 0)
timerCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
timerCard.BackgroundTransparency = 0.3
timerCard.BorderSizePixel = 0
timerCard.Parent = infoSection

local timerCardCorner = Instance.new("UICorner")
timerCardCorner.CornerRadius = UDim.new(0, 10)
timerCardCorner.Parent = timerCard

local timerIcon = Instance.new("TextLabel")
timerIcon.Size = UDim2.new(0, 30, 1, 0)
timerIcon.Position = UDim2.new(0, 8, 0, 0)
timerIcon.BackgroundTransparency = 1
timerIcon.TextColor3 = Color3.fromRGB(180, 180, 180)
timerIcon.Font = Enum.Font.SourceSansSemibold
timerIcon.TextSize = 16
timerIcon.Text = "⏱"
timerIcon.Parent = timerCard

local timerText = Instance.new("TextLabel")
timerText.Size = UDim2.new(1, -38, 1, 0)
timerText.Position = UDim2.new(0, 38, 0, 0)
timerText.BackgroundTransparency = 1
timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
timerText.TextXAlignment = Enum.TextXAlignment.Center
timerText.Font = Enum.Font.SourceSansBold
timerText.TextSize = 18
timerText.Text = "0:00"
timerText.Parent = timerCard

-- Phase indicator
local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(0, 160, 1, 0)
phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
phaseLabel.Position = UDim2.new(0.5, 0, 0, 0)
phaseLabel.BackgroundTransparency = 1
phaseLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
phaseLabel.Font = Enum.Font.SourceSansSemibold
phaseLabel.TextSize = 13
phaseLabel.Text = "WAITING"
phaseLabel.Parent = infoSection

-- Enhanced toast notification
local toastFrame = Instance.new("Frame")
toastFrame.Size = UDim2.new(0, 400, 0, 42)
toastFrame.AnchorPoint = Vector2.new(0.5, 0)
toastFrame.Position = UDim2.new(0.5, 0, 0, 130)
toastFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
toastFrame.BackgroundTransparency = 0
toastFrame.BorderSizePixel = 0
toastFrame.Visible = false
toastFrame.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
toastCorner.Parent = toastFrame

local toastStroke = Instance.new("UIStroke")
toastStroke.Thickness = 2
toastStroke.Color = Color3.fromRGB(255, 200, 100)
toastStroke.Transparency = 0.3
toastStroke.Parent = toastFrame

local toastGradient = Instance.new("UIGradient")
toastGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180,180,180))
}
toastGradient.Rotation = 90
toastGradient.Parent = toastFrame

local toastText = Instance.new("TextLabel")
toastText.Size = UDim2.new(1, -20, 1, 0)
toastText.Position = UDim2.new(0, 10, 0, 0)
toastText.BackgroundTransparency = 1
toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
toastText.Font = Enum.Font.SourceSansBold
toastText.TextSize = 16
toastText.Text = ""
toastText.Parent = toastFrame

-- Arrow removed - no directional guidance

-- State variables
local currentState = "Lobby"
local scores = {A = 0, B = 0}
local roundTimeRemaining = nil
local roundPhase = nil
local objectiveTimeLimit = 60
local objectiveStartTime = 0
local isCarrier = false
local greenSpawnPos = nil
local redSpawnPos = nil

local function formatTime(s)
    if not s or s < 0 then return "--:--" end
    local m = math.floor(s/60)
    local sec = math.floor(s % 60)
    return string.format("%d:%02d", m, sec)
end

local function animateToast(text, duration, color)
    toastText.Text = text or ""
    toastFrame.Visible = text ~= nil and text ~= ""

    if toastFrame.Visible then
        -- Set color
        local toastColor = color or Color3.fromRGB(255, 200, 100)
        toastStroke.Color = toastColor

        -- Animate in
        toastFrame.Position = UDim2.new(0.5, 0, 0, 110)
        local tweenIn = TweenService:Create(
            toastFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, 0, 0, 130)}
        )
        tweenIn:Play()

        -- Schedule hide
        task.delay(duration or 2, function()
            local tweenOut = TweenService:Create(
                toastFrame,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = UDim2.new(0.5, 0, 0, 110)}
            )
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                toastFrame.Visible = false
            end)
        end)
    end
end

local function updatePanel()
    -- Update scores
    attackScoreLabel.Text = tostring(scores.A or 0)
    defenseScoreLabel.Text = tostring(scores.B or 0)

    -- Update team indicator
    local team = Players.LocalPlayer.Team
    if team then
        local teamColor = team.TeamColor.Color
        teamCard.BackgroundColor3 = teamColor:Lerp(Color3.new(0,0,0), 0.7)
        teamCardStroke.Color = teamColor
        teamDot.BackgroundColor3 = teamColor
        teamName.Text = string.upper(team.Name)

        -- Highlight active team score
        if team.Name == "Attack" or team.Name == "Green" then
            attackFrame.BackgroundTransparency = 0.5
            defenseFrame.BackgroundTransparency = 0.75
            attackGradient.Enabled = true
            defenseGradient.Enabled = false
        elseif team.Name == "Defense" or team.Name == "Red" then
            attackFrame.BackgroundTransparency = 0.75
            defenseFrame.BackgroundTransparency = 0.5
            attackGradient.Enabled = false
            defenseGradient.Enabled = true
        end
    else
        teamCard.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        teamCardStroke.Color = Color3.fromRGB(100, 100, 100)
        teamDot.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        teamName.Text = "SPECTATOR"
        attackFrame.BackgroundTransparency = 0.7
        defenseFrame.BackgroundTransparency = 0.7
        attackGradient.Enabled = false
        defenseGradient.Enabled = false
    end

    -- Update timer
    local remain = roundTimeRemaining
    if remain == nil and currentState == "Live" and objectiveStartTime > 0 then
        local elapsed = os.clock() - objectiveStartTime
        remain = math.max(0, objectiveTimeLimit - elapsed)
    end

    if remain then
        timerText.Text = formatTime(remain)
        -- Flash when low time
        if remain <= 10 then
            timerText.TextColor3 = Color3.fromRGB(255, 100, 100)
            timerIcon.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
            timerIcon.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    else
        timerText.Text = "--:--"
        timerText.TextColor3 = Color3.fromRGB(180, 180, 180)
        timerIcon.TextColor3 = Color3.fromRGB(150, 150, 150)
    end

    -- Update phase (don't override if already set by message in onRoundChanged)
    local phase = roundPhase or currentState
    if phase == "Lobby" then
        -- Keep existing text if it's a special message, otherwise show default
        if not phaseLabel.Text:find("WAITING") and not phaseLabel.Text:find("STARTING") then
            phaseLabel.Text = "🏠 LOBBY"
            phaseLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    elseif phase == "Live" or phase == "InProgress" then
        phaseLabel.Text = "🎮 LIVE"
        phaseLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    elseif phase == "Intermission" then
        phaseLabel.Text = "⏸ BREAK"
        phaseLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    elseif phase == "Prep" then
        phaseLabel.Text = "⏱ GET READY"
        phaseLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    elseif phase == "End" then
        phaseLabel.Text = "🏆 ROUND OVER"
        phaseLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    elseif phase == "MatchComplete" then
        phaseLabel.Text = "🎯 MATCH COMPLETE"
        phaseLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    else
        if phase and phase ~= "" then
            phaseLabel.Text = string.upper(phase)
            phaseLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end
end

local function onRoundChanged(payload)
    scores = payload and payload.scores or scores
    currentState = payload and payload.state or currentState
    roundTimeRemaining = payload and payload.timeRemaining or nil
    roundPhase = payload and payload.phase or nil

    -- Handle lobby messages
    if payload and payload.message then
        -- Update phase label with the message (e.g., "Waiting for players..." or "Match starting in...")
        phaseLabel.Text = string.upper(payload.message)
        if payload.message:find("Waiting") then
            phaseLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        elseif payload.message:find("starting") then
            phaseLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
    end

    updatePanel()
end

local function onObjectiveEvent(payload)
    if payload.type == "ObjectiveSpawned" then
        objectiveTimeLimit = payload.timeLimit or 60
        objectiveStartTime = os.clock()
        greenSpawnPos = payload.greenSpawn or (workspace:FindFirstChild("GreenSpawn") and workspace.GreenSpawn.Position) or greenSpawnPos
        redSpawnPos = payload.redSpawn or (workspace:FindFirstChild("RedSpawn") and workspace.RedSpawn.Position) or redSpawnPos
        animateToast("🎯 OBJECTIVE SPAWNED", 2, Color3.fromRGB(100, 255, 100))
    elseif payload.type == "ObjectiveDelivered" then
        isCarrier = false
        animateToast("✅ OBJECTIVE DELIVERED", 2.5, Color3.fromRGB(100, 255, 100))
    elseif payload.type == "TimeUp" then
        animateToast("⏰ TIME'S UP", 2, Color3.fromRGB(255, 100, 100))
    elseif payload.type == "Carry" then
        isCarrier = (payload.by == Players.LocalPlayer.UserId)
        if isCarrier then
            local t = Players.LocalPlayer.Team
            if t and t.Name == "Red" then
                animateToast("💎 CARRYING - GO TO RED SPAWN", 3, Color3.fromRGB(255, 220, 50))
            else
                animateToast("💎 CARRYING - AVOID RED TEAM", 3, Color3.fromRGB(255, 220, 50))
            end
        else
            local who = Players:GetPlayerByUserId(payload.by)
            if who and Players.LocalPlayer.Team and who.Team == Players.LocalPlayer.Team then
                animateToast("👥 ALLY HAS OBJECTIVE", 1.5, Color3.fromRGB(100, 200, 255))
            else
                animateToast("⚠️ ENEMY HAS OBJECTIVE", 1.5, Color3.fromRGB(255, 100, 100))
            end
        end
    elseif payload.type == "Dropped" then
        if payload.by == Players.LocalPlayer.UserId then
            isCarrier = false
        end
        animateToast("📦 OBJECTIVE DROPPED", 1.5, Color3.fromRGB(200, 200, 100))
    elseif payload.type == "Stolen" then
        if payload.by == Players.LocalPlayer.UserId then
            isCarrier = true
            animateToast("⚡ STOLEN - RUN!", 2.5, Color3.fromRGB(255, 100, 50))
        elseif payload.from == Players.LocalPlayer.UserId then
            isCarrier = false
            animateToast("❌ STOLEN FROM YOU", 2, Color3.fromRGB(255, 50, 50))
        else
            animateToast("🔄 OBJECTIVE STOLEN", 2, Color3.fromRGB(255, 150, 50))
        end
    end
end

if Events.RoundChanged then Events.RoundChanged.OnClientEvent:Connect(onRoundChanged) end
if Events.Objective then Events.Objective.OnClientEvent:Connect(onObjectiveEvent) end

-- React to team changes
Players.LocalPlayer:GetPropertyChangedSignal("Team"):Connect(updatePanel)

-- Update panel
RunService.RenderStepped:Connect(function()
    updatePanel()
end)