local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local GLOBAL = getgenv()

local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage

CommandsAPIService.PostCommand {
    Name = "help",
    Description = "Show every built-in commands",
    Callback = function()
        local commands = CommandsAPIService.GetCommands()
        for commandName, command in pairs(commands) do
            MakeChatSystemMessage.Out(("%s - %s"):format(commandName, command.Description or "No description field"), MakeChatSystemMessage.Colors[3])
        end
    end
}

CommandsAPIService.PostCommand {
    Name = "rejoin",
    Description = "Rejoin to the same game place",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/weeeeee8/OuiOui/main/source.lua'))()")
    end,
}