-- Client input: press B to request construction

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events
do
    local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild("Net"):WaitForChild("Events")) end)
    if ok and mod then Events = mod else
        local folder = ReplicatedStorage:WaitForChild("Remotes", 5)
        local function get(name)
            return folder and (folder:FindFirstChild(name) or folder:WaitForChild(name, 5)) or nil
        end
        Events = { Construction = get("ConstructionRequest") }
    end
end

local debounce = false
local COOLDOWN = 0.5

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.B then
        if debounce then return end
        debounce = true
        if Events and Events.Construction then
            print("[Construction] Sending build request (B pressed)")
            Events.Construction:FireServer()
        else
            warn("[Construction] Remote missing; server may not be ready")
        end
        task.delay(COOLDOWN, function() debounce = false end)
    end
end)
