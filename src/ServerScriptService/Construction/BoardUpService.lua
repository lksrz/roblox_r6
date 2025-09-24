-- BoardUpService: allows players to board up openings (doors/windows/passages)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RateLimiter = require(game.ServerScriptService.AntiCheat.RateLimiter)

local BoardUpService = {}

local DEFAULT = {
    PlankWidth = 1.5,
    PlankThickness = 0.2,
    Hold = 0.2,
    MaxBoardsPerOpening = 24,
    MaxPerMinute = 30,
    KeyCode = Enum.KeyCode.E,
    Distance = 12,
    Material = Enum.Material.WoodPlanks,
    Color = Color3.fromRGB(155, 120, 80),
}

local function getCfg(cfg)
    local out = {}
    for k,v in pairs(DEFAULT) do out[k] = (cfg and cfg[k]) or v end
    return out
end

local function computeQuota(proxy: BasePart, cfg)
    local axis = proxy:GetAttribute("Axis") or "x"
    local length = (axis == "x") and proxy.Size.X or proxy.Size.Z
    local N = math.max(1, math.ceil(length / cfg.PlankWidth))
    N = math.min(N, cfg.MaxBoardsPerOpening)
    local boards = proxy:FindFirstChild("Boards")
    local current = boards and #boards:GetChildren() or 0
    return N, current
end

local function setPromptEnabled(proxy: BasePart, enabled: boolean)
    local pp = proxy:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        pp.Enabled = enabled
        if not enabled then pp.ObjectText = "Sealed" end
    end
end

local function ensureKickPrompt(proxy: BasePart, cfg)
    local prompt = proxy:FindFirstChild("KickPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = "KickPrompt"
        prompt.ActionText = "Kick"
        prompt.ObjectText = "Boards"
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.Parent = proxy
    end
    prompt.KeyboardKeyCode = (cfg and cfg.KeyCode) or Enum.KeyCode.Q
    prompt.MaxActivationDistance = (cfg and cfg.Distance) or 12
    return prompt
end

local function updatePrompts(proxy: BasePart, buildCfg, destroyCfg)
    local boardPrompt = proxy:FindFirstChildOfClass("ProximityPrompt")
    if boardPrompt then
        boardPrompt.KeyboardKeyCode = (buildCfg and buildCfg.KeyCode) or DEFAULT.KeyCode
        boardPrompt.HoldDuration = (buildCfg and buildCfg.Hold) or DEFAULT.Hold
        boardPrompt.MaxActivationDistance = (buildCfg and buildCfg.Distance) or DEFAULT.Distance
    end
    local N, current = computeQuota(proxy, getCfg(buildCfg))
    local kickPrompt = ensureKickPrompt(proxy, destroyCfg)
    -- Show only one prompt at a time:
    -- - Board Up when not fully sealed (current < N)
    -- - Kick only when fully sealed (current == N)
    local showKick = (current >= N and N > 0)
    local showBoard = (current < N)
    if boardPrompt then boardPrompt.Enabled = showBoard end
    kickPrompt.Enabled = showKick
end

local function countChildren(folder)
    local n = 0
    for _, _ in ipairs(folder:GetChildren()) do n += 1 end
    return n
end

-- per-proxy per-player last time stamp to enforce hold build time
local lastAt: { [Instance]: { [number]: number } } = {}

local function placeBoard(player: Player, proxy: BasePart, cfg, destroyCfg)
    if not player or not player.Parent then return end
    cfg = getCfg(cfg)
    local minPerMinute = math.max(cfg.MaxPerMinute or 0, math.floor(60 / math.max(0.05, cfg.Hold)) + 5)
    if not RateLimiter.Allow(player, "BOARDUP", minPerMinute) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then return end
    local dist = (hrp.Position - proxy.Position).Magnitude
    if dist > (cfg.Distance + 2) then return end

    -- opening dimensions
    local axis = proxy:GetAttribute("Axis") or "x"
    local boards = proxy:FindFirstChild("Boards")
    if not boards then boards = Instance.new("Folder"); boards.Name = "Boards"; boards.Parent = proxy end

    local length = (axis == "x") and proxy.Size.X or proxy.Size.Z
    local height = proxy.Size.Y
    if length <= 0.1 or height <= 0.1 then return end

    local N, current = computeQuota(proxy, cfg)
    -- Enforce that each plank requires at least Hold seconds of continuous holding
    lastAt[proxy] = lastAt[proxy] or {}
    local now = os.clock()
    local last = lastAt[proxy][player.UserId] or 0
    if now - last < cfg.Hold - 1e-3 then
        return
    end
    lastAt[proxy][player.UserId] = now
    if current >= N then
        setPromptEnabled(proxy, false)
        return
    end

    local slotW = length / N
    local idx = current -- 0-based
    local offsetAlong = -length * 0.5 + (idx + 0.5) * slotW

    local plank = Instance.new("Part")
    plank.Anchored = true
    plank.CanCollide = true
    plank.Material = cfg.Material
    plank.Color = cfg.Color
    plank.Name = string.format("Board_%d", idx + 1)
    if axis == "x" then
        plank.Size = Vector3.new(slotW, height, cfg.PlankThickness)
        plank.CFrame = proxy.CFrame * CFrame.new(offsetAlong, 0, 0)
    else
        plank.Size = Vector3.new(cfg.PlankThickness, height, slotW)
        plank.CFrame = proxy.CFrame * CFrame.new(0, 0, offsetAlong)
    end
    plank.Parent = boards

    if idx + 1 >= N then setPromptEnabled(proxy, false) end
    updatePrompts(proxy, cfg, destroyCfg)
end

-- Knock down one random board with fun effects
local lastKick: { [Instance]: { [number]: number } } = {}

local function kickBoard(player: Player, proxy: BasePart, cfg, destroyCfg, strong: boolean?)
    cfg = getCfg(cfg)
    destroyCfg = destroyCfg or {}
    local perMinute = (destroyCfg.MaxPerMinute or 60)
    if not RateLimiter.Allow(player, "BOARDKICK", perMinute) then return end
    -- Cooldown per opening per player
    local cd = destroyCfg.Cooldown or 0.25
    lastKick[proxy] = lastKick[proxy] or {}
    local now = os.clock()
    local last = lastKick[proxy][player.UserId] or 0
    if now - last < cd then return end
    lastKick[proxy][player.UserId] = now
    -- distance validation
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then return end
    local dist = (hrp.Position - proxy.Position).Magnitude
    if dist > ((destroyCfg.Distance or 12) + 2) then return end

    local boards = proxy:FindFirstChild("Boards")
    if not boards then return end
    local children = boards:GetChildren()
    if #children == 0 then return end

    local toBreak = 1
    if strong then
        toBreak = math.min(destroyCfg.StrongBreakMax or 4, math.max(1, math.random(2, 3)))
    elseif math.random() < (destroyCfg.DoubleBreakChance or 0) then
        toBreak = 2
    end

    local eventsOk, Events = pcall(function() return require(game.ReplicatedStorage.Net.Events) end)
    local Debris = game:GetService("Debris")

    for i = 1, toBreak do
        local list = boards:GetChildren()
        if #list == 0 then break end
        local pick = list[math.random(1, #list)]
        if pick and pick:IsA("BasePart") then
            if eventsOk and Events and Events.BoardFX then
                Events.BoardFX:FireAllClients({ kind = "Kick", pos = pick.Position, mag = (destroyCfg.Shake and destroyCfg.Shake.Mag) or 0.4, dur = (destroyCfg.Shake and destroyCfg.Shake.Duration) or 0.1 })
            end
            pick.Parent = workspace
            pick.CanCollide = false
            pick.Anchored = false
            pick.AssemblyLinearVelocity = Vector3.new((math.random()-0.5)*28, 18 + math.random()*10, (math.random()-0.5)*28)
            pick.AssemblyAngularVelocity = Vector3.new(math.random(), math.random(), math.random()) * 8
            Debris:AddItem(pick, 1.6)
        end
    end

    updatePrompts(proxy, cfg, destroyCfg)
end

function BoardUpService.Attach(model: Model, cfg, destroyCfg)
    if not (model and model.Parent) then return end
    local openings = model:FindFirstChild("Openings")
    if not openings then return end

    -- Hook remote for hold-to-board behavior
    local eventsOk, Events = pcall(function() return require(game.ReplicatedStorage.Net.Events) end)
        if eventsOk and Events then
            Events.BoardUp.OnServerEvent:Connect(function(player, proxy)
                if typeof(proxy) == "Instance" and proxy:IsDescendantOf(openings) then
                placeBoard(player, proxy, cfg, destroyCfg)
                end
            end)
            if Events.BoardKick then
                Events.BoardKick.OnServerEvent:Connect(function(player, proxy, strong)
                    if typeof(proxy) == "Instance" and proxy:IsDescendantOf(openings) then
                        kickBoard(player, proxy, cfg, destroyCfg, strong == true)
                    end
                end)
            end
        end

    for _, proxy in ipairs(openings:GetChildren()) do
        if proxy:IsA("BasePart") then
            local prompt = proxy:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                -- Primary board prompt is already on the proxy (created in generator)
                -- Configure it and add fallback Triggered handler
                prompt.ActionText = "Board Up"
                prompt.RequiresLineOfSight = false
                prompt.Triggered:Connect(function(player)
                    placeBoard(player, proxy, cfg, destroyCfg)
                end)
            end
            -- Kick prompt
            local kp = ensureKickPrompt(proxy, destroyCfg)
            kp.Triggered:Connect(function(player)
                kickBoard(player, proxy, cfg, destroyCfg)
            end)
            updatePrompts(proxy, cfg, destroyCfg)
        end
    end
end

return BoardUpService
