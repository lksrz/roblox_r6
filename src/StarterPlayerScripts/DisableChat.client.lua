local StarterGui = game:GetService("StarterGui")

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

pcall(function()
    local tcs = game:GetService("TextChatService")
    if tcs then
        if tcs:FindFirstChild("ChatWindowConfiguration") and tcs.ChatWindowConfiguration then
            tcs.ChatWindowConfiguration.Enabled = false
        end
        if tcs:FindFirstChild("ChatInputBarConfiguration") and tcs.ChatInputBarConfiguration then
            tcs.ChatInputBarConfiguration.Enabled = false
        end
        if tcs:FindFirstChild("BubbleChatConfiguration") and tcs.BubbleChatConfiguration then
            tcs.BubbleChatConfiguration.Enabled = false
        end
    end
end)

