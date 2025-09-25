-- Objective: spawn, pickup, steal, carry-follow, deliver at Green spawn

local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")
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
        -- Asset id for briefcase model
        ModelAssetId = 530795465,
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
local objectiveModel = nil -- Model or BasePart root for the objective
local objectivePart = nil -- BasePart used for prompt/effects (PrimaryPart or first BasePart)
local objectiveUsingFallback = false -- True if using simple cube instead of asset
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

-- Resolve the base part for a model (PrimaryPart or first BasePart descendant)
local function getModelBasePart(inst: Instance): BasePart?
    if not inst then return nil end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
    elseif inst:IsA("Tool") then
        local h = inst:FindFirstChild("Handle")
        if h and h:IsA("BasePart") then return h end
        for _, d in ipairs(inst:GetDescendants()) do
            if d.Name == "Handle" and d:IsA("BasePart") then return d end
            if d:IsA("BasePart") then return d end
        end
    elseif inst:IsA("BasePart") then
        return inst
    end
    return nil
end

-- Anchor/collide settings across model or part
local function setObjectivePhysics(inst: Instance, anchored: boolean, canCollide: boolean)
    if not inst then return end
    if inst:IsA("BasePart") then
        inst.Anchored = anchored
        inst.CanCollide = canCollide
    elseif inst:IsA("Model") or inst:IsA("Tool") then
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = anchored
                d.CanCollide = canCollide
            end
        end
    end
end

-- Move helpers for model/part
local function setObjectiveCFrame(inst: Instance, cf: CFrame)
    if not inst then return end
    if inst:IsA("BasePart") then
        inst.CFrame = cf
    elseif inst:IsA("Model") then
        inst:PivotTo(cf)
    elseif inst:IsA("Tool") then
        local bp = getModelBasePart(inst)
        if bp then bp.CFrame = cf end
    end
end

local function setObjectivePosition(inst: Instance, pos: Vector3)
    if not inst then return end
    if inst:IsA("BasePart") then
        inst.Position = pos
    elseif inst:IsA("Model") then
        local bp = getModelBasePart(inst)
        if bp then
            local current = bp.CFrame
            setObjectiveCFrame(inst, CFrame.new(pos) * (current - current.Position))
        else
            inst:PivotTo(CFrame.new(pos))
        end
    elseif inst:IsA("Tool") then
        local bp = getModelBasePart(inst)
        if bp then bp.Position = pos end
    end
end

-- Toggle all visual effects under the objective (Lights, Beams, ParticleEmitters)
local function setEffectsEnabled(inst: Instance, enabled: boolean)
    if not inst then return end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ParticleEmitter") then d.Enabled = enabled end
        if d:IsA("Beam") then d.Enabled = enabled end
        if d:IsA("Light") then d.Enabled = enabled end
    end
end

-- Load the briefcase model or fallback to a simple part
local function createObjectiveInstance(name: string, size: Vector3, position: Vector3, color: Color3)
    -- 1) Prefer a prebundled model placed in the experience for reliability
    local function findBundled()
        local modelName = (Config.OBJECTIVE and Config.OBJECTIVE.ModelName) or "Briefcase"
        local idName = tostring((Config.OBJECTIVE and Config.OBJECTIVE.ModelAssetId) or "")

        local function resolveCandidate(inst)
            if not inst then return nil end
            if inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Tool") then return inst end
            if inst:IsA("Folder") then
                for _, child in ipairs(inst:GetChildren()) do
                    if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Tool") then
                        return child
                    end
                end
            end
            return nil
        end

        -- First, prefer explicit Assets folders
        local rpAssets = ReplicatedStorage:FindFirstChild("Assets")
        if rpAssets then
            -- Prefer exact name matches within the folder
            local candidates = { modelName, idName, modelName .. ".rbxm", modelName .. ".rbxmx" }
            for _, nm in ipairs(candidates) do
                if nm and nm ~= "" then
                    local inst = rpAssets:FindFirstChild(nm)
                    local resolved = resolveCandidate(inst)
                    if resolved then return resolved end
                end
            end
            -- Otherwise, first usable child
            for _, child in ipairs(rpAssets:GetChildren()) do
                local resolved = resolveCandidate(child)
                if resolved then
                    print("[ObjectiveService] Using first available asset in", rpAssets:GetFullName(), "->", child.Name)
                    return resolved
                end
            end
        end

        local ssAssets = ServerStorage:FindFirstChild("Assets")
        if ssAssets then
            local candidates = { modelName, idName, modelName .. ".rbxm", modelName .. ".rbxmx" }
            for _, nm in ipairs(candidates) do
                if nm and nm ~= "" then
                    local inst = ssAssets:FindFirstChild(nm)
                    local resolved = resolveCandidate(inst)
                    if resolved then return resolved end
                end
            end
            for _, child in ipairs(ssAssets:GetChildren()) do
                local resolved = resolveCandidate(child)
                if resolved then
                    print("[ObjectiveService] Using first available asset in", ssAssets:GetFullName(), "->", child.Name)
                    return resolved
                end
            end
        end

        -- Last resort: scan top-level services
        for _, loc in ipairs({ ReplicatedStorage, ServerStorage }) do
            for _, child in ipairs(loc:GetChildren()) do
                local resolved = resolveCandidate(child)
                if resolved then return resolved end
            end
        end

        return nil
    end

    -- Try to find bundled asset, allowing a short grace period for Rojo to sync
    -- Debug: list children under ReplicatedStorage/Assets to help diagnose
    do
        local ra = ReplicatedStorage:FindFirstChild("Assets")
        if ra then
            local names = {}
            for _, ch in ipairs(ra:GetChildren()) do
                table.insert(names, string.format("%s(%s)", ch.Name, ch.ClassName))
            end
            print("[ObjectiveService] ReplicatedStorage.Assets children:", table.concat(names, ", "))
        else
            print("[ObjectiveService] ReplicatedStorage.Assets not found at spawn time")
        end
    end

    local bundled = findBundled()
    if not bundled then
        print("[ObjectiveService] No bundled objective found yet; waiting for Rojo sync...")
        for _ = 1, 20 do -- up to ~5 seconds (20 * 0.25)
            task.wait(0.25)
            bundled = findBundled()
            if bundled then break end
        end
    end
    if bundled then
        local clone = bundled:Clone()
        clone.Name = name
        clone.Parent = workspace
        local bp = getModelBasePart(clone) or (clone:IsA("BasePart") and clone)
        if bp then
            if clone:IsA("Model") then clone:PivotTo(CFrame.new(position)) else bp.Position = position end
            objectiveModel = clone
            objectivePart = bp
            objectiveUsingFallback = false
            setObjectivePhysics(objectiveModel, true, false)
            print("[ObjectiveService] Spawned bundled objective model:", bundled:GetFullName(), "(type:", bundled.ClassName .. ")")
            return objectiveModel
        else
            clone:Destroy()
        end
    end

    print("[ObjectiveService] Bundled asset not found; attempting InsertService as fallback")
    local assetId = Config.OBJECTIVE.ModelAssetId
    local modelInstance: Instance? = nil
    if typeof(assetId) == "number" and assetId > 0 then
        local ok, asset = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        if ok and asset and asset:IsA("Model") then
            -- Some assets load as a container Model with children; pick first child if single child
            local children = asset:GetChildren()
            if #children == 1 and children[1]:IsA("Model") then
                modelInstance = children[1]
                modelInstance.Parent = workspace
                asset:Destroy()
            else
                modelInstance = asset
                modelInstance.Parent = workspace
            end
            modelInstance.Name = name
            -- Place near desired position
            local base = getModelBasePart(modelInstance)
            if base then
                modelInstance:PivotTo(CFrame.new(position))
                print("[ObjectiveService] Loaded asset model:", assetId)
            else
                -- No parts? Fallback to simple part
                modelInstance:Destroy()
                modelInstance = nil
            end
        else
            warn("[ObjectiveService] InsertService.LoadAsset failed or returned non-Model for asset:", assetId, ok and (asset and asset.ClassName or "nil") or "pcall failed")
        end
    end

    if modelInstance then
        objectiveModel = modelInstance
        objectivePart = getModelBasePart(modelInstance)
        setObjectivePhysics(objectiveModel, true, false)
        objectiveUsingFallback = false
        return objectiveModel
    else
        -- Fallback: neon box
        objectiveModel = getOrCreatePart(name, size, position, color)
        objectivePart = objectiveModel
        objectiveUsingFallback = true
        print("[ObjectiveService] Using fallback cube for objective")
        return objectiveModel
    end
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
    setObjectivePhysics(objectiveModel, true, false)
    local offset = Vector3.new(0, 4, 0)
    followConnection = RunService.Heartbeat:Connect(function()
        if not carrier or not carrier.Character or not carrier.Character:FindFirstChild("HumanoidRootPart") then
            stopFollowing()
            return
        end
        local cframe = carrier.Character.HumanoidRootPart.CFrame + offset
        setObjectiveCFrame(objectiveModel, cframe)
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
    objectivePart = nil
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

    -- Create objective - prefer model asset (briefcase), fallback to bright box
    local objColor = Config.OBJECTIVE.Color or Color3.fromRGB(255, 255, 0)
    createObjectiveInstance("ObjectiveBox", objSize, objectivePos, objColor)
    
    -- Make it very visible (only override material if using fallback cube)
    if objectiveUsingFallback and objectivePart and objectivePart:IsA("BasePart") then
        objectivePart.Material = Enum.Material.Neon
        objectivePart.BrickColor = BrickColor.new("Bright yellow")
    end

    -- Make it glow and more visible
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(255, 255, 0)
    glow.Brightness = 3
    glow.Range = 25
    glow.Parent = objectivePart or objectiveModel

    -- Add a pulsing effect
    local tweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = tweenService:Create(objectivePart or objectiveModel, tweenInfo, {Transparency = 0.2})
    tween:Play()

    -- Add surface light for even more visibility
    local surfaceLight = Instance.new("SurfaceLight")
    surfaceLight.Color = Color3.fromRGB(255, 255, 0)
    surfaceLight.Brightness = 5
    surfaceLight.Range = 15
    surfaceLight.Parent = objectivePart or objectiveModel


    -- Add a beam effect to make it even more visible
    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    beam.Width0 = 2
    beam.Width1 = 2
    beam.Parent = objectivePart or objectiveModel

    -- Add some particle effects
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    particles.Size = NumberSequence.new(0.5, 1)
    particles.Lifetime = NumberRange.new(2, 4)
    particles.Rate = 20
    particles.Speed = NumberRange.new(2, 5)
    particles.Parent = objectivePart or objectiveModel


    -- Add a simple ProximityPrompt to allow pickup (Red team only)
    local promptParent = objectivePart or objectiveModel
    if promptParent:FindFirstChild("PickupPrompt") then
        promptParent.PickupPrompt:Destroy()
    end
    objectivePrompt = Instance.new("ProximityPrompt")
    objectivePrompt.Name = "PickupPrompt"
    objectivePrompt.ActionText = "Pick Up"
    objectivePrompt.ObjectText = "Objective"
    objectivePrompt.HoldDuration = 0.25
    objectivePrompt.RequiresLineOfSight = false
    objectivePrompt.MaxActivationDistance = 12
    objectivePrompt.Parent = promptParent

    table.insert(connections, objectivePrompt.Triggered:Connect(function(plr)
        if not plr or not plr.Team then return end

        -- If current carrier uses the prompt, drop it
        if carrier == plr then
            stopFollowing()

            -- Drop objective at player's current position (not random spawn)
            if objectiveModel and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local dropPos = plr.Character.HumanoidRootPart.Position + Vector3.new(0, 2, 3)
                setObjectivePosition(objectiveModel, dropPos)
                setObjectivePhysics(objectiveModel, true, false)
                if objectivePart and objectivePart:IsA("BasePart") then
                    objectivePart.Transparency = 0
                end
                if objectivePrompt then objectivePrompt.ActionText = "Pick Up" end
                setEffectsEnabled(objectiveModel, true)
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
                    setObjectivePosition(objectiveModel, randomPos)
                    if objectivePart and objectivePart:IsA("BasePart") then
                        objectivePart.Transparency = 0
                    end
                    if objectivePrompt then objectivePrompt.ActionText = "Pick Up" end
                    setEffectsEnabled(objectiveModel, true)
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
    objectivePart = nil

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
