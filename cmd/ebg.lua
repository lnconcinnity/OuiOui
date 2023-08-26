
local GLOBAL = getgenv()

local require = GLOBAL.require
local CommandsAPIService = GLOBAL.CommandsAPIService
local MakeChatSystemMessage = GLOBAL.MakeChatSystemMessage
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
        local result = ResultCollage.CFArg(Vector3.new(0, 25, 0))
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
        return {Origin = ResultCollage.CFArg(Vector3.new(0, 1.5, 0)).Position}
    end)
    Spoof.new("Auroral Blast", false, function(old)
        return {Origin = ResultCollage.CFArg(Vector3.new(0, 1.5, 0)).Position}
    end)
    Spoof.new("Blaze Column", false, function(old)
        local result = ResultCollage.CFArg(Vector3.new(0, -1.5, 0))
        return result * CFrame.Angles(math.pi / 2, -math.pi / 2, math.rad(25))
    end)
    Spoof.new("Arcane Gaurdian", false, function(old)
        local result = ResultCollage.CFArg(Vector3.new(0, 26, 0))
        return result
    end)
end

local REDUCED_MANA_CLASSES = {}
REDUCED_MANA_CLASSES['proj'] = false
REDUCED_MANA_CLASSES['multi'] = false
REDUCED_MANA_CLASSES['aoe'] = false

local spoofHook; spoofHook = hookmetamethod(game, '__namecall', function(self, ...)
    if getnamecallmethod() == "InvokeServer" and self.Name == "DoMagic" then
        local args = {...}
        local spellName = args[2]
        local spoof = GLOBAL.SpoofedSpells[spellName]
        if spoof and spoof.Enabled == true then
            args[3] = spoof.Callback(args[3])
        end
        return spoofHook(self, table.unpack(args))
    end
    return spoofHook(self, ...)
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