-- Centralized RemoteEvent/RemoteFunction registry

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = {}

local function ensure(name, className)
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then
        if RunService:IsServer() then
            folder = Instance.new("Folder")
            folder.Name = "Remotes"
            folder.Parent = ReplicatedStorage
        else
            folder = ReplicatedStorage:WaitForChild("Remotes", 10)
        end
    end

    local obj = folder and folder:FindFirstChild(name) or nil
    if not obj then
        if RunService:IsServer() then
            obj = Instance.new(className)
            obj.Name = name
            obj.Parent = folder
        else
            obj = folder and folder:WaitForChild(name, 10) or nil
        end
    end
    return obj
end

Events.RoundChanged = ensure("RoundChanged", "RemoteEvent")
Events.RequestSpawn = ensure("RequestSpawn", "RemoteFunction")
Events.UseGadget = ensure("UseGadget", "RemoteEvent")
Events.FireWeapon = ensure("FireWeapon", "RemoteEvent")
Events.HitConfirm = ensure("HitConfirm", "RemoteEvent")
Events.Objective = ensure("ObjectiveEvent", "RemoteEvent")
-- Construction/building requests
Events.Construction = ensure("ConstructionRequest", "RemoteEvent")
Events.BoardUp = ensure("BoardUpRequest", "RemoteEvent")
Events.BoardKick = ensure("BoardKickRequest", "RemoteEvent")
Events.BoardFX = ensure("BoardFX", "RemoteEvent")
-- Debug/minimap update
Events.ConstructionMap = ensure("ConstructionMap", "RemoteEvent")

return Events
