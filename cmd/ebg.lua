local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GLOBAL = getgenv()

local require = GLOBAL.require
local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage
local GetNearestPlayer = GLOBAL.GetNearestPlayer
local GetNearestPlayersFromRadius = GLOBAL.GetNearestPlayersFromRadius
local RaycastToMouse = GLOBAL.RaycastToMouse
local GetHumanoidRootPart, GetHumanoid = GLOBAL.GetHumanoidRootPart, GLOBAL.GetHumanoid

GLOBAL.GenericKeybinds.AutoPunch = Enum.KeyCode.Z
GLOBAL.GenericKeybinds.InfStamina = Enum.KeyCode.C
GLOBAL.GenericKeybinds.InverseMovement = Enum.KeyCode.V
GLOBAL.GenericKeybinds.Brazil = Enum.KeyCode.X
GLOBAL.GenericKeybinds.Aimbot = Enum.KeyCode.L

GLOBAL.GenericTargetPlayer = nil

GLOBAL.SpoofedSpells = {} do
    local Spoof = {}
    function Spoof.new(name: string, default: boolean?, callback: (old: any) -> any)
        local self = {
            Name = name,
            Enabled = if default ~= nil then default else false,
            Callback = callback
        }
        GLOBAL.SpoofedSpells[name] = self
        return self
    end

    local ResultCollage = {}
    ResultCollage.CFArg = function(offset)
        local result = RaycastToMouse(nil, true)
        return CFrame.new(result.Position + if offset then offset else Vector3.new(0, 0.25, 0))
    end

    Spoof.new("Lightning Barrage", false, function(old)
        local result = ResultCollage.CFArg(Vector3.new(0, 28, 0))
        return {Direction = result * CFrame.lookAt(Vector3.zero, Vector3.yAxis)}
    end)
    Spoof.new("Orbital Strike", false, function(old)
        local result = ResultCollage.CFArg()
        return result * CFrame.lookAt(Vector3.zero, Vector3.yAxis)
    end)
    Spoof.new("Splitting Slime", false, function(old)
        local result = ResultCollage.CFArg()
        return result
    end)
    Spoof.new("Illusive Atake", false, function(old)
        local result = ResultCollage.CFArg()
        return result
    end)
    Spoof.new("Water Beam", false, function(old)
        local result = RaycastToMouse(nil, true)
        return {Origin = result.Position+(result.Normal*2)}
    end)
    Spoof.new("Auroral Blast", false, function(old)
        local result = RaycastToMouse(nil, true)
        return {Origin = result.Position+(result.Normal*2)}
    end)
    Spoof.new("Blaze Column", false, function(old)
        local result = ResultCollage.CFArg(Vector3.new(0, -1.5, 0))
        return result * CFrame.Angles(math.pi / 2, -math.pi / 2, math.rad(25))
    end)
    Spoof.new("Arcane Guardian", false, function(old)
        local result = ResultCollage.CFArg(Vector3.new(0, 26, 0))
        return {Position = result.Position}
    end)
end

local AIMBOT_MASS = 60 / 1000 -- m=v/t
local UNRENDER_POSITION = Vector3.yAxis*10e5
local SPAWN_LOCATIONS_BY_PLACE_IDS = {
    [2569625809] = Vector3.new(-10e5, 100, 0)
}

local CombatRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat")
local KeyReserve = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("KeyReserve")
local ReverseSpeed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReverseSpeed")
local DoMagic = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DoMagic")
local DoClientMagic = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DoClientMagic")

local AIMBOT_HEADER = Instance.new("Part")
AIMBOT_HEADER.Anchored = true
AIMBOT_HEADER.CanCollide = false
AIMBOT_HEADER.CastShadow = false
AIMBOT_HEADER.CFrame = CFrame.identity
AIMBOT_HEADER.Size = Vector3.one*1
AIMBOT_HEADER.CanTouch = false
AIMBOT_HEADER.CanQuery = false
AIMBOT_HEADER.Material = Enum.Material.Neon
AIMBOT_HEADER.Color = Color3.new(1, 0, 1)
AIMBOT_HEADER.Parent = workspace.CurrentCamera
local AIMBOT_HEADER_HIGHLIGHT = Instance.new("Highlight")
AIMBOT_HEADER_HIGHLIGHT.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
AIMBOT_HEADER_HIGHLIGHT.FillTransparency = 0
AIMBOT_HEADER_HIGHLIGHT.FillColor = Color3.new(1, 0, 1)
AIMBOT_HEADER_HIGHLIGHT.OutlineTransparency = 0
AIMBOT_HEADER_HIGHLIGHT.Parent = AIMBOT_HEADER

local autoPunchActive = false
local infStaminaActive = false
local recordingSpellInfo = false
local brazilEnabled = false
local reverseSpeedEnabled = false
local aimbotEnabled = false

local activelyDoingBrazilTroll = false
local activelyRecordingDamage = false
local playerMouse = Players.LocalPlayer:GetMouse()

local aimbotMousePosition = Vector3.zero

local brazilTeleportDelay = 3.07
local brazilTargetLocation = 2-- 1 = spawn, 2 = void, 3 = nullzone
local spellNameHistory = {}

local lastPunchIteration = 0

local mouseIndexHook; mouseIndexHook = hookmetamethod(playerMouse, '__index', function(self, key)
    if key == "Hit" then
        local result = RaycastToMouse(nil, true)
        if aimbotEnabled then
            local target =  GLOBAL.GenericTargetPlayer
            local humanoid = if target.Character then target.Character:FindFirstChild("Humanoid") else nil
            if humanoid and humanoid.Health > 0 then
                return CFrame.new(aimbotMousePosition) * CFrame.lookAt(Vector3.zero, if humanoid.RootPart then (if humanoid.RootPart.AssemblyLinearVelocity:Dot(humanoid.RootPart.AssemblyLinearVelocity) > 0 then humanoid.RootPart.AssemblyLinearVelocity.Unit else humanoid.RootPart.CFrame.LookVector) else workspace.CurrentCamera.CFrame.LookVector)
            end
        end
        return CFrame.new(result.Position) * CFrame.lookAt(Vector3.zero, result.Normal)
    end
    return mouseIndexHook(self, key)
end)

local namecallHook; namecallHook = hookmetamethod(game, '__namecall', function(self, ...)
    if getnamecallmethod() == "InvokeServer" then
        if self.Name == "DoMagic" then
            local args = {...}
            local spellName = args[2]
            local spoof = GLOBAL.SpoofedSpells[spellName]
            if spoof and spoof.Enabled == true then
                args[3] = spoof.Callback(args[3])
            end
            return namecallHook(self, table.unpack(args))
        end
    elseif getnamecallmethod() == "FireServer" then
        if self.Name == "PlayerData" then
            if infStaminaActive then
                local args = {...}
                if args[1] == "Flip" then
                    args[1] = ""
                elseif args[1] == "Running" then
                    args[2] = false
                end
                return namecallHook(self, table.unpack(args))
            end
        elseif self.Name == "DoClientMagic" then
            if recordingSpellInfo then
                local spellName = select(2, ...)
                spellNameHistory[#spellNameHistory+1] = spellName
            end
        end
    end
    return namecallHook(self, ...)
end)

CommandsAPIService.PostCommand {
    Name = "groupspoof",
    Description = "Spoof a group spells to cause mayhem!",
    Callback = function(default: boolean?, ...)
        for _, key in ipairs({...}) do
            local spoof = GLOBAL.SpoofedSpells[key]
            if spoof then
                spoof.Enabled = if default ~= nil then default else true
            end
        end
        return "Successfully " .. (if (if default ~= nil then default else true) then "spoofed " else "unspoofed ") .. "spells: " .. table.concat({...}, "\n")
    end,
    Arguments = {spellName = "string", toggle = {"boolean", "opt"}}
}

CommandsAPIService.PostCommand {
    Name = "spoofall",
    Description = "Spoof a all spells to cause mayhem!",
    Callback = function(default: boolean?)
        for _, spoof in pairs(GLOBAL.SpoofedSpells) do
            spoof.Enabled = if default ~= nil then default else true
        end
        return "Successfully " .. (if (if default ~= nil then default else true) then "spoofed " else "unspoofed ") .. "every spell"
    end,
    Arguments = {spellName = "string", toggle = {"boolean", "opt"}}
}

CommandsAPIService.PostCommand {
    Name = "spoofspell",
    Description = "Spoof a specific spell to cause mayhem!",
    Callback = function(spellName: string, default: boolean?)
        local spoof = GLOBAL.SpoofedSpells[spellName]
        if spoof then
            spoof.Enabled = if default ~= nil then default else true
            return "Successfully " .. (if spoof.Enabled then "spoofed " else "unspoofed ") .. spellName
        end
        return "Unable to find spell " .. spellName
    end,
    Arguments = {spellName = "string", toggle = {"boolean", "opt"}}
}

CommandsAPIService.PostCommand {
    Name = "unspoofspell",
    Description = "Unspoof a spell, returning them back to their original functionality",
    Callback = function(spellName: string)
        local spoof = GLOBAL.SpoofedSpells[spellName]
        if spoof then
            spoof.Enabled = false
        end
        return "Successfully unspoofed " .. spellName
    end,
    Arguments = {spellName = "string"}
}

CommandsAPIService.PostCommand {
    Name = "showspoofable",
    Description = "Show the list of spoofable spells",
    Callback = function()
        local spoofable = {}
        for key in pairs(GLOBAL.SpoofedSpells) do
            table.insert(spoofable, key)
        end
        return ("Current spoofable spells: \n%s"):format(table.concat(spoofable, '\n'))
    end,
}

CommandsAPIService.PostCommand {
    Name = "devrecordspellnames",
    Description = "Record spell names, mostly for testing and spell gathering purposes",
    Callback = function()
        table.clear(spellNameHistory)
        recordingSpellInfo = true
        return "Recording spell name history"
    end
}

CommandsAPIService.PostCommand {
    Name = 'devstoprecordspellnames',
    Description = "Stop recording spell names, mostly for testing and spell gathering purposes",
    Callback = function()
        recordingSpellInfo = false
        return "Stopped recording spell name history"
    end
}

CommandsAPIService.PostCommand {
    Name = 'devcopyspellnamehistory',
    Description = "Copy recorded spell name  history mostly for testing and spell gathering purposes",
    Callback = function()
        if #spellNameHistory <= 0 then
            return "Nothing to copy from spell name history"
        end
        setclipboard(("%s"):format(table.concat(spellNameHistory, ",")))
        return "Copied spell name history"
    end
}

CommandsAPIService.PostCommand {
    Name = "toggleinfstamina",
    Description = "Toggle infite stamina, running and flipping won't consume any stamina",
    Callback = function(out: boolean)
        infStaminaActive = if out ~= nil then out else false
        return (if infStaminaActive then "Enabled" else "Disabled") .. " infinite stamina"
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "toggleaura",
    Description = "Toggle punch aura, will punch players inside a 12-stud radius",
    Callback = function(out: boolean)
        autoPunchActive = if out ~= nil then out else false
        return (if autoPunchActive then "Enabled" else "Disabled") .. " auto punch"
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "toggleaimbot",
    Description = "Toggle if you want to your movement to be inverted or not when hit by Ace up the sleeve spell",
    Callback = function(out: boolean)
        aimbotEnabled = if out ~= nil then out else false
        AIMBOT_HEADER_HIGHLIGHT.Adornee = if aimbotEnabled then AIMBOT_HEADER else nil
        return (if reverseSpeedEnabled then "Enabled" else "Disabled") .. " aimbot"
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "togglereversespeed",
    Description = "Toggle if you want to your movement to be inverted or not when hit by Ace up the sleeve spell",
    Callback = function(out: boolean)
        reverseSpeedEnabled = if out ~= nil then out else false
        for _, connection in ipairs(getconnections(ReverseSpeed.OnClientEvent)) do
            connection[if reverseSpeedEnabled then "Enable" else "Disable"](connection)
        end
        return (if reverseSpeedEnabled then "Enabled" else "Disabled") .. " movement inversion"
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "setbrazilenabled",
    Description = "A troll command where, as long as you have disorder ignition, you send the to a target location defined by the command 'setbrazilloc'",
    Callback = function(out: boolean)
        brazilEnabled = if out ~= nil then out else false
        return (if brazilEnabled then "Enabled" else "Disabled") .. " Brazil Troll command"
    end,
    Arguments = {out = "boolean"}
}

CommandsAPIService.PostCommand {
    Name = "setbrazilloc",
    Description = "Set the target destination of the troll",
    Callback = function(option: number)
        if option > 3 or option < 1 then
            error("Destination must be an interger between 1 to 3")
        end
        brazilTargetLocation = option
        return ("Set target location to %s"):format(if option == 1 then "Spawn" elseif option == 2 then "Void" else "Floating point")
    end
}

CommandsAPIService.PostCommand {
    Name = "recorddamageoutput",
    Description = "Record the overall damage dealt to the set target player",
    Callback = function()
        if activelyRecordingDamage then
            return "Currently recording damage, please wait"
        end
        local target = GLOBAL.GenericTargetPlayer
        local humanoid = if target.Character then target.Character:FindFirstChild("Humanoid") else nil
        if humanoid then
            activelyRecordingDamage = true

            local lastIncomingDamage = 0
            local start = tick()
            local recording = false
            local hpChanged, recordingUpdate;

            local totalDamage = 0

            local function setupRecorder()
                recordingUpdate = RunService.Heartbeat:Connect(function()
                    local now = tick()
                    if now - lastIncomingDamage >= 3 or now - start >= 10 then
                        if hpChanged then hpChanged:Disconnect() end
                        if recordingUpdate then recordingUpdate:Disconnect() end
                        activelyRecordingDamage = false
                        if totalDamage <= 0 then
                            MakeChatSystemMessage.Out("No damage was taken within recording time", MakeChatSystemMessage.Colors[1])
                        else
                            MakeChatSystemMessage.Out("Dealt a total of " .. tostring(totalDamage * 10) .. " damage", MakeChatSystemMessage.Colors[2])
                        end
                    end
                end)
            end

            local _oldHealth = 0
            local baseHealth = nil
            hpChanged = humanoid.HealthChanged:Connect(function(health)
                if health < _oldHealth then
                    lastIncomingDamage = tick()
                    if not baseHealth then
                        baseHealth = humanoid.Health
                    end
                    if not recording then
                        recording = true
                        setupRecorder()
                    end

                    totalDamage = baseHealth - health
                end
                _oldHealth = health
            end)

            target.Destroying:Connect(function()
                activelyRecordingDamage = false
                if hpChanged then hpChanged:Disconnect() end
                if recordingUpdate then recordingUpdate:Disconnect() end
                MakeChatSystemMessage.Out("Target left the server", MakeChatSystemMessage.Colors[1])
            end)
        else
            MakeChatSystemMessage.Out("Target does not exist", MakeChatSystemMessage.Colors[1])
        end
    end
}

table.insert(GLOBAL.GenericCleanup, RunService.Heartbeat:Connect(function(dt)
    if autoPunchActive then
        local now = tick()
        if now >= lastPunchIteration then
            lastPunchIteration = now + 0.178
            local nearestPlayers = GetNearestPlayersFromRadius()
            if nearestPlayers and #nearestPlayers > 0 then
                for _, player in ipairs(nearestPlayers) do
                    CombatRemote:FireServer(player.Character)
                    CombatRemote:FireServer(1)
                end
            end
        end
    end
end))
table.insert(GLOBAL.GenericCleanup, RunService.Stepped:Connect(function(t, dt)
    if aimbotEnabled then
        local target = GLOBAL.GenericTargetPlayer
        local rootPart = if target.Character then target.Character:FindFirstChild("HumanoidRootPart") else nil
        if rootPart then
            local v1 = rootPart.AssemblyLinearVelocity
            local t1 = v1/AIMBOT_MASS
            local t2 = t1 + 0.2*Vector3.one
            local v2 = AIMBOT_MASS*t2
            local d = 0.5*(t2-t1)*(v2+v1)
            aimbotMousePosition = rootPart.Position+d
            AIMBOT_HEADER.Position = aimbotMousePosition
        else
            AIMBOT_HEADER.Position = UNRENDER_POSITION
        end
    else
        AIMBOT_HEADER.Position = UNRENDER_POSITION
    end
end))
table.insert(GLOBAL.GenericCleanup, UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
    if gpe then return end
    if input.KeyCode == GLOBAL.GenericKeybinds.AutoPunch then
        autoPunchActive = not autoPunchActive
        MakeChatSystemMessage.Out((if autoPunchActive then "Enabled" else "Disabled") .. " auto punch", MakeChatSystemMessage.Colors[2])
    elseif input.KeyCode == GLOBAL.GenericKeybinds.InfStamina then
        infStaminaActive = not infStaminaActive
        MakeChatSystemMessage.Out((if autoPunchActive then "Enabled" else "Disabled") .. " infinite stamina", MakeChatSystemMessage.Colors[2])
    elseif input.KeyCode == GLOBAL.GenericKeybinds.InverseMovement then
        reverseSpeedEnabled = not reverseSpeedEnabled
        for _, connection in ipairs(getconnections(ReverseSpeed.OnClientEvent)) do
            connection[if reverseSpeedEnabled then "Enable" else "Disable"](connection)
        end
        MakeChatSystemMessage.Out((if autoPunchActive then "Enabled" else "Disabled") .. " movement inversion", MakeChatSystemMessage.Colors[2])
    elseif input.KeyCode == GLOBAL.GenericKeybinds.Aimbot then
        aimbotEnabled = not aimbotEnabled
        AIMBOT_HEADER_HIGHLIGHT.Adornee = if aimbotEnabled then AIMBOT_HEADER else nil
        MakeChatSystemMessage.Out((if autoPunchActive then "Enabled" else "Disabled") .. " aimbot", MakeChatSystemMessage.Colors[2])
    elseif input.KeyCode == GLOBAL.GenericKeybinds.Brazil then
        if brazilEnabled then
            if not activelyDoingBrazilTroll then
                if GLOBAL.GenericTargetPlayer then
                    local target = GLOBAL.GenericTargetPlayer
                    local humanoid = if target.Character then target.Character:FindFirstChild("Humanoid") else nil
                    if humanoid and GetHumanoidRootPart() then
                        if target.Character:FindFirstChildOfClass("ForceField") then
                            MakeChatSystemMessage.Out("Current target is on a safezone", MakeChatSystemMessage.Colors[1])
                            return
                        end
                        MakeChatSystemMessage.Out("Simulating troll", MakeChatSystemMessage.Colors[2])
                        activelyDoingBrazilTroll = true

                        local targetPosition = humanoid.RootPart.Position
                        local fdt = math.min(GLOBAL.WorldDelta*60, 1)

                        local predict = targetPosition + humanoid.RootPart.CFrame.LookVector
                        local vel = humanoid.RootPart.AssemblyLinearVelocity
                        if vel:Dot(vel) > 0 then
                            local possibleFuture = targetPosition + (vel.Unit * humanoid.WalkSpeed)
                            local direction = (possibleFuture - targetPosition).Unit * GLOBAL.WorldDelta * (vel.Magnitude + (humanoid.WalkSpeed*1.2))
                            predict = targetPosition + direction
                        end
                        GetHumanoidRootPart().CFrame = CFrame.new(predict) * CFrame.new(Vector3.zero, workspace.CurrentCamera.CFrame.LookVector)
                        task.wait(0.174*fdt)
                        DoClientMagic:FireServer("Chaos", "Disorder Ignition")
                        DoMagic:InvokeServer("Chaos", "Disorder Ignition", {
                            nearestHRP = humanoid.Parent:FindFirstChild("Head"),
                            nearestPlayer = target,
                            rpos = targetPosition,
                            norm = Vector3.yAxis,
                            rhit = workspace:WaitForChild("Map"):WaitForChild("Part")
                        })
                        local can = true
                        local t = brazilTeleportDelay
                        repeat t -= task.wait()
                            if humanoid.Health <= 0 or humanoid.RootPart == nil or not GetHumanoidRootPart() or GetHumanoid().Health <= 0 or not target then
                                can = false
                                break
                            end
                        until t <= 0
                        if not GetHumanoidRootPart():FindFirstChild("ChaosLink") then can = false end
                        if can then
                            local goal = if brazilTargetLocation == 1 then SPAWN_LOCATIONS_BY_PLACE_IDS[game.PlaceId] elseif brazilTargetLocation == 2 then Vector3.new(0, workspace.FallenPartsDestroyHeight + 2.5, 0) else CFrame.new(math.huge, math.huge, math.huge).Position
                            -- teleport our player
                            GetHumanoidRootPart().CFrame = CFrame.new(goal) * CFrame.new(Vector3.zero, workspace.CurrentCamera.CFrame.LookVector)
                            task.wait(0.23*fdt)
                            KeyReserve:FireServer(Enum.KeyCode.Y)
                        else
                            MakeChatSystemMessage.Out("An error occured, (target missed or died, or you died)", MakeChatSystemMessage.Colors[1])
                        end
                        activelyDoingBrazilTroll = false
                    else
                        MakeChatSystemMessage.Out("Target does not exist", MakeChatSystemMessage.Colors[1])
                    end
                end
            else
                MakeChatSystemMessage.Out("A troll is currently commencing, please try again later", MakeChatSystemMessage.Colors[1])
            end
        end
    end
end))