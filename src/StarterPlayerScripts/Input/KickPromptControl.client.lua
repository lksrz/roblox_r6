-- Client-side filter: show Kick prompt only on the closest opening that has any boards.
-- If the closest opening with boards is not fully sealed, we still hide Kick prompts elsewhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local function getHRP()
    local c = player.Character or player.CharacterAdded:Wait()
    return c:WaitForChild("HumanoidRootPart")
end

local PlankWidth = 1.5
local MaxBoardsPerOpening = 24
local DestroyDistance = 12
do
    local ok, ConfigLoader = pcall(function() return require(ReplicatedStorage.Shared.ConfigLoader) end)
    if ok then
        local cfg = ConfigLoader.Load("KickPromptControl")
        if cfg and cfg.CONSTRUCTION then
            local bu = cfg.CONSTRUCTION.BOARDUP
            if bu then
                PlankWidth = bu.PlankWidth or PlankWidth
                MaxBoardsPerOpening = bu.MaxBoardsPerOpening or MaxBoardsPerOpening
            end
            local d = cfg.CONSTRUCTION.DESTROY
            if d then
                DestroyDistance = d.Distance or DestroyDistance
            end
        end
    end
end

local function computeQuota(proxy: BasePart)
    local axis = proxy:GetAttribute("Axis") or "x"
    local length = (axis == "x") and proxy.Size.X or proxy.Size.Z
    local N = math.max(1, math.ceil(length / PlankWidth))
    N = math.min(N, MaxBoardsPerOpening)
    local boards = proxy:FindFirstChild("Boards")
    local current = boards and #boards:GetChildren() or 0
    return N, current
end

local function eachOpenings()
    local res = {}
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") then
            local openings = model:FindFirstChild("Openings")
            if openings then
                for _, proxy in ipairs(openings:GetChildren()) do
                    if proxy:IsA("BasePart") then
                        table.insert(res, proxy)
                    end
                end
            end
        end
    end
    return res
end

local function step()
    local hrp = getHRP()
    local nearest, nd2
    for _, proxy in ipairs(eachOpenings()) do
        local boardsFolder = proxy:FindFirstChild("Boards")
        if boardsFolder and #boardsFolder:GetChildren() > 0 then
            local d2 = (proxy.Position - hrp.Position).Magnitude
            if d2 <= DestroyDistance and (not nd2 or d2 < nd2) then
                nearest, nd2 = proxy, d2
            end
        end
    end

    -- Hide all kick prompts except the nearest with boards; if nearest is not sealed, hide all
    for _, proxy in ipairs(eachOpenings()) do
        local kp = proxy:FindFirstChild("KickPrompt")
        if kp and kp:IsA("ProximityPrompt") then
            kp.Enabled = false
        end
    end

    if nearest then
        local N, current = computeQuota(nearest)
        if current >= N then
            local kp = nearest:FindFirstChild("KickPrompt")
            if kp and kp:IsA("ProximityPrompt") then
                kp.Enabled = true
            end
        end
    end
end

task.spawn(function()
    while true do
        step()
        task.wait(0.25)
    end
end)

