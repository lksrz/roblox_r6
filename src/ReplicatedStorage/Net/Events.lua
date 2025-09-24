-- Centralized RemoteEvent/RemoteFunction registry

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = {}

local function ensure(name, className)
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Remotes"
        folder.Parent = ReplicatedStorage
    end
    local obj = folder:FindFirstChild(name)
    if not obj then
        obj = Instance.new(className)
        obj.Name = name
        obj.Parent = folder
    end
    return obj
end

Events.RoundChanged = ensure("RoundChanged", "RemoteEvent")
Events.RequestSpawn = ensure("RequestSpawn", "RemoteFunction")
Events.UseGadget = ensure("UseGadget", "RemoteEvent")
Events.FireWeapon = ensure("FireWeapon", "RemoteEvent")
Events.HitConfirm = ensure("HitConfirm", "RemoteEvent")
Events.Objective = ensure("ObjectiveEvent", "RemoteEvent")

return Events

