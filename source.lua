local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

type CommandInfo = {
    Name: string,
    Description: string?,
    Callback: (...any) -> (),
    Arguments: {[string]: string | {string}}?
}

local OUT_ERROR_COLOR = Color3.fromRGB(255, 22, 0)
local OUT_WARN_COLOR = Color3.fromRGB(255, 199, 50)
local OUT_INFO_COLOR = Color3.fromRGB(198, 255, 244)

local CommandPrefix = ";"

local require do
    local oldRequire = require
    local SEPERATOR = "/"
    local EXTENSION = ".lua"
    local ORIGIN = string.format("https://raw.githubusercontent.com/%s/OuiOui/%s/cmd",
        "weeeeee8", -- user
        "main" -- branch
    )
    local cache = {}
    require = function(path: string | Instance): any
        if type(path) == "string" then
            if cache[path] then
                return cache[path]
            end
            local ok, content = pcall(game.HttpGet, game, ORIGIN..path..EXTENSION)
            if not ok then
                error(string.format("Unable to fetch request to (%s)", path..EXTENSION), 2)
            else
                local _path = string.split(path, SEPERATOR)
                local name = _path[#_path]:sub(1, #_path[#_path]-#EXTENSION)
                local src = loadstring(content, name)
                if not src then
                    error("Cannot find the source code for " .. name, 2)
                end
                src = src()
                cache[path] = src
                return src
            end
        elseif typeof(path) == "Instance" then
            return oldRequire(path)
        else
            error("Invalid type of import, expect string or Instance, got " .. typeof(path), 2)
        end
    end

    getgenv().require = require
end

local function sendOutMessageToChat(text: string, color: Color3?, textSize: number?)
    assert(#text > 0, "Argument 1 must be a non-empty string")
    local config = {
        Text = text,
        Color = color or OUT_INFO_COLOR,
        Font = Enum.Font.SourceSansSemibold,
        TextSize = textSize or 18,
    }
    StarterGui:SetCore('ChatMakeSystemMessage', config)
end
getgenv().MakeChatSystemMessage = {
    Out = sendOutMessageToChat,
    Colors = {OUT_ERROR_COLOR, OUT_WARN_COLOR, OUT_INFO_COLOR}
}


local ArgumentParser = {} do
    local OPTIONAL = "opt"
    local PLAYER_TYPE = "plr"

    local function validateType(type, stype)
        if stype == OPTIONAL then
            return true
        elseif (type == "number" or type == "boolean") then
            return type == stype, ("Invalid type, expected %s, got %s"):format(stype, type)
        elseif type == "string" then
            if stype == PLAYER_TYPE then
                return true, "Player"
            end
        end
        return true
    end

    function ArgumentParser.new(args: {[string]: string | {string}})
        local types = {}
        for _, k in next, args do
            table.insert(types, k)
        end
        return setmetatable({args = args, types = types}, {__index = ArgumentParser})
    end

    function ArgumentParser:Validate(out: any, index: number)
        local t = type(out)
        if type(self.types[index]) == "table" then
            local ok = false
            for i = 1, #self.types[index] do
                local ok_ = validateType(t, self.types[index][i])
                if ok_ then
                    ok = true
                    break
                end
            end
            return ok
        else
            return validateType(t, self.types[index])
        end
    end
end

local Command = {} do
    local ParsedCommand = {}
    function ParsedCommand.new(command: {}, args: {string}, callback: (...any) -> ())
        return setmetatable({
            Command = command,
            Arguments = args,
            Callback = callback,
        }, {__index = ParsedCommand})
    end

    function ParsedCommand:Parse()
        local newArgs = {}
        local oldArgs = self.Arguments
        for i = 1, #oldArgs do
            local arg = oldArgs[i]
            local boolOk, boolArg = pcall(HttpService.JSONDecode, HttpService, arg)
            local out = (if boolOk then boolArg else nil) or tonumber(arg) or tostring(arg)
            if self.Command.Parser then
                local ok, typeOrErr = self.Command.Parser:Validate(out, i)
                if ok then
                    if typeOrErr == "Player" then
                        local player = Players:FindFirstChild(arg)
                        if not player then
                            return false, "Could not find the player " .. arg
                        end
                        out = player
                    end
                else
                    return false, typeOrErr
                end
            end
            newArgs[i] = out
        end
        self.Arguments = newArgs
        return true
    end

    function ParsedCommand:Run()
        local ok, errOrOut = pcall(self.Callback, table.unpack(self.Arguments))
        if ok then
            return true, errOrOut
        else
            return false, errOrOut
        end
    end

    function Command.new(name: string, desc: string?, callback: (...any) -> (), autotCompletePriority: number, args: {[string]: string | {string}}?)
        local self = {
            Name = name,
            Description = desc,
            Callback = callback,
            Priority = autotCompletePriority,
            Parser = if args then ArgumentParser.new(args) else nil,
        }

        return setmetatable(self, {__index = Command})
    end

    function Command:FromArguments(args: {string})
        return ParsedCommand.new(self, args, self.Callback)
    end
end

local CommandStorageAPI = {} do
    local COMMANDS = {}
    function CommandStorageAPI.PostCommand(commandInfo: CommandInfo)
        COMMANDS[commandInfo.Name] = Command.new(commandInfo.Name, commandInfo.Description, commandInfo.Callback, commandInfo.Priority, commandInfo.Arguments)
    end

    function CommandStorageAPI.RemoveCommand(name: string)
        if COMMANDS[name] then
            COMMANDS[name]:Destroy()
            COMMANDS[name] = nil
        end
    end
    function CommandStorageAPI.GetCommand(name: string)
        return COMMANDS[name]
    end
    function CommandStorageAPI.GetCommands()
        return COMMANDS
    end
    getgenv().CommandsAPIService = CommandStorageAPI
end

local Dispatcher = {} do
    -- took it off cmdr
    local function charCode(n)
        return utf8.char(tonumber(n, 16))
    end

    local function parseEscapeSequences(text)
        return text:gsub("\\(.)", {
            t = "\t",
            n = "\n",
        })
            :gsub("\\u(%x%x%x%x)", charCode)
            :gsub("\\x(%x%x)", charCode)
    end
    
    local function encodeControlChars(text)
        return (
            text:gsub("\\\\", "___!ESCAPE!___")
                :gsub('\\"', "___!QUOTE!___")
                :gsub("\\'", "___!SQUOTE!___")
                :gsub("\\\n", "___!LN!___")
        )
    end
    
    local function decodeControlChars(text)
        return (text:gsub("___!ESCAPE!___", "\\"):gsub("___!QUOTE!___", '"'):gsub("___!LN!___", "\n"))
    end

    local function splitString(text, max)
        text = encodeControlChars(text)
        max = max or math.huge
        local t = {}
        local spat, epat = [=[^(['"])]=], [=[(['"])$]=]
        local buf, quoted
        for str in text:gmatch("[^ ]+") do
            str = parseEscapeSequences(str)
            local squoted = str:match(spat)
            local equoted = str:match(epat)
            local escaped = str:match([=[(\*)['"]$]=])
            if squoted and not quoted and not equoted then
                buf, quoted = str, squoted
            elseif buf and equoted == quoted and #escaped % 2 == 0 then
                str, buf, quoted = buf .. " " .. str, nil, nil
            elseif buf then
                buf = buf .. " " .. str
            end
            if not buf then
                t[#t + (#t > max and 0 or 1)] = decodeControlChars(str:gsub(spat, ""):gsub(epat, ""))
            end
        end

        if buf then
            t[#t + (#t > max and 0 or 1)] = decodeControlChars(buf)
        end

        return t
    end

    function Dispatcher:Evaluate(text: string)
        if #text >= 100_000 then
            return false, "Input is too long"
        end

        local arguments = splitString(text)
        local commandName = table.remove(arguments, 1)
        if commandName == nil then
            return false, "Empty field, please use the help command to see all commands."
        end
        local commandObject = CommandStorageAPI.GetCommand(commandName)
        if commandObject then
            local command = commandObject:FromArguments(arguments)
            local success, errorText = command:Parse()
            if success then
                return command
            else
                return false, errorText
            end
        else
            return false, string.format("%s is not a valid command, please use the help command to see all commmands.", commandName)
        end
    end

    function Dispatcher:Run(...)
        local args = table.pack(...)
        local text = args[1]
        for i = 2, args.n do
            text = text .. " " .. tostring(args[i])
        end
        local command, errText = self:Evaluate(text)
        if not command then
            sendOutMessageToChat(errText, OUT_ERROR_COLOR)
            return
        end

        local ok, out = command:Run()
        if out then
            sendOutMessageToChat(out, if ok then OUT_WARN_COLOR else OUT_ERROR_COLOR)
        end
    end
end

local Player = Players.LocalPlayer
local function hasPrefix(text: string)
    return text:sub(1, 1) == CommandPrefix and text:sub(2, 2) ~= CommandPrefix
end

local function onPlayerChatted(message: string)
    if message:sub(1, 1) == "/" then
        local contents = string.split(message, " ")
        local _ = table.remove(contents, 1)
        if hasPrefix(contents[1]) then
            contents[1] = contents[1]:sub(2, #contents[1]) -- remove the prefix
            Dispatcher:Run(table.unpack(contents))
        end
    elseif hasPrefix(message) then
        message = message:sub(2, #message)
        local contents = string.split(message, " ")
        Dispatcher:Run(table.unpack(contents))
    end
end
Player.Chatted:Connect(onPlayerChatted)

-- import built in commands
require('/builtIn')
sendOutMessageToChat("OuiOui imported!", OUT_INFO_COLOR, 24)