-- Centralized configuration loading utility
-- Eliminates duplication and ensures consistent fallback behavior

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLoader = {}

local function getDefaultConfig()
    return {
        forceR6 = true,
        baseplate = {
            size = Vector3.new(512,1,512),
            color = Color3.fromRGB(163,162,165),
            name = "Baseplate"
        },
        spawns = {
            inset = 10,
            size = Vector3.new(8,1,8),
            forceFieldDuration = 0
        },
        teams = {
            red = { name = "Red", brickColor = "Really red" },
            green = { name = "Green", brickColor = "Lime green" },
            autoAssignable = false,
            assignment = "alternate",
        },
        ROUND = { LENGTH_SEC = 180, WIN_TARGET = 3, SWITCH_SIDES_EVERY = 2 },
    }
end

function ConfigLoader.Load(moduleName: string?)
    -- Try to load from Shared/Config first
    local ok, config
    ok, config = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if shared then
            local cfg = shared:FindFirstChild("Config") or shared:WaitForChild("Config", 5)
            if cfg then return require(cfg) end
        end
        return nil
    end)

    if ok and config then return config end

    -- Fallback to direct ReplicatedStorage/Config
    ok, config = pcall(function()
        local cfg = ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:WaitForChild("Config", 5)
        if cfg then return require(cfg) end
        return nil
    end)

    if ok and config then return config end

    -- Final fallback to defaults with warning
    warn(string.format("[ConfigLoader] Using default config; ReplicatedStorage.Shared.Config not found%s",
        moduleName and " (requested by " .. moduleName .. ")" or ""))
    return getDefaultConfig()
end

return ConfigLoader
