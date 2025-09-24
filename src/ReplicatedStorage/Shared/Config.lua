-- Central game configuration (shared)

local Config = {
    forceR6 = true,

    baseplate = {
        size = Vector3.new(512, 1, 512),
        color = Color3.fromRGB(163, 162, 165),
        name = "Baseplate",
    },

    spawns = {
        inset = 10,
        size = Vector3.new(8, 1, 8),
        forceFieldDuration = 0,
    },

    teams = {
        red = { name = "Red", brickColor = "Really red" },
        green = { name = "Green", brickColor = "Lime green" },
        autoAssignable = false,
        assignment = "alternate",
    },

    -- Debug: Team colors should be different
    DEBUG_TEAM_COLORS_DIFFERENT = true,

    ROUND = { LENGTH_SEC = 180, WIN_TARGET = 3, SWITCH_SIDES_EVERY = 2 },

    WEAPONS = {
        RateLimit = 120,  -- requests per minute
    },

    OBJECTIVE = {
        Size = Vector3.new(2, 2, 2),
        Position = Vector3.new(0, 1, 0),
        Color = Color3.fromRGB(255, 219, 77),
    },

    EXTRACT = {
        Size = Vector3.new(10, 1, 10),
        Position = Vector3.new(0, 0.5, 80),
        Color = Color3.fromRGB(120, 200, 255),
    },
}

return Config

