local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local GLOBAL = getgenv()

local DEFAULT_RAY_DISTANCE = 2000
local IMPORTED_PACKAGES = {}
local IGNORE_PACKAGES = {'builtIn'}
GLOBAL.GenericKeybinds = {
    Teleport = Enum.KeyCode.T,
}

if GLOBAL.GenericConnections and #GLOBAL.GenericConnections then
    for i = 1, #GLOBAL.GenericConnections do
        GLOBAL.GenericConnections[i]:Disconnect()
    end
end
GLOBAL.GenericConnections = {}

local require = GLOBAL.require
local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage

local canPlayerTeleportToMouse = true
local humanoidRootPart = nil
local humanoid = nil

local function RaycastToMouse(distance: number?): {Position: Vector3, Normal: Vector3}
    local loc = UserInputService:GetMouseLocation()
    local ray = workspace.CurrentCamera:ViewportPointToRay(loc.X, loc.Y)
    local dir = ray.Direction * (distance or DEFAULT_RAY_DISTANCE)
    local result = workspace:Raycast(ray.Origin, dir)
    return if result then result else {Instance = nil, Position = ray.Origin + dir, Normal = Vector3.yAxis, Material = Enum.Material.Air, Distance = 0}
end

local function OnCharacterAdded(character: Model)
    humanoid = character:WaitForChild("Humanoid") :: Humanoid
    humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: Part
end

GLOBAL.RaycastToMouse = RaycastToMouse
GLOBAL.GetHumanoidRootPart = function()
    return humanoidRootPart
end

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
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
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
        local ok = pcall(require, '/'..name)
        if not ok then
            error(("Unable to load package %s (package doesn't exist)"):format(name))
        end
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

CommandsAPIService.PostCommand {
    Name = "tpenabled",
    Description = "A toggable where you can teleport to your mouse position whenever you pressed the teleport keybind (Default: T)",
    Callback = function(out: boolean)
        print(out)
        canPlayerTeleportToMouse = out
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "setgenerickeybindof",
    Description = "Set a keybind of a Generic Keybind to something else",
    Callback = function(of: string, keybind: string)
        if GLOBAL.GenericKeybinds[of] == nil then
            local genericKeybindList = {}
            for key in pairs(GLOBAL.GenericKeybinds) do
                table.insert(genericKeybindList, tostring(key))
            end
            error(("%s is not a bound keybind, bounded keys are:\n%q"):format(of, table.concat(genericKeybindList, '\n')))
        end
        local key = Enum.KeyCode[keybind]
        if not key then
            error(("%s is not a valid keycode"):format(key))
        end
        local old = GLOBAL.GenericKeybinds[of]
        GLOBAL.GenericKeybinds[of] = key
        return "Successfully swapped out " .. of .. "'s keybind from " .. old .. " to " .. keybind
    end
}

table.insert(GLOBAL.GenericConnections, Players.LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))
table.insert(GLOBAL.GenericConnections, UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
    if gpe then return end
    if input.KeyCode == GLOBAL.GenericKeybinds.Teleport then
        if canPlayerTeleportToMouse then
            if humanoidRootPart then
                local result = RaycastToMouse()
                local position = result.Position+result.Normal*2
                humanoidRootPart.CFrame = CFrame.new(position) * CFrame.lookAt(Vector3.zero, humanoidRootPart.CFrame.LookVector)
            end
        end
    end
end))

if Players.LocalPlayer.Character then
    OnCharacterAdded(Players.LocalPlayer.Character)
end