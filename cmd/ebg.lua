local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GLOBAL = getgenv()

local require = GLOBAL.require
local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage
local GetNearestPlayer = GLOBAL.GetNearestPlayer
local GetNearestPlayersFromRadius = GLOBAL.GetNearestPlayersFromRadius
local RaycastToMouse = GLOBAL.RaycastToMouse

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
        return {Origin = ResultCollage.CFArg(Vector3.new(0, -2, 0)).Position}
    end)
    Spoof.new("Auroral Blast", false, function(old)
        return {Origin = ResultCollage.CFArg(Vector3.new(0, -2, 0)).Position}
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

local CombatRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat")

local autoPunchActive = false
local infStaminaActive = false
local recordingSpellInfo = false

local spellNameHistory = {}

local lastPunchIteration = 0

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
        return "Successfully " .. (if (if default then default else true) then "spoofed " else "unspoofed ") .. "spells: " .. table.concat({...}, "\n")
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
        return "Successfully " .. (if (if default then default else true) then "spoofed " else "unspoofed ") .. "every spell"
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
        end
        return "Successfully " .. (if (if default then default else true) then "spoofed " else "unspoofed ") .. spellName
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
        setclipboard(("%q"):format(table.concat(spellNameHistory, ",")))
        return "Copied spell name history"
    end
}

CommandsAPIService.PostCommand {
    Name = "toggleinfstamina",
    Description = "Toggle infite stamina, running and flipping won't consume any stamina",
    Callback = function(out: boolean)
        infStaminaActive = out
    end,
    Arguments = {out = "boolean"}
}


CommandsAPIService.PostCommand {
    Name = "toggleautopunch",
    Description = "Toggle autopunch, will punch players inside a 12-stud radius",
    Callback = function(out: boolean)
        autoPunchActive = out
    end,
    Arguments = {out = "boolean"}
}

table.insert(GLOBAL.GenericCleanup, RunService.Heartbeat:Connect(function(dt)
    if autoPunchActive then
        local now = tick()
        if now >= lastPunchIteration then
            lastPunchIteration = now + 0.178
            local nearestPlayers = GetNearestPlayersFromRadius()
            if nearestPlayers and #nearestPlayers > 0 then
                for _, player in ipairs(nearestPlayers) do
                    CombatRemote:FireServer(1)
                    CombatRemote:FireServer(player.Character)
                end
            end
        end
    end
end))