
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

    Spoof.new("Lightning Barrage", true, function(old)
        local result = RaycastToMouse()
        return {Direction = CFrame.new(result.Position - Vector3.new(0, 16, 0)) * CFrame.lookAt(Vector3.zero, Vector3.yAxis)}
    end)
    Spoof.new("Orbital Strike", function(old)
        local result = RaycastToMouse()
        return CFrame.new(result.Position) * CFrame.lookAt(Vector3.zero, Vector3.yAxis)
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
        if spoof and spoof.Enabled then
            args[3] = spoof.Callback(args[3])
        end
        return spoofHook(self, table.unpack(args))
    end
    return spoofHook(self, ...)
end)

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
        return ("Current spoofable spells: \n%q"):format(table.concat(spoofable, '\n'))
    end,
}