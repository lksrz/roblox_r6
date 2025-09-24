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

    -- Procedural Construction / Building Generation
    CONSTRUCTION = {
        Seed = 1337,
        Footprint = { Width = 100, Length = 80 },
        Floors = 1,

        -- Structure
        WallHeight = 16.8, -- +20% from 14
        WallThickness = 2,
        CorridorWidth = 12,

        -- Rooms (BSP partition constraints)
        Room = {
            MinSize = { Width = 16, Length = 14 },
            MaxSize = { Width = 34, Length = 28 },
        },

        -- Openings
        Door = { Width = 10, MinWidth = 12, Height = 9, Clearance = 3, MinSpacing = 18 },
        ExteriorDoors = 2,
        Window = {
            Width = 6,
            Height = 5,
            SillHeight = 4,
            Spacing = 8, -- center-to-center along exterior walls
            InsetFromCorner = 4, -- keep windows away from corners
        },

        -- Colors/Style
        Colors = {
            Walls = Color3.fromRGB(150, 150, 150),      -- grey walls
            InteriorWalls = Color3.fromRGB(150, 150, 150),
            Corridors = Color3.fromRGB(170, 170, 170),
            Rooms = Color3.fromRGB(210, 210, 210),
            Floor = Color3.fromRGB(140, 110, 80),       -- wood tone
            Roof = Color3.fromRGB(255, 255, 255),       -- white ceiling
        },
        Materials = {
            Walls = Enum.Material.Concrete,
            InteriorWalls = Enum.Material.Concrete,
            Floor = Enum.Material.Wood,
            Roof = Enum.Material.SmoothPlastic,
        },

        -- Generation toggles
        GenerateFloors = false, -- per-room/corridor thin floor patches
        GenerateFloorSlab = true, -- one big floor under whole building
        GenerateRoof = true,      -- one big roof above walls
        Slab = { FloorThickness = 1, RoofThickness = 1, Extend = 0, FloorOffset = 0.5 },
        Debug = {
            Print = true,
            VisualizeRects = false,
            Randomize = true,
        },
    },
}

return Config
