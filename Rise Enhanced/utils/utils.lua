local utils = {}

utils.cache = {}

local function getPropertyTable(propertyTable, moduleName)
    if propertyTable == nil then return nil end
    if moduleName == nil then moduleName = "__general" end
    if type(propertyTable) ~= "table" then return { moduleName, propertyTable } end
    return { moduleName, table.unpack(propertyTable) }
end

local function callCache(propertyTable, moduleName, func, ...)
    if not utils.cache then return nil end
    utils.cache[func](getPropertyTable(propertyTable, moduleName), ...)
end

local function getCache(propertyTable, moduleName)
    if not utils.cache then return end
    return utils.cache.get(getPropertyTable(propertyTable, moduleName))
end

local function setCache(propertyTable, moduleName, value)
    if not utils.cache then return end
    utils.cache.set(getPropertyTable(propertyTable, moduleName), value)
end

-- Will set a value on cache only if the current value is nil, Warning: Cache resets on first load, will stay between script resets
local function setNilCache(propertyTable, moduleName, value)
    if getCache(propertyTable, moduleName) ~= nil then return end
    setCache(propertyTable, moduleName, value)
end

-- Returns a cache handler, similar to the settings handler but cache will be deleted on
-- game startup, only preservers values on script reset
-- if no moduleName is passed, it will be assinged to "__general"
function utils.getCacheHandler(_moduleName)
    if _moduleName == nil then _moduleName = "__general" end
    local handler = {
        name = _moduleName
    }

    -- Will set a value on cache only if the current value is nil, Warning: Cache resets on first load, will stay between script resets
    function handler.setNil(propertyTable, value)
        setNilCache(propertyTable, handler.name, value)
    end
    -- Calls a function (same functions as the settings handler ones) on the given path in cache, can call the imgui func if needed (recommended to avoid using cache for anything other than set and get) Warning: Cache resets on first load, will stay between script resets
    function handler.call(propertyTable, func, ...)
        callCache(propertyTable, handler.name, func, ...)
    end
    -- Sets a value to the cache, Warning: Cache resets on first load, will stay between script resets
    function handler.set(propertyTable, value)
        setCache(propertyTable, handler.name, value)
    end
    -- Gets a value from cache, Warning: Cache resets on first load, will stay between script resets
    function handler.get(propertyTable)
        return getCache(propertyTable, handler.name)
    end
    return handler
end


-- Returns settingsHandler, cacheHandler. settingsHandler handles and persists configuration, cacheHandler will only persist data on script resets
function utils.getHandlers(settingsDefaults,
        settingsFolder, settingsFilename, cacheModuleName)
    local settings = utils.getSettingsHandler(settingsDefaults,
        settingsFolder, settingsFilename)
    local cacheHandler = utils.getCacheHandler(cacheModuleName)
    return settings, cacheHandler
end

-- Useful functions

-- Return copy of a table
function utils.copy(original)
    if type(original) ~= "table" then return original end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = utils.copy(v)
    end
    return copy
end

function utils.contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end


local references = {
    singletons = {},
    definitions = {},
    custom = {},
}

local function getDefaultReference(keys, original, initialFunc, genericFunc)
    if original[keys[1]] == nil then
        original[keys[1]] = {
            func = initialFunc,
            args = {keys[1]}
        }
    end
    local reference = original[keys[1]]
    for i = 2, #keys do
        if reference[keys[i]] == nil then
            reference[keys[i]] = {
                func = genericFunc,
                args = {reference, keys[i]}
            }
        end
        reference = reference[keys[i]]
    end

    return reference.func(table.unpack(reference.args))
end

-- returns managed singleton and corresponding :call
function utils.singleton(...)
    return getDefaultReference(
        {...},
        references.singletons,
        function (singleton)
            return sdk.get_managed_singleton(singleton)
        end,
        function (parent, key)
            local parentRef = parent.func(table.unpack(parent.args))
            if parentRef == nil then
                return
            end
            return parentRef:call(key)
        end
    )
end

-- returns type definition and correspondig :get_method
function utils.definition(...)
    return getDefaultReference(
        {...},
        references.definitions,
        function (definition)
            return sdk.find_type_definition(definition)
        end,
        function (parent, key)
            return parent.func(table.unpack(parent.args)):get_method(key)
        end
    )
end

-- sets a reference to get later on
function utils.setReference(keys, getFunc, ...)
    if type(keys) == "string" then
        keys = {keys}
    end
    local reference = references.custom
    for i = 1, #keys - 1 do
        reference = reference[keys[i]]
    end
    if reference[keys[#keys]] == nil then
        reference[keys[#keys]] = {func = getFunc, args = {...}}
    end
end

-- gets a reference
function utils.reference(...)
    local keys = {...}
    local reference = references.custom
    for _, key in pairs(keys) do
        reference = reference[key]
    end

    return reference.func(table.unpack(reference.args))
end

-- Default function to call original
function utils.original(args)
    return sdk.PreHookResult.CALL_ORIGINAL
end

-- Default function to skip original
function utils.skip(args)
    return sdk.PreHookResult.SKIP_ORIGINAL
end

-- Default retval function
function utils.retval(retval)
    return retval
end

-- Formats number with comas every thousands or returns _default_text when number is equal to _default_at, _default_at denifed as 0 if not given
function  utils.formatNumber(number, _default_text, _default_at)
    if _default_text ~= nil then
        if _default_at == nil then
            _default_at = 0
        end
        if number == _default_at then
            return _default_text
        end
    end
    if number < 1000 and number > -1000 then
        return number
    end
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- Returns the duration text formatted
function utils.durationText(duration, singular, plural, _default_text, _default_at)
    if _default_text ~= nil and _default_at == nil then
        _default_at = 0
    end
    if duration == _default_at then
        return _default_text
    elseif duration == 1 then
        return string.format(singular, duration)
    else
        return string.format(plural, duration)
    end
end

-- Return whether or not the player is in battle
function utils.inBattle()
    local musicManager = utils.singleton("snow.wwise.WwiseMusicManager")
    if not musicManager then return false end

    local currentMusicType = musicManager:get_field("_FightBGMType")
    local currentBattleState = musicManager:get_field("_CurrentEnemyAction")

    local musicMixManager = utils.singleton("snow.wwise.WwiseMixManager")
    if not musicMixManager then return false end
    local currentMixUsed = musicMixManager:get_field("_Current")

    local questManager = utils.singleton("snow.QuestManager")
    if not questManager then return false end

    local currentQuestType = questManager:get_field("_QuestType")
    local currentQuestStatus = questManager:get_field("_QuestStatus")

    local inBattle = currentBattleState == 3 -- Fighting a monster
        or currentMixUsed == 37 -- Fighting a wave of monsters
        or currentMixUsed == 10 -- Stronger battle music mix is being used
        or currentMixUsed == 31 -- Used in some arena battles
        or currentQuestType == 64 -- Fighting in the arena (Utsushi)

    local isQuestComplete = currentQuestStatus == 3 -- Completed the quest
        or currentQuestStatus == 0 -- Not in a quest

    return inBattle and not isQuestComplete
end

-- Returns whether the quest es online or not, only works properly inside of mission
function utils.isQuestOnline()
    return utils.singleton("snow.stage.StageManager"):get_IsQuestOnline()
end

-- Returns the player count inside of a quest, will return 1 in lobby
function utils.getPlayerCount()
    if not utils.isQuestOnline() then return 1 end
    return utils.singleton("snow.QuestManager"):get_field("_TotalJoinNum")
end

-- Returns true if there are 2 or more players inside the quest, will return true on lobby
function utils.isMultiplayerQuest()
    return utils.getPlayerCount() > 1
end

-- Return the player, playerIndex, playerList[playerIndex + 1], playerList
function utils.getPlayerData()
    local playerDataManager = utils.singleton("snow.player.PlayerManager")
    local playerList = playerDataManager:get_field("<PlayerData>k__BackingField"):get_elements()
    local player = playerDataManager:call("findMasterPlayer")
    local playerIndex = player:call("getPlayerIndex")
    return player, playerIndex, playerList[playerIndex + 1], playerList
end

-- Returns the player
function utils.getPlayer()
    return utils.singleton("snow.player.PlayerManager", "findMasterPlayer")
end

-- Returns the current weapon
function utils.getPlayerWeapon()
    return utils.getPlayer():get_field("_playerWeaponType")
end

-- Returns true if the weapon is sheathed
function utils.isWeaponSheathed()
    local player = utils.getPlayer()
    local playerAction = utils.definition("snow.player.PlayerBase")
            :get_field("<RefPlayerAction>k__BackingField"):get_data(player)
    return utils.definition("snow.player.PlayerAction"):get_field("_weaponFlag")
            :get_data(playerAction) == 0
end

--
function utils.chat(message, sound, ...)
    if type(message) ~= "string" then return end
    if  sound == nil or not sound or type(sound) ~= "number" then
        sound = 0
    end
    utils.singleton("snow.gui.ChatManager"):call("reqAddChatInfomation", string.format(message, ...), sound)
end

-- Time handler

local timers = {}

-- Allows a function to be used with a delay in seconds
function utils.addTimer(delay, func)
    table.insert(timers, {
        delay = os.clock() + delay,
        action = func
    })
end

local time
local function tickTimers()
    time = os.clock()
    for i, timer in pairs(timers) do
        if timer.delay - time <= 0 then
            timer.action()
            timers[i] = nil
        end
    end
end

re.on_frame(tickTimers)

-- Settings handler

-- Search for the index in a table given certain value
function utils.tableSearch(table, value)
    for k, v in pairs(table) do
        if v == value then
            return k
        end
    end
    return nil
end

local function getFilePath(folder, _file)
    local filename
    if type(_file) == "string" then filename = _file end

    if not filename or filename == "" then
        filename = "config.json"
    elseif not filename:match(".json$") then
        filename = filename .. ".json"
    end

    return folder and (folder .. "/" .. filename) or filename
end

-- Makes handler, can have a default set of values and will autosave when a change ocurr
function utils.getSettingsHandler(defaults, folder, _filename)
    local settings = {
        data = {},
        default = utils.copy(defaults),
        file = getFilePath(folder, _filename),
    }

    local function load(_file)
        if json == nil then return end
        if _file == nil then _file = settings.file end
        settings.data = utils.copy(settings.default)
        local currentSettings = json.load_file(_file)

        if currentSettings ~= nil then
            local function updateValues(table, savedValues)
                for key, value in pairs(table) do
                    if savedValues[key] ~= nil then
                        if type(value) == "table" then
                            updateValues(value, savedValues[key])
                        else
                            table[key] = savedValues[key]
                        end
                    end
                end
            end
            updateValues(settings.data, currentSettings)
        end
    end

    load(settings.file)

    local function save(_table, _file)
        if json == nil then return end
        if _file == nil then _file = settings.file end
        if _table == nil then _table = settings.data end
        json.dump_file(_file, _table)
    end

    local function decodeProperty(propertyTable, table)
        local property, key, value
        if type(propertyTable) ~= "table" then propertyTable = { propertyTable } end
        if table == nil then table = settings.data end
        value = table
        local nilLastValue = false
        for _, v in pairs(propertyTable) do
            property = value
            key = v
            if property[key] == nil then
                property[key] = {}
                nilLastValue = true
            end
            value = property[key]
        end
        if nilLastValue then property[key] = nil end
        return property, key
    end

    -- Return the value given by the propertyTable, ex: settings.get({"skewerLvl", "top"}) will return settings.data.skewerLvl.top or settings.get("enabled") will return settings.data.enable
    function settings.get(propertyTable)
        local property, key = decodeProperty(propertyTable)
        return property[key]
    end

    -- Return a copy of the default value given by the propertyTable
    function settings.getDefault(propertyTable)
        local property, key = decodeProperty(propertyTable, settings.default)
        return utils.copy(property[key])
    end

    -- Sets value given by the propertyTable, _changed is optional and assumed as true, ex: settings.set({"skewerLvl", "top"}, 4) will set as settings.data.skewerLvl.top = 4, can also use settings.set("enabled", true) to set settings.data.enabled = true
    function settings.set(propertyTable, value, _changed)
        if _changed ~= nil and not _changed then return end
        local property, key = decodeProperty(propertyTable)
        property[key] = utils.copy(value)
        save()
    end

    -- Resets given setting, if no args given will reset the entire data structure
    function settings.reset(propertyTable)
        if propertyTable == nil then
            settings.data = utils.copy(settings.default)
            save()
        else
            local property, key = decodeProperty(propertyTable)
            if property == nil or key == nil then return end
            local defaultProperty, defaultKey = decodeProperty(propertyTable, settings.default)
            if defaultProperty == nil or defaultKey == nil then return end
            property[key] = utils.copy(defaultProperty[defaultKey])
            save()
        end
    end

    -- Call a given function, will autosave on change. func can be any function that returns "changed, value", ex: settings.imgui(.., imgui.checkbox, ..)
    function settings.call(propertyTable, func, ...)
        if type(func) ~= "function" then return end
        local property, key = decodeProperty(propertyTable)
        local args = {...}
        table.insert(args, 2, property[key])
        local changed, newValue = func(table.unpack(args))
        if changed == nil or newValue == nil then
            error("settings.call was called with an invalid func")
        end
        if changed then
            property[key] = newValue
            save()
        end

        return changed, newValue
    end

    -- Allows combo to return the value instead of the index of the table, accepts both index or values as defaults, _func is optional and assumed imgui.combo by default
    function settings.combo(propertyTable, label, table, _func)
        if _func == nil then _func = imgui.combo end
        if type(_func) ~= "function" then
            error("settings.combo was called with an invalid func")
        end
        local property, key = decodeProperty(propertyTable)
        local unindexed = false
        local value = property[key]
        if type(value) ~= "number" then
            unindexed = true
            value = utils.tableSearch(table, value)
        end
        local changed, newValue = _func(label, value, table)
        if unindexed then newValue = table[newValue] end
        if changed then
            property[key] = newValue
            save()
        end

        return changed, newValue
    end

    local function toStep(number, step)
        if type(step) == "number" then
            if step < 0 then
                local int, float = math.modf(number)
                float = math.floor(float / step + 0.5) * step
                return int + float
            else
                return math.floor(number / step + 0.5) * step
            end
        else
            return math.floor(number + 0.5) * 1
        end
    end

    --- Allows slider functions to have a default return (will be min - 1) or have steps in the slider.
    -- if _arg is a string or function that returns a string it will be used as the default display text on the slider for min - 1.
    -- if _arg is a number ex: settings.slider_int("cost", "Cost", 0, 1000, settings.data.cost, 10) will make the slider display and return numbers from 0 to 1000 in steps of 10.
    -- _func is optional and imgui.slider_int by default, will use imgui.slider_float if step is float
    function settings.slider(propertyTable, label, min, max, _text, _arg, _func)
        if _func == nil then _func = imgui.slider_int end
        if type(_func) ~= "function" then
            error("settings.slider was called with an invalid func")
        end
        local property, key = decodeProperty(propertyTable)
        local value = property[key]
        local inSteps = false
        local arguments, float
        if _arg == nil then
            arguments = {
                label,
                value,
                min,
                max,
                _text ~= nil and _text or value
            }
        elseif type(_arg) == "string" then
            arguments = {
                label,
                value,
                _arg ~= nil and min - 1 or min,
                max,
                value < min and _arg or _text
            }
        elseif type(_arg) == "number" then
            inSteps = true
            if math.type(_arg) == "float" then
                _func = imgui.slider_float
            end
            arguments = {
                label,
                value,
                min,
                max,
                _text ~= nil and _text or value
            }
        else
            error("settings.slider was called with an invalid arg (nil, string, number)")
        end
        local changed, newValue = _func(table.unpack(arguments))
        if inSteps then newValue = toStep(newValue, _arg) end
        if changed then
            property[key] = newValue
            save()
        end

        return changed, newValue
    end

    return settings
end

-- Quest manager

local questStatusName = {
    [0] = "menu/lobby",
    [1] = "loading",
    [2] = "quest",
    [3] = "end",
    [5] = "abandoned",
    [7] = "returned",
}

local questFlowName = {
    [0] = "quest",
    [1] = "countdown",
    [8] = "animation",
    [16] = "over"
}

-- Returns questStatus
function utils.getQuestStatus()
    local manager = utils.singleton("snow.QuestManager")
    if manager == nil then return end
    return manager:get_field("_QuestStatus")
end

-- Returns name of the questStatus, 0 = "menu/lobby", 1 = "loading", 2 = "quest", 3 = "end", 5 = "abandoned", 7 = "returned",
function utils.getQuestStatusName()
    local status = utils.getQuestStatus()
    if status == nil then return "nil" end
    return questStatusName[utils.getQuestStatus()]
end

function utils.getQuestEndFlow()
    local manager = utils.singleton("snow.QuestManager")
    if manager == nil then return end
    return manager:get_field("_EndFlow")
end

function utils.getQuestEndFlowName()
    local status = utils.getQuestEndFlow()
    if status == nil then return "nil" end
    return questFlowName[utils.getQuestStatus()]
end

-- Localization

local localization = {
    languages = {},
    indexed = {},
    indexedByValue = {},
    current = nil,
    language = nil,
}

local function getWithDefault(default, newValue, _key)
    if newValue == nil then return default end
    if _key ~= nil then newValue = newValue[_key] end
    if type(default) ~= "table" then
        return newValue ~= default and newValue ~= nil and newValue or default
    end
    local copy = {}
    for k, v in pairs(default) do
        copy[k] = getWithDefault(v, newValue, k)
    end
    return copy
end

local function setCurrentLanguage(key)
    local default = localization.languages[localization.indexed[1]]
    local newLang = localization.languages[key]
    localization.current = key
    if default == newLang then
        localization.language = utils.copy(default)
    else
        localization.language = getWithDefault(default, newLang)
    end
end

-- Adds language, ex: util.addLanguage("en_US", require("ModName.lang.en_US")) in case en_US.lua returns a lang table
function utils.addLanguage(key, langTable)
    localization.indexed[#localization.indexed + 1] = key
    localization.indexedByValue[key] = #localization.indexed
    localization.languages[key] = utils.copy(langTable)
    if localization.current == nil then setCurrentLanguage(key) end
end

-- Returns the name of the language based on the index, ex: utils.getLanguageValue(1) will return "en_US" if that is the first lang added
function utils.getLanguageValue(index)
    return localization.indexed[index]
end

-- Returns the index of the language based on the name, ex: utils.getLanguageIndex("en_US") will return 1 if that is the first lang added
function utils.getLanguageIndex(key)
    return localization.indexedByValue[key]
end

-- Sets current language, can be given an index for ease of use with imgui.combo
function utils.setLanguage(key)
    if type(key) == "number" then key = localization.indexed[key] end
    if not localization.languages[key] or localization.current == key then return end
    setCurrentLanguage(key)
end

-- Gets current language
function utils.getLanguage()
    return localization.language
end

function utils.getLanguageKey()
    return localization.current
end

-- Returns the languageIndexed table ex: { "en_US", "es_MX" } for ease of use with imgui.combo
function utils.getLanguageTable()
    return utils.copy(localization.indexed)
end

-- Custom Functions

-- Returns a table of the given size filled with the given value, _value is nil by default
function utils.filledTable(size, _value)
    local table = {}
    size = size
    for i = 1, size do table[i] = _value end
    return table
end

-- Alias of imgui.button and will call func when true
function utils.imguiButton(label, func, ...)
    if type(func) ~= "function" then
        error("utils.button was called with an invalid function")
    end
    if imgui.button(label) then
        func(...)
    end
end

local toStringFunctions, printedTables
printedTables = {}
toStringFunctions = {
    ["nil"] = function ()
        return "nil"
    end,
    ["number"] = function (variable)
        return variable
    end,
    ["boolean"] = function (variable)
        return variable and "true" or "false"
    end,
    ["string"] = function (variable)
        return "\"" .. variable .. "\""
    end,
    ["function"] = function ()
        return "*function"
    end,
    ["thread"] = function ()
        return "*thread"
    end,
    ["userdata"] = function ()
        return "*userdata"
    end,
    ["table"] = function (variable, indentation)
        local tableStr = tostring(variable)
        if printedTables[tableStr] then
            return tableStr
        end
        printedTables[tableStr] = true
        if indentation == nil then indentation = "" end
        local text = "{"
        local originalIndentation = indentation
        indentation = indentation .. "\t"
        for k, v in pairs(variable) do
            text = text .. "\n" .. indentation .. k .. " = "
                .. toStringFunctions[type(v)](v, indentation) .. ","
        end

        return text .. "\n" .. originalIndentation .. "}"
    end
}

-- Makes a string out of the given value to be printed, functions and things like that will have an * at the start, _name is optional to add as the name of the printed variable
function utils.toString(variable, _name)
    printedTables = {}
    return (_name and _name .. " = " or "") .. toStringFunctions[type(variable)](variable)
end

-- Prints directly an imgui.text using utils.toString
function utils.text(variable, name)
    imgui.text(utils.toString(variable, name))
end

-- Print Debug Info

-- Quick alias for imgui.tree_node using a func
function utils.treeFunc(treeName, func)
    if type(func) ~= "function" then
        error("func is not a function in utils.treeFunc")
    end
    if imgui.tree_node(treeName) then
        func()
        imgui.tree_pop()
    end
end

-- Quick alias for imgui.tree_node to print a variable
function utils.treeText(treeName, variable, label)
    if label == nil then label = treeName end
    if imgui.tree_node(treeName) then
        utils.text(variable, label)
        imgui.tree_pop()
    end
end

function utils.printInfoNodes()
    utils.treeText("Cache", utils.cache.data, "cache.data")
    utils.treeText("Localization", {
        indexedByValue = localization.indexedByValue,
        indexed = localization.indexed,
        current = localization.current,
    }, "localization")
    utils.treeText("Custom references", references.custom, "references.custom")
    utils.treeText("Singletons", references.singletons, "references.singletons")
    utils.treeText("Type definitions", references.definitions, "references.definitions")
end

-- Util Initialization

local initialized

-- Initializes the cache (maybe other modules in the future)
function utils.init(cacheFolder, _cacheFile)
    if initialized then return end
    initialized = true
    -- Init Cache
    local cacheHandler = utils.getSettingsHandler({}, cacheFolder, _cacheFile)

    -- reset cache if on the first 5 mins of the game opening
    if os.clock() <= 300 and next(cacheHandler.data) ~= nil then
        cacheHandler.reset()
    end
    utils.cache = cacheHandler
end

return utils