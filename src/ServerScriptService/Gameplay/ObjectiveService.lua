-- Objective: spawn, pickup, steal, carry-follow, deliver at Green spawn

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Simple config to avoid ConfigLoader dependency
local Config = {
    OBJECTIVE = {
        Size = Vector3.new(3, 3, 3),
        Color = Color3.fromRGB(255, 255, 0),
        SpawnDistance = 30,
        TimeLimit = 60,
    },
    EXTRACT = {
        Size = Vector3.new(10, 1, 10),
        Color = Color3.fromRGB(120, 200, 255),
    },
}

-- Store event connections to prevent memory leaks
local connections = {}

-- Clean up function to disconnect all stored connections
local function cleanupConnections()
    for _, connection in ipairs(connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    connections = {}
end

local ObjectiveService = {}
local objectiveModel = nil
local carrier = nil
local extractZone = nil
local roundStartTime = nil
local redSpawnPosition = nil
local greenSpawnPosition = nil
local followConnection = nil
local objectivePrompt = nil

local function getOrCreatePart(name, size, position, color)
    local p = workspace:FindFirstChild(name)
    if not p then
        p = Instance.new("Part")
        p.Name = name
        p.Anchored = true
        p.CanCollide = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = workspace
    end
    p.Size = size
    p.Position = position
    if color then p.Color = color end
    return p
end

-- Input validation functions
local function validatePlayerState(player)
    if not player then return false, "Player is nil" end
    if not player.Parent then return false, "Player is not in game" end
    return true
end

local function validateObjectiveEventPayload(payload)
    if not payload then return false, "Payload is nil" end
    if typeof(payload) ~= "table" then return false, "Payload is not a table" end

    if not payload.type then
        return false, "Missing required field: type"
    end

    if typeof(payload.type) ~= "string" then
        return false, "Invalid type field"
    end

    local validTypes = { "Pickup", "Drop" }
    local isValidType = false
    for _, validType in ipairs(validTypes) do
        if payload.type == validType then
            isValidType = true
            break
        end
    end

    if not isValidType then
        return false, "Invalid event type: " .. payload.type
    end

    return true
end

-- Get events with error handling
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
        Objective = ensure("ObjectiveEvent", "RemoteEvent"),
    }
end

local Events = getEvents()

-- Function to get random position away from green spawn
local function clampToBaseplate(pos, objHalfY)
    local base = workspace:FindFirstChild("Baseplate")
    if not base or not base:IsA("BasePart") then
        return pos -- no baseplate to clamp against
    end
    local margin = 5
    local half = base.Size * 0.5
    local minX = base.Position.X - half.X + margin
    local maxX = base.Position.X + half.X - margin
    local minZ = base.Position.Z - half.Z + margin
    local maxZ = base.Position.Z + half.Z - margin
    local yTop = base.Position.Y + half.Y + (objHalfY or 1.5)
    local x = math.clamp(pos.X, minX, maxX)
    local z = math.clamp(pos.Z, minZ, maxZ)
    return Vector3.new(x, yTop, z)
end

local function getRandomObjectivePosition(greenSpawnPos, distance, objSize)
    local angle = math.random() * math.pi * 2
    local x = greenSpawnPos.X + math.cos(angle) * distance
    local z = greenSpawnPos.Z + math.sin(angle) * distance
    local y = greenSpawnPos.Y + (objSize and objSize.Y or 3) * 0.5
    local candidate = Vector3.new(x, y, z)
    return clampToBaseplate(candidate, (objSize and objSize.Y or 3) * 0.5)
end

local function stopFollowing()
    if followConnection and followConnection.Connected then
        followConnection:Disconnect()
    end
    followConnection = nil
end

local function startFollowing(plr)
    stopFollowing()
    if not objectiveModel or not plr or not plr.Character then return end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    objectiveModel.Anchored = true
    objectiveModel.CanCollide = false
    local offset = Vector3.new(0, 4, 0)
    followConnection = RunService.Heartbeat:Connect(function()
        if not carrier or not carrier.Character or not carrier.Character:FindFirstChild("HumanoidRootPart") then
            stopFollowing()
            return
        end
        local cframe = carrier.Character.HumanoidRootPart.CFrame + offset
        objectiveModel.CFrame = cframe
    end)
end

function ObjectiveService.StartRound(redSpawnPos)
    -- Stop following and clear carrier from previous round
    stopFollowing()
    carrier = nil

    -- Destroy existing objective model
    if objectiveModel then
        objectiveModel:Destroy()
        objectiveModel = nil
    end
    objectivePrompt = nil

    -- Set spawn positions for this round
    redSpawnPosition = redSpawnPos
    roundStartTime = nil  -- Don't start timer yet, wait for StartTimer()

    print("[ObjectiveService] StartRound called with RedSpawn:", redSpawnPos)

    -- Find green spawn position (should be at (200, 1.5, 200))
    local greenSpawn = workspace:FindFirstChild("GreenSpawn")
    local greenPos = greenSpawn and greenSpawn.Position or Vector3.new(200, 1.5, 200)
    greenSpawnPosition = greenPos

    -- Calculate random objective position
    local objSize = Config.OBJECTIVE.Size or Vector3.new(3,3,3)
    local objectivePos = getRandomObjectivePosition(greenPos, Config.OBJECTIVE.SpawnDistance, objSize)

    -- positions computed for spawn

    -- Create objective - make it bright and visible
    local objColor = Config.OBJECTIVE.Color or Color3.fromRGB(255, 255, 0)

    -- Always create a simple visible box for now
    objectiveModel = getOrCreatePart("ObjectiveBox", objSize, objectivePos, objColor)
    
    -- Make it very visible
    objectiveModel.Material = Enum.Material.Neon
    objectiveModel.BrickColor = BrickColor.new("Bright yellow")

    -- Make it glow and more visible
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(255, 255, 0)
    glow.Brightness = 3
    glow.Range = 25
    glow.Parent = objectiveModel

    -- Add a pulsing effect
    local tweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = tweenService:Create(objectiveModel, tweenInfo, {Transparency = 0.2})
    tween:Play()

    -- Add surface light for even more visibility
    local surfaceLight = Instance.new("SurfaceLight")
    surfaceLight.Color = Color3.fromRGB(255, 255, 0)
    surfaceLight.Brightness = 5
    surfaceLight.Range = 15
    surfaceLight.Parent = objectiveModel


    -- Add a beam effect to make it even more visible
    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    beam.Width0 = 2
    beam.Width1 = 2
    beam.Parent = objectiveModel

    -- Add some particle effects
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    particles.Size = NumberSequence.new(0.5, 1)
    particles.Lifetime = NumberRange.new(2, 4)
    particles.Rate = 20
    particles.Speed = NumberRange.new(2, 5)
    particles.Parent = objectiveModel


    -- Add a simple ProximityPrompt to allow pickup (Red team only)
    if objectiveModel:FindFirstChild("PickupPrompt") then
        objectiveModel.PickupPrompt:Destroy()
    end
    objectivePrompt = Instance.new("ProximityPrompt")
    objectivePrompt.Name = "PickupPrompt"
    objectivePrompt.ActionText = "Pick Up"
    objectivePrompt.ObjectText = "Objective"
    objectivePrompt.HoldDuration = 0.25
    objectivePrompt.RequiresLineOfSight = false
    objectivePrompt.MaxActivationDistance = 12
    objectivePrompt.Parent = objectiveModel

    table.insert(connections, objectivePrompt.Triggered:Connect(function(plr)
        if not plr or not plr.Team then return end

        -- If current carrier uses the prompt, drop it
        if carrier == plr then
            stopFollowing()

            -- Drop objective at player's current position (not random spawn)
            if objectiveModel and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local dropPos = plr.Character.HumanoidRootPart.Position + Vector3.new(0, 2, 3)
                objectiveModel.Position = dropPos
                objectiveModel.Anchored = true
                objectiveModel.CanCollide = false
                objectiveModel.Transparency = 0
                if objectivePrompt then objectivePrompt.ActionText = "Pick Up" end
                for _, child in ipairs(objectiveModel:GetChildren()) do
                    if child:IsA("ParticleEmitter") then child.Enabled = true end
                    if child:IsA("Light") then child.Enabled = true end
                    if child:IsA("Beam") then child.Enabled = true end
                end
            end

            carrier = nil
            Events.Objective:FireAllClients({ type = "Dropped", by = plr.UserId })
            return
        end

        if not carrier then
            -- Ground pickup: allow both teams
            carrier = plr
            print("[ObjectiveService] Player", plr.Name, "picked up objective. Team:", plr.Team and plr.Team.Name or "No team")
            startFollowing(plr)
            objectivePrompt.ActionText = "Drop/Steal"
            Events.Objective:FireAllClients({ type = "Carry", by = plr.UserId })
            return
        end

        -- Steal: allow opposing team to take from current carrier
        if carrier and carrier.Team and plr.Team and carrier.Team ~= plr.Team then
            local prev = carrier
            carrier = plr
            startFollowing(plr)
            objectivePrompt.ActionText = "Drop/Steal"
            Events.Objective:FireAllClients({ type = "Stolen", from = prev.UserId, by = plr.UserId })
        end
    end))

    -- Broadcast objective spawn to all clients (include Green spawn for guidance)
    Events.Objective:FireAllClients({
        type = "ObjectiveSpawned",
        position = objectivePos,
        timeLimit = Config.OBJECTIVE.TimeLimit,
        greenSpawn = greenPos,
        redSpawn = redSpawnPos
    })
end

function ObjectiveService.GetTimeRemaining()
    if not roundStartTime then return Config.OBJECTIVE.TimeLimit end  -- Return full time if not started
    local elapsed = os.clock() - roundStartTime
    return math.max(0, Config.OBJECTIVE.TimeLimit - elapsed)
end

function ObjectiveService.Tick()
    print("[ObjectiveService] Tick called - Carrier:", carrier and carrier.Name or "nil", "RedSpawn:", redSpawnPosition and "set" or "nil")

    -- Check time limit first
    local timeRemaining = ObjectiveService.GetTimeRemaining()
    if roundStartTime and timeRemaining <= 0 then  -- Only check time if timer started
        print("[ObjectiveService] Time up! Returning DefenseWin")
        Events.Objective:FireAllClients({ type = "TimeUp", winner = "Defense" })
        return "DefenseWin"
    end

    -- Check if red player with objective is at red spawn
    if carrier and redSpawnPosition then
        print("[ObjectiveService] Carrier exists:", carrier.Name, "Team:", carrier.Team and carrier.Team.Name or "No team")

        -- Check if carrier is still valid
        local isCarrierValid = validatePlayerState(carrier)
        if not isCarrierValid then
            print("[ObjectiveService] Carrier invalid, dropping")
            carrier = nil
            Events.Objective:FireAllClients({ type="Dropped", by=0 })
            return nil
        end

        -- Check if carrier is red team
        if carrier.Team and carrier.Team.Name == "Red" then
            print("[ObjectiveService] Red carrier detected")
            -- Check if carrier's character exists and is at RED spawn (main win condition)
            if carrier.Character and carrier.Character:FindFirstChild("HumanoidRootPart") and redSpawnPosition then
                local hrp = carrier.Character.HumanoidRootPart
                local distanceToRedSpawn = (hrp.Position - redSpawnPosition).Magnitude

                print("[ObjectiveService] Red carrier distance to spawn:", distanceToRedSpawn, "Position:", hrp.Position, "Red spawn:", redSpawnPosition)
                if distanceToRedSpawn < 15 then  -- Increased from 10 to 15
                    print("[ObjectiveService] Red team delivered! Distance:", distanceToRedSpawn)
                    Events.Objective:FireAllClients({
                        type = "ObjectiveDelivered",
                        by = carrier.UserId,
                        winner = "Attack"
                    })
                    stopFollowing()
                    carrier = nil
                    return "AttackWin"
                end
            end

            if not (carrier.Character and carrier.Character:FindFirstChild("HumanoidRootPart")) then
                -- Carrier died or lost character: respawn objective at random location
                carrier = nil
                stopFollowing()
                if objectiveModel then
                    local objSize = Config.OBJECTIVE.Size or Vector3.new(3,3,3)
                    local randomPos = getRandomObjectivePosition(greenSpawnPosition, Config.OBJECTIVE.SpawnDistance, objSize)
                    objectiveModel.Position = randomPos
                    objectiveModel.Transparency = 0
                    if objectivePrompt then objectivePrompt.ActionText = "Pick Up" end
                    for _, child in ipairs(objectiveModel:GetChildren()) do
                        if child:IsA("ParticleEmitter") then child.Enabled = true end
                        if child:IsA("Light") then child.Enabled = true end
                        if child:IsA("Beam") then child.Enabled = true end
                    end
                end
                Events.Objective:FireAllClients({ type="Dropped", by=0 })
            end
        end
    end

    return nil
end

-- Event handling with validation
table.insert(connections, Events.Objective.OnServerEvent:Connect(function(plr, payload)
    -- Validate player and payload
    local isPlayerValid, playerError = validatePlayerState(plr)
    if not isPlayerValid then
        warn(string.format("[ObjectiveService] Invalid player state: %s (UserId: %s)", playerError, plr.UserId or "unknown"))
        return
    end

    local isPayloadValid, payloadError = validateObjectiveEventPayload(payload)
    if not isPayloadValid then
        warn(string.format("[ObjectiveService] Invalid payload: %s (UserId: %s)", payloadError, plr.UserId))
        return
    end

    -- Process objective events
    if payload.type == "Pickup" and not carrier then
        carrier = plr
        Events.Objective:FireAllClients({ type="Carry", by=plr.UserId })
    elseif payload.type == "Drop" and carrier == plr then
        carrier = nil
        Events.Objective:FireAllClients({ type="Dropped", by=plr.UserId })
    end
end))

-- Start the actual round timer (called when live phase begins)
function ObjectiveService.StartTimer()
    roundStartTime = os.clock()
end

-- Function to clean up objective when round ends
function ObjectiveService.CleanupObjective()
    -- Stop following if active
    stopFollowing()

    -- Clear carrier
    carrier = nil

    -- Destroy objective model
    if objectiveModel then
        objectiveModel:Destroy()
        objectiveModel = nil
    end

    -- Clear prompt reference
    objectivePrompt = nil

    -- Clear spawn positions
    redSpawnPosition = nil
    greenSpawnPosition = nil
    roundStartTime = nil
end

-- Cleanup on game shutdown
game:BindToClose(function()
    cleanupConnections()
    ObjectiveService.CleanupObjective()
end)

return ObjectiveService
