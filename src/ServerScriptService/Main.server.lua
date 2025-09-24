-- Bootstraps lobby countdown and round system

local Players = game:GetService("Players")

local LobbyManager = require(script.Parent.LobbyManager)
-- Ensure ConstructionService is initialized early (bootstrap)
pcall(function()
    local folder = script.Parent:FindFirstChild("Construction") or script.Parent:WaitForChild("Construction", 5)
    if folder then
        require(folder:WaitForChild("ConstructionService"))
    end
end)

-- Initialize lobby manager on server start
task.wait(1) -- Let services initialize
LobbyManager.CheckAndStart()
