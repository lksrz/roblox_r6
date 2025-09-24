-- Bootstraps lobby countdown and round system

local Players = game:GetService("Players")

local LobbyManager = require(script.Parent.LobbyManager)

-- Initialize lobby manager on server start
task.wait(1) -- Let services initialize
LobbyManager.CheckAndStart()
