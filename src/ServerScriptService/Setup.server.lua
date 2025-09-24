-- Game bootstrap: teams, baseplate, spawns, and team assignment
local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Simple config - no complex loading to avoid issues
local Config = {
    forceR6 = true,
    baseplate = {
        size = Vector3.new(100, 1, 100),  -- Smaller for testing
        color = Color3.fromRGB(163, 162, 165),
        name = "Baseplate"
    },
    spawns = {
        inset = 10,
        size = Vector3.new(8, 1, 8),
        forceFieldDuration = 0
    },
    teams = {
        red = { name = "Red", brickColor = "Really red" },
        green = { name = "Green", brickColor = "Lime green" },
        autoAssignable = false,
        assignment = "alternate",
    },
}


-- Global baseplate size for use in other functions
local BASEPLATE_SIZE = Config.baseplate.size

if Config.forceR6 then
    -- Try the correct way to set R6 in newer Roblox versions
    pcall(function()
        -- Try different methods for R6 enforcement
        if StarterPlayer:FindFirstChild("CharacterRigType") then
            StarterPlayer.CharacterRigType = Enum.HumanoidRigType.R6
        else
            -- Alternative method for older versions
            local humanoidDescription = Instance.new("HumanoidDescription")
            humanoidDescription.RigType = Enum.HumanoidRigType.R6
            StarterPlayer.HumanoidDescription = humanoidDescription
        end
    end)
end

-- Disable chat at the server level to prevent client-side ChatScript errors
pcall(function()
    local StarterGui = game:GetService("StarterGui")
    -- Set server-wide chat settings
    StarterGui.ShowDevelopmentGui = false

    -- Try to disable chat service if available
    local TextChatService = game:GetService("TextChatService")
    if TextChatService then
        TextChatService.ChatVersion = Enum.ChatVersion.LegacyChatService
    end
end)

-- Simple team creation
local function createTeam(name, brickColor)
    local team = Instance.new("Team")
    team.Name = name
    team.TeamColor = BrickColor.new(brickColor)
    team.AutoAssignable = false
    team.Parent = TeamsService
    return team
end

local redTeam = createTeam("Red", "Really red")
local greenTeam = createTeam("Green", "Lime green")

-- Simple baseplate creation
local function createBaseplate()
    -- Remove existing baseplate if it exists
    local existing = Workspace:FindFirstChild("Baseplate")
    if existing then
        existing:Destroy()
    end

    -- Use the global baseplate size

    local bp = Instance.new("Part")
    bp.Name = "Baseplate"
    bp.Anchored = true
    bp.Size = BASEPLATE_SIZE
    bp.Position = Vector3.new(0, 0.5, 0)
    bp.TopSurface = Enum.SurfaceType.Smooth
    bp.BottomSurface = Enum.SurfaceType.Smooth
    bp.Color = Color3.fromRGB(163, 162, 165)
    bp.Parent = Workspace

    return bp
end

local baseplate = createBaseplate()

-- Simple spawn creation
local function createSpawn(name, team, position)
    -- Remove existing spawn if it exists
    local existing = Workspace:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = name
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Neutral = false
    spawn.Duration = 0 -- No forcefield
    spawn.AllowTeamChangeOnTouch = false
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.TeamColor = team.TeamColor
    spawn.BrickColor = team.TeamColor
    spawn.Color = team.TeamColor.Color
    spawn.CFrame = CFrame.new(position)
    spawn.Parent = Workspace

    return spawn
end

-- Simple spawn positioning - adjusted for smaller baseplate
local halfSize = BASEPLATE_SIZE.X * 0.4  -- 40% from center
local spawnY = baseplate.Position.Y + (BASEPLATE_SIZE.Y * 0.5) + 0.5

local redPos = Vector3.new(-halfSize, spawnY, -halfSize)   -- Left side
local greenPos = Vector3.new(halfSize, spawnY, halfSize)   -- Right side

local redSpawn = createSpawn("RedSpawn", redTeam, redPos)
local greenSpawn = createSpawn("GreenSpawn", greenTeam, greenPos)

-- Disable any other spawn locations that might exist in the place/template
for _, inst in ipairs(Workspace:GetDescendants()) do
    if inst:IsA("SpawnLocation") and inst.Name ~= "RedSpawn" and inst.Name ~= "GreenSpawn" then
        pcall(function() inst.Enabled = false end)
        inst.Neutral = false
    end
end

-- Simple team assignment: alternate between teams
local function teamCounts()
    local r, g = 0, 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Team == redTeam then r += 1 elseif p.Team == greenTeam then g += 1 end
    end
    return r, g
end

local nextTeamIsRed = true
local function assignPlayerToTeam(player: Player)
    local rCount, gCount = teamCounts()
    local team
    if rCount == gCount then
        team = nextTeamIsRed and redTeam or greenTeam
        nextTeamIsRed = not nextTeamIsRed
    else
        team = (rCount < gCount) and redTeam or greenTeam
    end
    player.Team = team
    player.Neutral = false
    pcall(function() player:LoadCharacter() end)
end

for _, plr in ipairs(Players:GetPlayers()) do assignPlayerToTeam(plr) end
Players.PlayerAdded:Connect(function(plr)
    task.wait(0.2)
    assignPlayerToTeam(plr)
end)
