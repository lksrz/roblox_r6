-- Client helper: while holding the Board Up prompt key, repeatedly ask server to place boards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UIS = game:GetService("UserInputService")

local Events do
    local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild("Net"):WaitForChild("Events")) end)
    if ok then Events = mod end
end

local interval = 0.2
local boardKey = Enum.KeyCode.E
local kickKey = Enum.KeyCode.Q
do
    local ok, ConfigLoader = pcall(function() return require(ReplicatedStorage.Shared.ConfigLoader) end)
    if ok then
        local cfg = ConfigLoader.Load("BoardUpClient")
        if cfg and cfg.CONSTRUCTION and cfg.CONSTRUCTION.BOARDUP then
            if cfg.CONSTRUCTION.BOARDUP.Hold then
                interval = math.max(0.05, cfg.CONSTRUCTION.BOARDUP.Hold)
            end
            if cfg.CONSTRUCTION.BOARDUP.KeyCode then
                boardKey = cfg.CONSTRUCTION.BOARDUP.KeyCode
            end
            if cfg.CONSTRUCTION.DESTROY and cfg.CONSTRUCTION.DESTROY.KeyCode then
                kickKey = cfg.CONSTRUCTION.DESTROY.KeyCode
            end
        end
    end
end

local activePrompt: ProximityPrompt? = nil
local holdAccum = 0
local boardHeld = false
local keyHeld = false

local function isOpeningPrompt(prompt: ProximityPrompt)
    local p = prompt and prompt.Parent
    return p and p:IsA("BasePart") and p.Parent and p.Parent.Name == "Openings"
end

-- Track currently shown opening prompt (do not clear on Hidden to avoid single-board stalls)
ProximityPromptService.PromptShown:Connect(function(prompt)
    if isOpeningPrompt(prompt) then
        activePrompt = prompt
        holdAccum = 0
    end
end)

-- Also track actual hold begin/end for reliable state
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    if isOpeningPrompt(prompt) then
        activePrompt = prompt
        holdAccum = 0
        boardHeld = true
        keyHeld = true
    end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
    if prompt == activePrompt then
        boardHeld = false
        holdAccum = 0
    end
end)

-- Do not forcibly clear on PromptHidden; engine may hide between triggers.

-- Track board key state
-- We query key state directly per-frame; no need to observe InputBegan/Ended

-- Drive continuous placement independent of the engine's prompt hold cycle
local RunService = game:GetService("RunService")
-- Track physical key state regardless of gameProcessedEvent
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == boardKey then keyHeld = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == boardKey then keyHeld = false end
end)

RunService.Heartbeat:Connect(function(dt)
    if not (activePrompt and activePrompt.Parent and activePrompt.Enabled) then
        holdAccum = 0
        return
    end
    -- Build action while E is held (only when the visible prompt is NOT Kick)
    if keyHeld and Events and Events.BoardUp and (activePrompt.Name ~= "KickPrompt") then
        holdAccum += dt
        if holdAccum >= interval then
            holdAccum -= interval
            Events.BoardUp:FireServer(activePrompt.Parent)
        end
    end
end)

-- Kick action on key press (single; strong when Shift + Key)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == kickKey and activePrompt and activePrompt.Enabled and Events and Events.BoardKick then
        local strong = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
        Events.BoardKick:FireServer(activePrompt.Parent, strong)
    end
end)
