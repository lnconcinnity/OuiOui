local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local GLOBAL = getgenv()

local DEFAULT_RAY_DISTANCE = 2000
local IMPORTED_PACKAGES = {}
local IGNORE_PACKAGES = {'builtIn'}
GLOBAL.GenericKeybinds = GLOBAL.GenericKeybinds or {
    Teleport = Enum.KeyCode.T,
    Fly = Enum.KeyCode.F,
}

if GLOBAL.GenericCleanup and #GLOBAL.GenericCleanup then
    for i = 1, #GLOBAL.GenericConnections do
        local cleanup = GLOBAL.GenericCleanup[i]
        if type(cleanup) == "function" then
            cleanup()
        elseif typeof(cleanup) == "Instance" or (type(cleanup) == "table" and type(cleanup.Destroy) == "function") then
            cleanup:Destroy()
        elseif typeof(cleanup) == "RBXScriptConnection" or (type(cleanup) == "table" and type(cleanup.Disconnect) == "function") then
            cleanup:Disconnect()
        end
    end
end
GLOBAL.GenericCleanup = {}

local require = GLOBAL.require
local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage

local flightStateEnabled = false
local flyInputs = {
    [Enum.KeyCode.A] = false,
    [Enum.KeyCode.S] = false,
    [Enum.KeyCode.W] = false,
    [Enum.KeyCode.D] = false,
}
local flyMovers = {
    position = nil :: AlignPosition,
    orientation = nil :: AlignOrientation,
}
local flightSpeed = 120

local cacheParts = {}
local cacheConnections = {}
table.insert(GLOBAL.GenericCleanup, function()
    for _,v in ipairs(cacheConnections) do
        v:Disconnect()
    end
end)

local canPlayerTeleportToMouse = true
local canPlayerFly = true

local humanoidRootPart = nil
local humanoid = nil

local function RaycastToMouse(distance: number?, safeCall: boolean?): {Position: Vector3, Normal: Vector3}
    local params = RaycastParams.new()
    params.RespectCanCollide = true
    params.FilterType = Enum.RaycastFilterType.Exclude
    local loc = if safeCall then UserInputService.GetMouseLocation(UserInputService) else UserInputService:GetMouseLocation()
    local ray = if safeCall then workspace.CurrentCamera.ViewportPointToRay(workspace.CurrentCamera, loc.X, loc.Y) else workspace.CurrentCamera:ViewportPointToRay(loc.X, loc.Y)
    local dir = ray.Direction * (distance or DEFAULT_RAY_DISTANCE)
    local result = if safeCall then workspace.Raycast(workspace, ray.Origin, dir, params) else workspace:Raycast(ray.Origin, dir)
    return if result then result else {Instance = nil, Position = ray.Origin + dir, Normal = Vector3.yAxis, Material = Enum.Material.Air, Distance = 0}
end

local function toggleFlyState(toggled: boolean)
    if canPlayerFly then
        if toggled then
            flyMovers.position.Position = humanoidRootPart.Position
            flyMovers.position.Enabled = true
            flyMovers.orientation.CFrame = CFrame.lookAt(Vector3.zero, workspace.CurrentCamera.CFrame.LookVector)
            flyMovers.orientation.Enabled = true
        else
            flyMovers.position.Enabled = false
            flyMovers.orientation.Enabled = false
            humanoidRootPart.AssemblyLinearVelocity *= 0
            humanoidRootPart.AssemblyAngularVelocity *= 0
        end
        flightStateEnabled = toggled
    end
end

local function OnCharacterAdded(character: Model)
    humanoid = character:WaitForChild("Humanoid") :: Humanoid
    humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: Part

    local attachment = Instance.new("Attachment")
    attachment.Parent = humanoidRootPart
    local alignPosition = Instance.new("AlignPosition")
    alignPosition.Attachment0 = attachment
    alignPosition.MaxVelocity = 10e5
    alignPosition.MaxForce = math.huge
    alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPosition.Enabled = false
    alignPosition.Parent = humanoidRootPart
    flyMovers.position = alignPosition
    local alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Attachment0 = attachment
    alignOrientation.MaxAngularVelocity = 10e5
    alignOrientation.MaxTorque = math.huge
    alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrientation.Enabled = false
    alignOrientation.Parent = humanoidRootPart
    flyMovers.orientation = alignOrientation

    local function onDescendantAdded(descendant: Instance)
        if descendant:IsA("BasePart") then
            cacheParts[descendant] = true
        end
    end

    for _,v in ipairs(cacheConnections) do
        v:Disconnect()
    end
    cacheConnections = {}

    humanoid.Died:Connect(function()
        toggleFlyState(false)
    end)

    table.insert(cacheConnections, character.DescendantAdded:Connect(onDescendantAdded))
    table.insert(cacheConnections, character.DescendantRemoving:Connect(function(d)
        cacheParts[d] = nil
    end))
    for _, v in ipairs(character:GetDescendants()) do
        task.spawn(onDescendantAdded, v)
    end
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
    Name = "importPackage",
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
        return "Package " .. name .. " imported!"
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
    Name = "flyenabled",
    Description = "A toggable where you can enable your character to enter flight mode whenever you pressed the fly keybind",
    Callback = function(out: boolean)
        canPlayerFly = out
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "tpenabled",
    Description = "A toggable where you can enable your character teleport to your mouse position whenever you pressed the teleport keybind",
    Callback = function(out: boolean)
        canPlayerTeleportToMouse = out
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "setflightspeed",
    Description = "Adjust the flight speed to your liking (min: 16)",
    Callback = function(speed: boolean)
        if speed < 16 then
            MakeChatSystemMessage.Out("Cannot have flight speed below 16, clamping at 16...", MakeChatSystemMessage.Colors[2])
        end
        flightSpeed = math.max(speed, 16)
        return "Successfully set flight speed to " .. flightSpeed
    end,
    Arguments = {speed = "number"}
}

CommandsAPIService.PostCommand {
    Name = "showboundedkeybinds",
    Description = "Display all bounded keybinds",
    Callback = function()
        local genericKeybindList = {}
        for key, code in pairs(GLOBAL.GenericKeybinds) do
            table.insert(genericKeybindList, ("%s - %s"):format(key, tostring(code.Name)))
        end
        return ("Current bounded keybinds: \n%s"):format(table.concat(genericKeybindList, '\n'))
    end,
}

CommandsAPIService.PostCommand {
    Name = "fly",
    Description = "Set flight mode enabled",
    Callback = function()
        toggleFlyState(true)
    end
}

CommandsAPIService.PostCommand {
    Name = "unfly",
    Description = "Set flight mode disabled",
    Callback = function()
        toggleFlyState(false)
    end
}

CommandsAPIService.PostCommand {
    Name = "setgenerickeybindof",
    Description = "Set a keybind of a Generic Keybind to something else",
    Callback = function(of: string, keybind: string)
        if GLOBAL.GenericKeybinds[of] == nil then
            local genericKeybindList = {}
            for key in pairs(GLOBAL.GenericKeybinds) do
                table.insert(genericKeybindList, key)
            end
            error(("%s is not a bound keybind, bounded keys are:\n%s"):format(of, table.concat(genericKeybindList, '\n')))
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

do
    RunService:BindToRenderStep("FlyUpdate", Enum.RenderPriority.Input.Value - 1, function(dt)
        if canPlayerFly and flightStateEnabled then
            if humanoidRootPart or (humanoid and humanoid.Health <= 0) then
                local dir = Vector3.zero
                if flyInputs[Enum.KeyCode.A] then
                    dir -= Vector3.xAxis
                end
                if flyInputs[Enum.KeyCode.D] then
                    dir += Vector3.xAxis
                end
                if flyInputs[Enum.KeyCode.W] then
                    dir -= Vector3.zAxis
                end
                if flyInputs[Enum.KeyCode.S] then
                    dir += Vector3.zAxis
                end
                local input = workspace.CurrentCamera.CFrame:VectorToWorldSpace(dir)
                if input:Dot(input) > 0 then
                    input = input.Unit*flightSpeed
                end
                local pos = humanoidRootPart.Position + input
                flyMovers.position.Position = pos
                flyMovers.orientation.CFrame = CFrame.lookAt(Vector3.zero, workspace.CurrentCamera.CFrame.LookVector)
            end
        end
    end)
    table.insert(GLOBAL.GenericCleanup, function()
        RunService:UnbindFromRenderStep("FlyUpdate")
    end)
end
table.insert(GLOBAL.GenericCleanup, Players.LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))
table.insert(GLOBAL.GenericCleanup, UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
    if gpe then return end
    if input.KeyCode == GLOBAL.GenericKeybinds.Teleport then
        if canPlayerTeleportToMouse then
            if humanoidRootPart then
                if humanoid.Health <= 0 then
                    return
                end
                local result = RaycastToMouse()
                local position = result.Position+result.Normal*2
                humanoidRootPart.CFrame = CFrame.new(position) * CFrame.lookAt(Vector3.zero, humanoidRootPart.CFrame.LookVector)
            end
        end
    elseif input.KeyCode == GLOBAL.GenericKeybinds.Fly then
        toggleFlyState(not flightStateEnabled)
    elseif flyInputs[input.KeyCode] ~= nil then
        flyInputs[input.KeyCode] = true
    end
end))
table.insert(GLOBAL.GenericCleanup, RunService.Stepped:Connect(function()
    if flightStateEnabled then
        for cache in pairs(cacheParts) do
            cache.CanCollide = false
        end
    end
end))
table.insert(GLOBAL.GenericCleanup, UserInputService.InputEnded:Connect(function(input: InputObject, gpe: boolean)
    if flyInputs[input.KeyCode] ~= nil then
        flyInputs[input.KeyCode] = false
    end
    if gpe then return end
end))

if Players.LocalPlayer.Character then
    OnCharacterAdded(Players.LocalPlayer.Character)
end