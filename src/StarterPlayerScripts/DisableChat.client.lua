-- Immediate chat disabling to prevent ChatScript errors
local StarterGui = game:GetService("StarterGui")

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

