-- Immediate chat disabling to prevent ChatScript errors
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

-- Disable chat immediately, before other scripts can interfere
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

-- Additional cleanup after a brief delay
task.spawn(function()
    task.wait(1)

    -- Ensure chat stays disabled
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    end)

    -- Try to clear any remaining chat elements
    pcall(function()
        local success = pcall(function()
            StarterGui:SetCore("ChatActive", false)
        end)
        if not success then
            -- If ChatActive doesn't work, try alternative
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        end
    end)
end)

-- Aggressively remove legacy ChatScript to avoid SetCore errors
task.spawn(function()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    local ps = localPlayer:FindFirstChild("PlayerScripts") or localPlayer:WaitForChild("PlayerScripts", 5)
    if not ps then return end

    local function scrub(child)
        if child and child.Name == "ChatScript" then
            pcall(function()
                child:Destroy()
            end)
        end
    end

    -- Remove any existing ChatScript
    for _, ch in ipairs(ps:GetChildren()) do
        scrub(ch)
    end
    -- Remove if it appears later
    ps.ChildAdded:Connect(scrub)
end)
