-- Suppress Classic Chat LocalScripts to avoid SetCore errors in Studio
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts", 10)

-- Create a parked folder to avoid parenting-to-nil warnings
local disabledFolder = Instance.new("Folder")
disabledFolder.Name = "DisabledChat"
disabledFolder.Parent = playerScripts

local function tryDisable(child)
    if not child or not child:IsA("LocalScript") then return end
    local n = child.Name
    if n == "ChatScript" or n == "BubbleChat" or n == "ChatMain" then
        -- Only disable and move if it's still in PlayerScripts
        if child.Parent == playerScripts then
            pcall(function() child.Enabled = false end)
            -- Move into a disabled folder instead of Destroying to avoid warnings
            pcall(function() child.Parent = disabledFolder end)
        end
    end
end

if playerScripts then
    for _, ch in ipairs(playerScripts:GetChildren()) do
        tryDisable(ch)
    end
    playerScripts.ChildAdded:Connect(tryDisable)
end
