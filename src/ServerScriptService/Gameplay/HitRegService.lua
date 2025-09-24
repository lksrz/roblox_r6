local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getEvents()
    -- TODO: ISSUE #8 - Code Duplication: Remote event creation logic duplicated across multiple files
    -- Should be centralized in a shared utility module
    local net = ReplicatedStorage:FindFirstChild("Net")
    if net and net:FindFirstChild("Events") then
        local ok, mod = pcall(require, net.Events)
        if ok and mod then return mod end
    end
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then
        folder = Instance.new("Folder"); folder.Name = "Remotes"; folder.Parent = ReplicatedStorage
    end
    local function ensure(name, class)
        local obj = folder:FindFirstChild(name)
        if not obj then obj = Instance.new(class); obj.Name = name; obj.Parent = folder end
        return obj
    end
    return {
        FireWeapon = ensure("FireWeapon", "RemoteEvent"),
        HitConfirm = ensure("HitConfirm", "RemoteEvent"),
    }
end

local Events = getEvents()
local RateLimiter = require(game.ServerScriptService.AntiCheat.RateLimiter)

-- Simple config to avoid ConfigLoader dependency
local Config = {
    WEAPONS = {
        RateLimit = 120,  -- requests per minute
    },
}

-- Input validation utility functions
local function validateVector3(vec, maxMagnitude)
    if typeof(vec) ~= "Vector3" then return false end
    if vec.X ~= vec.X or vec.Y ~= vec.Y or vec.Z ~= vec.Z then return false end -- Check for NaN
    if maxMagnitude and vec.Magnitude > maxMagnitude then return false end
    return true
end

local function validatePlayerState(player)
    if not player then return false, "Player is nil" end
    if not player.Parent then return false, "Player is not in game" end
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        local humanoid = player.Character.Humanoid
        if humanoid.Health <= 0 then return false, "Player is dead" end
    end
    return true
end

local function validateWeaponFirePayload(payload)
    if not payload then return false, "Payload is nil" end
    if typeof(payload) ~= "table" then return false, "Payload is not a table" end

    if not payload.origin or not payload.dir or not payload.weaponName then
        return false, "Missing required fields: origin, dir, or weaponName"
    end

    if not validateVector3(payload.origin, 1000) then
        return false, "Invalid origin vector"
    end

    if not validateVector3(payload.dir, 10) then
        return false, "Invalid direction vector"
    end

    if typeof(payload.weaponName) ~= "string" then
        return false, "Invalid weapon name type"
    end

    return true
end

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

-- Store the connection to prevent memory leaks
table.insert(connections, Events.FireWeapon.OnServerEvent:Connect(function(plr, payload)
    -- Comprehensive input validation and error handling
    local isPlayerValid, playerError = validatePlayerState(plr)
    if not isPlayerValid then
        warn(string.format("[HitRegService] Invalid player state: %s (UserId: %s)", playerError, plr.UserId or "unknown"))
        return
    end

    local isPayloadValid, payloadError = validateWeaponFirePayload(payload)
    if not isPayloadValid then
        warn(string.format("[HitRegService] Invalid payload: %s (UserId: %s)", payloadError, plr.UserId))
        Events.HitConfirm:FireClient(plr, { ok = false, error = "Invalid request" })
        return
    end

    -- Rate limiting check
    if not RateLimiter.Allow(plr, "FireWeapon", Config.WEAPONS.RateLimit or 120) then
        Events.HitConfirm:FireClient(plr, { ok = false, error = "Rate limit exceeded" })
        return
    end

    -- Perform raycast with error handling
    local success, result = pcall(function()
        return workspace:Raycast(payload.origin, payload.dir)
    end)

    if not success then
        warn(string.format("[HitRegService] Raycast failed: %s (UserId: %s)", result, plr.UserId))
        Events.HitConfirm:FireClient(plr, { ok = false, error = "Raycast failed" })
        return
    end

    -- Process hit result
    if result then
        -- TODO: Add hit processing logic (damage, destruction, etc.)
        Events.HitConfirm:FireClient(plr, { ok = true, hit = true })
    else
        Events.HitConfirm:FireClient(plr, { ok = true, hit = false })
    end
end))

-- Cleanup on game shutdown
game:BindToClose(cleanupConnections)
