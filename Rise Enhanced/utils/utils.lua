local utils = {}

-- Singleton manager

-- Returns a manager from sdk.get_managed_singleton
-- function utils.manager(name)
--     return sdk.get_managed_singleton(name)
-- end

-- Returns a definition from sdk.find_type_definition
-- function utils.definition(name)
--     return sdk.find_type_definition(name)
-- end

-- Does a call from a manager, singleton can be either the managed singleton or a string of
-- said manager, in which case it will first do:
-- singleton = utils.manager(singleton)
-- nameOrTable can be either the name of the function to call, in which case args can be passed
-- normally, or can be a table like {{name = "reqAddChatInfomation", args = {2289944406}}},
-- it will loop through the table doing subsequent :call on each result
-- function utils.managerCall(singleton, nameOrTable, ...)
--     if type(singleton) == "string" then
--         singleton = utils.manager(singleton)
--     end
--     if type(nameOrTable) == "table" then
--         local current = singleton
--         for i = 1, #nameOrTable do
--             current = current:call(nameOrTable[i].name, table.unpack(nameOrTable[i].args))
--         end
--         return current
--     end
--     return singleton:call(nameOrTable, ...)
-- end

-- Does a get_field from a manager, singleton can be either the managed singleton or a string of
-- said manager, in which case it will first do:
-- singleton = utils.manager(singleton)
-- nameOrTable can be either the name of the field to get or a table of all fields to get in order
-- ex: { "_Kitchen", "_MealFunc" } or simply "_Kitchen"
-- function utils.managerField(singleton, nameOrTable)
--     if type(singleton) == "string" then
--         singleton = utils.manager(singleton)
--     end
--     if type(nameOrTable) == "table" then
--         local current = singleton
--         for i = 1, #nameOrTable do
--             current = current:get_field(nameOrTable[i])
--         end
--         return current
--     end
--     return singleton:get_field(nameOrTable)
-- end

-- Cache manager

local cache
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

-- Only for code completion, will not be usable until utils.init()
cache = utils.getCacheHandler("utils")

-- Returns settingsHandler, cacheHandler. settingsHandler handles and persists configuration, cacheHandler will only persist data on script resets
function utils.getHandlers(settingsDefaults,
        settingsFolder, settingsFilename, cacheModuleName)
    local settings = utils.getSettingsHandler(settingsDefaults,
        settingsFolder, settingsFilename)
    local cacheHandler = utils.getCacheHandler(cacheModuleName)
    return settings, cacheHandler
end

-- Useful functions

local function inBattleCheck()
    local currentBattleState =
        sdk.get_managed_singleton("snow.wwise.WwiseMusicManager"):get_field("_CurrentEnemyAction")
    local currentMixUsed =
        sdk.get_managed_singleton("snow.wwise.WwiseMixManager"):get_field("_Current")

    local questManager = sdk.get_managed_singleton("snow.QuestManager")
    local currentQuestType = questManager.get_field("_QuestType")
    local currentQuestStatus = questManager.get_field("_QuestStatus")

    local inBattle = currentBattleState == 3 -- Fighting a monster
    or currentMixUsed == 37 -- Fighting a wave of monsters
    or currentMixUsed == 10 -- Stronger battle music mix is being used
    or currentMixUsed == 31 -- Used in some arena battles
    or currentQuestType == 64 -- Fighting in the arena (Utsushi)

    return inBattle and currentQuestStatus == 2
end

-- Return whether or not the player is in battle
function utils.inBattle()
    local success, result = pcall(inBattleCheck)
    if not success then return end
    return result
end

-- Returns whether the quest es online or not, only works properly inside of mission
function utils.isQuestOnline()
    local manager = sdk.get_managed_singleton("snow.stage.StageManager")
    if not manager then return nil end
    return manager:get_IsQuestOnline()
end

-- Returns the player count inside of a quest, will return 1 in lobby
function utils.getPlayerCount()
    if not utils.isQuestOnline() then return 1 end
    return sdk.get_managed_singleton("snow.QuestManager"):get_field("_TotalJoinNum")
end

-- Returns true if there are 2 or more players inside the quest, will return true on lobby
function utils.isMultiplayerQuest()
    return utils.getPlayerCount() > 1
end

-- Returns the player
function utils.getPlayer()
    local manager = sdk.get_managed_singleton("snow.player.PlayerManager")
    if manager == nil then return nil end
    return manager:call("findMasterPlayer")
end

-- Returns the ingame player object
function utils.getPlayerObject()
    local player = utils.getPlayer()
    if player == nil then return nil end
    return player:call("get_GameObject")
end

-- Returns the current weapon
function utils.getPlayerWeapon()
    local player = utils.getPlayer()
    if player == nil then return nil end
    return player:get_field("_playerWeaponType")
end

-- Can be used to know wheter the mod is enabled or not by also checking for loaded _managers (optional) or wheter if _combatPause (optional) is true and the player is not in combat
function utils.isEnabled(enabled, _managers, _combatPause)
    if not enabled then return false end
    if _combatPause and utils.inBattle() then return false end
    if _managers == nil then return true end
    for _, manager in pairs(_managers) do
        if not sdk.get_managed_singleton(manager) then return false end
    end
    return true
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

local timeTimer
local function tickTimers()
    timeTimer = os.clock()
    for i, timer in pairs(timers) do
        if timer.delay - timeTimer <= 0 then
            timer.action()
            timers[i] = nil
        end
    end
end

re.on_frame(tickTimers)

-- Loop handler

local loops = {}

-- Allows a function to loop until the given condition function returns false
-- when the condition returns false the loop entry will be deleted automatically
function utils.addLoop(sleep, conditionFunc, func)
    table.insert(loops, {
        lastExecution = os.clock() - sleep,
        sleep = sleep,
        condition = conditionFunc,
        func = func
    })
end

local timeLoop
local function tickLoops()
    timeLoop = os.clock()
    for i, loop in pairs(loops) do
        if loop.condition() then
            if timeLoop - loop.lastExecution > loop.sleep then
                loop.lastExecution = timeLoop
                loop.func()
            end
        else
            loops[i] = nil
        end
    end
end

re.on_frame(tickLoops)

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

-- Return copy of a table
function utils.copy(original)
    if type(original) ~= "table" then return original end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = utils.copy(v)
    end
    return copy
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
        local currentSettings = json.load_file(_file)
        if currentSettings == nil then currentSettings = utils.copy(settings.default) end
        settings.data = currentSettings
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

    --- Allows slider_int to have a default return (will be min - 1) or have steps in the slider
    -- if _arg is a string or function that returns a string it will be used as the default display text on the slider for min - 1
    -- if _arg is a number ex: settings.slider_int("cost", "Cost", 0, 100, settings.data.cost * 10, 10) will make the slider display and return numbers from 0 to 100 times 10, effectively 0 - 1000 in steps of 10
    -- _func is optional and imgui.slider_int by default
    function settings.sliderInt(propertyTable, label, min, max, text, _arg, _func)
        if _func == nil then _func = imgui.slider_int end
        if type(_func) ~= "function" then
            error("settings.sliderInt was called with an invalid func")
        end
        local property, key = decodeProperty(propertyTable)
        local value = property[key]
        local multiplier = false
        local arguments
        if _arg == nil then
            arguments = {
                label,
                value,
                min,
                max,
            }
            if text ~= nil then arguments[#arguments+1] = text end
        elseif type(_arg) == "string" then
            arguments = {
                label,
                value,
                _arg ~= nil and min - 1 or min,
                max,
                (text == nil or value < min) and _arg or text
            }
        elseif type(_arg) == "number" then
            multiplier = true
            arguments = {
                label,
                math.floor(value / _arg),
                math.floor(min / _arg),
                math.floor(max / _arg),
                value
            }
        else
            error("settings.sliderInt was called with an invalid arg (nil, string, number)")
        end
        local changed, newValue = _func(table.unpack(arguments))
        if multiplier then newValue = newValue * _arg end
        if changed then
            property[key] = newValue
            save()
        end

        return changed, newValue
    end

    return settings
end

-- Custom Hooks

-- local hooksAlias = {}

-- Hooks a previous aliased function to a pre and/or post func, not that useful if you only use that hook 1 time, useful when the hook needs to be used more than once
-- Default Hooks: "onCart", "onQuestActivate", "onQuestUpdate", "onReturn", "onQuestKill", "onEquipEquipmentLoadout"
-- function utils.hook(hook, preFunc, postFunc)
--     if type(hook) ~= "string" then error("utils.hook was called without an alias") end
--     hook = hooksAlias[hook]
--     hook.func(hook.hook, preFunc, postFunc)
-- end

-- Adds an alias to a hook, uses sdk.hook as _registerFunc by default, ex:
-- utils.hookAlias("onCart", sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic")) for an "onCart" hook
-- utils.hookAlias("onQuestUpdate", "UpdateBehavior", re.on_pre_application_entry) for an "onQuestUpdate" hook
-- function utils.hookAlias(alias, hook, _registerFunc)
--     if _registerFunc == nil then _registerFunc = sdk.hook end
--     hooksAlias[alias] = {
--         hook = hook,
--         func = _registerFunc,
--     }
-- end

-- local function defaultHooks()
--     utils.hookAlias("onCart", sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"))
--     utils.hookAlias("onQuestActivate", sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"))
--     utils.hookAlias("onQuestUpdate", "UpdateBehavior", re.on_pre_application_entry)
--     utils.hookAlias("onReturn", sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"))
--     utils.hookAlias("onQuestKill", sdk.find_type_definition("snow.enemy.EnemyCharacterBase"):get_method("questEnemyDie"))
--     utils.hookAlias("onEquipEquipmentLoadout", sdk.find_type_definition("snow.data.EquipDataManager"):get_method("applyEquipMySet(System.Int32)"))
-- end

-- defaultHooks()

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
    local manager = sdk.get_managed_singleton("snow.QuestManager")
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
    local manager = sdk.get_managed_singleton("snow.QuestManager")
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
    size = size + 1
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

local toStringFunctions
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
    cache = utils.getCacheHandler("utils")
end

return utils