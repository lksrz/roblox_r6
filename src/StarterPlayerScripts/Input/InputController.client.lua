local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getEvents()
    local ok, mod = pcall(function() return require(ReplicatedStorage.Net.Events) end)
    if ok and mod then return mod end
    local folder = ReplicatedStorage:WaitForChild("Remotes", 5)
    local function get(name)
        return folder and (folder:FindFirstChild(name) or folder:WaitForChild(name, 5)) or nil
    end
    return {
        FireWeapon = get("FireWeapon"),
    }
end

-- Input validation functions
local function validateVector3(vec)
    if typeof(vec) ~= "Vector3" then return false end
    if vec.X ~= vec.X or vec.Y ~= vec.Y or vec.Z ~= vec.Z then return false end -- Check for NaN
    return true
end

local function validateWeaponInput()
    local cam = workspace.CurrentCamera
    if not cam then return false, "No camera" end

    local origin = cam.CFrame.Position
    local dir = cam.CFrame.LookVector * 500

    if not validateVector3(origin) or not validateVector3(dir) then
        return false, "Invalid camera vectors"
    end

    return true, origin, dir
end

local Events = getEvents()

local firing = false

UserInputService.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        firing = true
    end
end)

UserInputService.InputEnded:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        firing = false
    end
end)

-- TODO: ISSUE #10 - Performance Issue: RenderStepped runs every frame for input
-- Should use heartbeat or input service events instead of polling every frame
game:GetService("RunService").RenderStepped:Connect(function()
    if not firing then return end

    local isValid, origin, dir = validateWeaponInput()
    if not isValid then
        warn("[InputController] Invalid weapon input: " .. origin)
        return
    end

    -- Add error handling for server communication
    local success, result = pcall(function()
        return Events.FireWeapon:FireServer({ origin = origin, dir = dir, weaponName = "Carbine" })
    end)

    if not success then
        warn("[InputController] Failed to fire weapon: " .. result)
    end
end)
