-- ConstructionService: handles server-side construction generation
-- Responsibility: listen for build requests and spawn a simple defensive box

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events
do
    local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild("Net"):WaitForChild("Events")) end)
    if ok and mod then Events = mod else
        -- Fallback to Remotes folder if Net.Events is unavailable
        local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
        folder.Name = "Remotes"
        folder.Parent = ReplicatedStorage
        local function ensure(name, className)
            local obj = folder:FindFirstChild(name)
            if not obj then obj = Instance.new(className) obj.Name = name obj.Parent = folder end
            return obj
        end
        Events = { Construction = ensure("ConstructionRequest", "RemoteEvent") }
    end
end

local ConstructionService = {}

-- Simple, configurable defaults (kept local to avoid broad config edits)
local DEFAULTS = {
    wallHeight = 12,
    wallThickness = 2,
    boxInnerSize = 24, -- inner square size between opposite walls
    color = Color3.fromRGB(120, 170, 120),
    cooldownSec = 3,
}

-- Basic per-player cooldown
local lastRequestAt: { [number]: number } = {}

local function withinCooldown(player: Player)
    local now = os.clock()
    local last = lastRequestAt[player.UserId] or 0
    if now - last < DEFAULTS.cooldownSec then return true end
    lastRequestAt[player.UserId] = now
    return false
end

local function getGreenSpawn()
    local spawn = Workspace:FindFirstChild("GreenSpawn")
    if spawn and spawn:IsA("BasePart") then return spawn end
    -- Accept SpawnLocation too
    if spawn and spawn:IsA("SpawnLocation") then return spawn end
    return nil
end

local function clearOld()
    for _, name in ipairs({"DefenseWalls", "GeneratedBuilding"}) do
        local container = Workspace:FindFirstChild(name)
        if container then container:Destroy() end
    end
end

local function makeWall(name: string, size: Vector3, cframe: CFrame, color: Color3)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Size = size
    p.CFrame = cframe
    p.Color = color
    return p
end

local function buildProceduralAt(origin: CFrame)
    clearOld()

    -- Determine floor Y offset
    local baseplate = Workspace:FindFirstChild("Baseplate")
    local groundY = baseplate and baseplate.Position.Y + (baseplate.Size.Y * 0.5) or 0

    local originOnGround = CFrame.new(origin.Position.X, groundY, origin.Position.Z)

    -- Load config
    local cfgLoaderOk, Loader = pcall(function()
        return require(ReplicatedStorage.Shared.ConfigLoader)
    end)
    local sharedCfg = (cfgLoaderOk and Loader and Loader.Load("ConstructionService")) or nil
    local buildCfg = sharedCfg and sharedCfg.CONSTRUCTION or nil
    if not buildCfg then
        warn("[ConstructionService] CONSTRUCTION config missing; using ad-hoc defaults")
        buildCfg = {
            Seed = 1337,
            Footprint = { Width = 96, Length = 72 },
            Floors = 1,
            WallHeight = 16.8,
            WallThickness = 2,
            CorridorWidth = 12,
            Room = { MinSize = { Width = 16, Length = 14 }, MaxSize = { Width = 34, Length = 28 } },
            Door = { Width = 10, MinWidth = 12, Height = 9, Clearance = 3, MinSpacing = 18 },
            ExteriorDoors = 2,
            Window = { Width = 6, Height = 5, SillHeight = 4, Spacing = 8, InsetFromCorner = 4 },
            Colors = { Walls = Color3.fromRGB(150,150,150), InteriorWalls = Color3.fromRGB(150,150,150), Corridors = Color3.fromRGB(170,170,170), Rooms = Color3.fromRGB(210,210,210), Floor = Color3.fromRGB(140,110,80), Roof = Color3.fromRGB(255,255,255) },
            Materials = { Walls = Enum.Material.Concrete, InteriorWalls = Enum.Material.Concrete, Floor = Enum.Material.Wood, Roof = Enum.Material.SmoothPlastic },
            GenerateFloors = false,
            GenerateFloorSlab = true,
            GenerateRoof = true,
            Slab = { FloorThickness = 1, RoofThickness = 1, Extend = 0, FloorOffset = 0.5 },
            Debug = { Print = true, VisualizeRects = false, Randomize = true },
        }
    end

    -- Call generator
    local ok, gen = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Construction"):WaitForChild("Generator"))
    end)
    if not ok or not gen then
        warn("[ConstructionService] Generator module not found")
        return
    end
    -- Shallow clone config so we can override Seed per build without mutating shared config
    local runCfg = table.clone(buildCfg)
    -- Randomize per build (unless Debug.Randomize == false)
    local salt = math.floor((os.clock() * 1000) % 1e9)
    local shouldRandomize = true
    if buildCfg.Debug and buildCfg.Debug.Randomize == false then
        shouldRandomize = false
    end
    runCfg.Seed = (buildCfg.Seed or 0) + (shouldRandomize and salt or 0)

    local model, meta = gen.Generate(originOnGround, runCfg)
    if model then
        print("[ConstructionService] Generated procedural building")
    end

    -- Send ASCII minimap to clients for debugging/feedback
    pcall(function()
        local walls = model and model:FindFirstChild("Walls")
        if not walls then return end
        local parts = walls:GetChildren()
        if #parts == 0 then return end
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
        for _, p in ipairs(parts) do
            if p:IsA("BasePart") then
                local px, pz = p.Position.X, p.Position.Z
                local sx, sz = p.Size.X, p.Size.Z
                minX = math.min(minX, px - sx * 0.5)
                maxX = math.max(maxX, px + sx * 0.5)
                minZ = math.min(minZ, pz - sz * 0.5)
                maxZ = math.max(maxZ, pz + sz * 0.5)
            end
        end
        local spanX = math.max(1, maxX - minX)
        local spanZ = math.max(1, maxZ - minZ)
        local targetCols = 60
        local cell = math.max(1, math.max(spanX, spanZ) / targetCols)
        local cols = math.floor(spanX / cell + 0.5)
        local rows = math.floor(spanZ / cell + 0.5)
        local grid = {}
        for r = 1, rows do
            local row = table.create(cols, " ")
            grid[r] = row
        end
        for _, p in ipairs(parts) do
            if p:IsA("BasePart") then
                local x0 = p.Position.X - p.Size.X * 0.5
                local x1 = p.Position.X + p.Size.X * 0.5
                local z0 = p.Position.Z - p.Size.Z * 0.5
                local z1 = p.Position.Z + p.Size.Z * 0.5
                local c0 = math.max(1, math.floor((x0 - minX) / cell) + 1)
                local c1 = math.min(cols, math.floor((x1 - minX) / cell) + 1)
                local r0 = math.max(1, math.floor((z0 - minZ) / cell) + 1)
                local r1 = math.min(rows, math.floor((z1 - minZ) / cell) + 1)
                for r = r0, r1 do
                    local row = grid[r]
                    for c = c0, c1 do
                        row[c] = "#"
                    end
                end
            end
        end
        local lines = {}
        for r = rows, 1, -1 do
            lines[#lines + 1] = table.concat(grid[r])
        end
        local mapText = table.concat(lines, "\n")
        print("[Construction Minimap]\n" .. mapText)
    end)

    -- Move Green spawn to the largest room center (on floor)
    if meta and meta.largestRoomCenter and meta.floorTopY then
        local spawn = getGreenSpawn()
        if spawn and spawn:IsA("BasePart") then
            local pos = meta.largestRoomCenter
            local y = meta.floorTopY + (spawn.Size.Y * 0.5)
            spawn.CFrame = CFrame.new(Vector3.new(pos.X, y, pos.Z))
        end
    end

    -- Lower grass terrain just under the building floor level within the building bounds
    pcall(function()
        if not (model and meta and meta.floorTopY) then return end
        local terrain = Workspace.Terrain
        local bboxCF, bboxSize = model:GetBoundingBox()
        local pad = 6
        local extentX = bboxSize.X + pad
        local extentZ = bboxSize.Z + pad
        -- Set grass top below the original floor base (ignoring visual floor offset)
        local baseY = meta.floorBaseY or meta.floorTopY
        local targetTop = baseY - 2

        -- Carve out existing terrain from well below up to just below the floor within bounds
        local airHeight = 128
        local airCF = CFrame.new(bboxCF.Position.X, targetTop - airHeight * 0.5, bboxCF.Position.Z)
        terrain:FillBlock(airCF, Vector3.new(extentX, airHeight, extentZ), Enum.Material.Air)

        -- Refill with grass up to slightly below the floor to avoid z-fighting
        local grassTop = targetTop -- targetTop already includes a 2-stud offset below the floor
        local grassThick = 32
        local grassCF = CFrame.new(bboxCF.Position.X, grassTop - grassThick * 0.5, bboxCF.Position.Z)
        terrain:FillBlock(grassCF, Vector3.new(extentX, grassThick, extentZ), Enum.Material.Grass)
    end)
end

local function handleConstructionRequest(player: Player)
    -- Validate player exists and is in game
    if not player or not player.Parent then return end
    if withinCooldown(player) then
        warn(string.format("[ConstructionService] Rate limited: %s", player.Name))
        return
    end

    local greenSpawn = getGreenSpawn()
    if not greenSpawn then
        warn("[ConstructionService] GreenSpawn not found; cannot build")
        return
    end

    -- Build procedural structure near the green team spawn
    buildProceduralAt(greenSpawn.CFrame)
    print(string.format("[ConstructionService] Built procedural building near Green spawn (by %s)", player.Name))
end

function ConstructionService.Init()
    -- Resolve remote robustly
    local remote = Events and Events.Construction or nil
    if not remote then
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 10)
        if remotesFolder then
            remote = remotesFolder:FindFirstChild("ConstructionRequest") or remotesFolder:WaitForChild("ConstructionRequest", 10)
        end
    end

    if not remote then
        warn("[ConstructionService] ConstructionRequest remote not found; cannot initialize")
        return
    end

    -- Connect remote
    remote.OnServerEvent:Connect(function(player)
        print(string.format("[ConstructionService] Request received from %s", player and player.Name or "?"))
        -- No payload needed yet
        handleConstructionRequest(player)
    end)

    -- Cleanup cooldown table when players leave
    Players.PlayerRemoving:Connect(function(plr)
        lastRequestAt[plr.UserId] = nil
    end)

    print("[ConstructionService] Initialized and listening for ConstructionRequest")
end

-- Auto-init if required directly
ConstructionService.Init()

return ConstructionService
