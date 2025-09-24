-- Simple local FX for board kicks: camera shake

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events
do
    local ok, mod = pcall(function() return require(ReplicatedStorage.Net.Events) end)
    if ok then Events = mod end
end

local function shakeCamera(mag, dur)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local t = 0
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        t += dt
        if t >= dur then
            if conn then conn:Disconnect() end
            return
        end
        local off = Vector3.new((math.random()-0.5)*mag, (math.random()-0.5)*mag, 0)
        cam.CFrame = cam.CFrame * CFrame.new(off)
    end)
end

local function onFX(payload)
    if type(payload) ~= "table" then return end
    if payload.kind == "Kick" then
        shakeCamera(payload.mag or 0.3, payload.dur or 0.1)
    end
end

if Events and Events.BoardFX then
    Events.BoardFX.OnClientEvent:Connect(onFX)
end

