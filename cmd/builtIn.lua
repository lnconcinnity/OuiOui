local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local GLOBAL = getgenv()

local IMPORTED_PACKAGES = {}
local IGNORE_PACKAGES = {'builtIn'}

local require = GLOBAL.require
local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage

CommandsAPIService.PostCommand {
    Name = "help",
    Description = "Shows every commands",
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
        MakeChatSystemMessage.Out("Rejoining server place, please wait.", MakeChatSystemMessage.Colors[2])
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/weeeeee8/OuiOui/main/source.lua'))()")
    end,
}

CommandsAPIService.PostCommand {
    Name = "package",
    Description = "Import a command package to the game",
    Callback = function(name: string)
        assert(name and #name > 0, "Name must not be nil or an empty string")
        if table.find(IGNORE_PACKAGES, name) or IMPORTED_PACKAGES[name] then
            error(("Package %s is already loaded"):format(name))
        end
        require('/'..name)
    end,
    Arguments = {name = "string"}
}

CommandsAPIService.PostCommand {
    Name = "remotespy",
    Description = "Import SimpleSpyBeta to the place",
    Callback = function()
        local ok, contentOrErr = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/78n/SimpleSpy/main/SimpleSpyBeta.lua")
        if ok then
            local src = loadstring(contentOrErr, "SimpleSpy")
            if not src then
                error("Fetch fault with SimpleSpy, unable to load in source code", 2)
            end
            src()
            return "Successfully imported SimpleSpy"
        else
            error(("Unable to load in SimpleSpy (%s)"):format(contentOrErr), 2)
        end
    end
}