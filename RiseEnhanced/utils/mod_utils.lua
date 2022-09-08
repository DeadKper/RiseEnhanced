local jsonUtils = json

-- Aliases
local function getType(name) return sdk.find_type_definition(name) end

local function getSingletonData(name)
    return {sdk.get_managed_singleton(name), getType(name)}
end

local function getSingletonField(singleton, name)
    local singletonRef, typedef = table.unpack(singleton)
    return singletonRef:get_field(name)
end

local function callSingletonFunc(singleton, name, ...)
    local args = {...}
    local singletonRef, typedef = table.unpack(singleton)
    return singletonRef:call(name, table.unpack(args))
end

-- Returns a table with enum names by value, so you can do:
-- imgui.text("Current quest type: " .. questTypeEnumMap[currentQuestType] .. " (" .. currentQuestType .. ")")
-- Which shows "Current quest type: INVALID (0)"
local function getEnumMap(enumTypeName)
    local typeDef = getType(enumTypeName)
    if not typeDef then return {} end

    local fields = typeDef:get_fields()
    local map = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local key = field:get_data(nil)
            map[key] = name
        end
    end

    return map
end

local function info(text) log.info("[MODUTILS] " .. text) end

local function getQuestStatus(questManager)
    if not questManager then
        questManager = getSingletonData("snow.QuestManager")
    end
    return getSingletonField(questManager, "_QuestStatus")
end

-- Very useful if you don't want your mod to interfere in fights
local function checkIfInBattle()
    local musicManager = getSingletonData("snow.wwise.WwiseMusicManager")

    local currentMusicType = getSingletonField(musicManager, "_FightBGMType")
    local currentBattleState = getSingletonField(musicManager,
                                                 "_CurrentEnemyAction")

    local musicMixManager = getSingletonData("snow.wwise.WwiseMixManager")
    local currentMixUsed = getSingletonField(musicMixManager, "_Current")

    local questManager = getSingletonData("snow.QuestManager")

    local currentQuestType = getSingletonField(questManager, "_QuestType")
    local currentQuestStatus = getSingletonField(questManager, "_QuestStatus")

    local inBattle = currentBattleState == 3 -- Fighting a monster
    or currentMixUsed == 37 -- Fighting a wave of monsters
    or currentMixUsed == 10 -- Stronger battle music mix is being used
    or currentMixUsed == 31 -- Used in some arena battles
    or currentQuestType == 64 -- Fighting in the arena (Utsushi)

    local isQuestComplete = currentQuestStatus == 3 -- Completed the quest
    or currentQuestStatus == 0 -- Not in a quest

    return inBattle and not isQuestComplete
end

-- Doesn't show how many players are on your lobby, only in quests
local function getPlayerCount()
    local questManager = getSingletonData("snow.QuestManager")
    local numberOfPlayers = getSingletonField(questManager, "_TotalJoinNum")

    return numberOfPlayers
end

-- Only works in quests
local function checkIfInMultiplayer() return getPlayerCount() > 1 end

-- Enum maps should be obtained at the top level because they won't ever change while the game runs
local mixEnumMap = getEnumMap("snow.wwise.WwiseMixManager.Mix")
local fightBgmEnumMap = getEnumMap(
                            "snow.wwise.WwiseEnemyMonitoredParameters.FightBGMType")
local enemyActionEnumMap =
    getEnumMap("snow.wwise.WwiseMusicManager.EnemyAction")
local questTypeEnumMap = getEnumMap("snow.quest.QuestType")
local questStatusEnumMap = getEnumMap("snow.QuestManager.Status")

-- Only works when called inside on_draw_ui
local function printDebugInfo()
    local questTypeEnumMap = getEnumMap("snow.quest.QuestType")
    local a, b = pcall(function()
        local musicManager = getSingletonData("snow.wwise.WwiseMusicManager")
        local questManager = getSingletonData("snow.QuestManager")
        local musicMixManager = getSingletonData("snow.wwise.WwiseMixManager")

        local currentMusicType =
            getSingletonField(musicManager, "_FightBGMType")
        local currentBattleState = getSingletonField(musicManager,
                                                     "_CurrentEnemyAction")

        local currentMixUsed = getSingletonField(musicMixManager, "_Current")
        local currentQuestType = getSingletonField(questManager, "_QuestType")
        local currentQuestStatus = getSingletonField(questManager,
                                                     "_QuestStatus")
        local numberOfPlayers = getSingletonField(questManager, "_TotalJoinNum")
        local playersSuffix = "players"
        if numberOfPlayers == 1 then playersSuffix = "player" end

        imgui.text("Detected as \"in battle\"? " ..
                       (checkIfInBattle() and "Yes" or "No"))
        imgui.text("Detected as \"in multiplayer\"? " ..
                       (checkIfInMultiplayer() and "Yes" or "No") .. " (" ..
                       numberOfPlayers .. " " .. playersSuffix .. " in quest)")
        imgui.text("");
        imgui.text(
            "Current quest type: " .. questTypeEnumMap[currentQuestType] .. " (" ..
                currentQuestType .. ")")
        imgui.text("Current quest status: " ..
                       questStatusEnumMap[currentQuestStatus] .. " (" ..
                       currentQuestStatus .. ")")
        imgui.text("Current fight music type: " ..
                       fightBgmEnumMap[currentMusicType] .. " (" ..
                       currentMusicType .. ")")
        imgui.text(
            "Current music mix: " .. mixEnumMap[currentMixUsed] .. " (" ..
                currentMixUsed .. ")")
        imgui.text("Current battle state: " ..
                       enemyActionEnumMap[currentBattleState] .. " (" ..
                       currentBattleState .. ")")
    end)
    log.info(b)
end

-- Saves you quite a bit of code to get the current player.
-- Note that the player's type depends on what they're doing
-- In quest? The player's type will be their weapon
-- Example for SnS: "snow.player.ShortSword" -> "snow.player.PlayerQuestBase" -> "snow.player.PlayerBase"
-- Example while in the Lobby(outside of the training area), regardless of weapon: "snow.player.PlayerLobbyBase" -> "snow.player.PlayerBase"
-- Needs to be obtained exactly when you're using it (like on a pre/post hook) since it changes frequently
local function getCurrentPlayer()
    return sdk.get_managed_singleton("snow.player.PlayerManager"):call(
               "findMasterPlayer")
end

-- You'll probably not need this, as getConfigHandler already handles everything
local function loadConfig(defaultConfig, configFile)
    local currentConfig = {}

    if jsonUtils ~= nil then
        local savedConfig = jsonUtils.load_file(configFile)

        if savedConfig ~= nil then currentConfig = savedConfig end

        for k, v in pairs(currentConfig) do defaultConfig[k] = v end
    end

    return defaultConfig
end

-- You can use this, but it's easier to use settings.saveConfig instead
-- "settings" is a table returned by calling getConfigHandler.
local function saveConfig(currentConfig, newConfig, configFile)
    for k, v in pairs(newConfig) do currentConfig[k] = v end

    if jsonUtils ~= nil then
        jsonUtils.dump_file(configFile, currentConfig)
    end
end

-- Handles and persists your mod configuration for you, so users don't have to toggle stuff every restart.
local function getConfigHandler(defaultSettings, modName, fileName)
    local settings = {}

    if fileName == nil or fileName == "" then
        fileName = "config.json"
    elseif not fileName:match(".json$") then
        fileName = fileName .. ".json"
    end

    local configFile = modName .. "/" .. fileName

    settings.data = loadConfig(defaultSettings, configFile)

    settings.isSavingAvailable = jsonUtils ~= nil

    function settings.saveConfig(newConfig)
        saveConfig(settings.data, newConfig, configFile)
    end

    function settings.update(value, property, index)
        settings.handleChange(true, value, property, index)
    end

    function settings.handleChange(changed, value, property, index)
        if changed then
            local newSetting = {};
            if index ~= nil then
                newSetting[property][index] = value;
            else
                newSetting[property] = value;
            end
            settings.saveConfig(newSetting)
        end
    end

    function settings.imguit(property, index, imguiFunc, ...)
        local args = {...}
        local changed, newValue = imguiFunc(args[1], settings.data[property][index], table.unpack(args, 2))
        if changed == nil or newValue == nil then
            error("settings.imgui was called with an invalid imgui func")
        end
        if changed then
            local newSetting = {};
            settings.data[property][index] = newValue;
            settings.saveConfig(newSetting)
        end

        return {changed, newValue}
    end

    function settings.imgui(property, imguiFunc, ...)
        local args = {...}
        local changed, newValue = imguiFunc(args[1], settings.data[property], table.unpack(args, 2))
        if changed == nil or newValue == nil then
            error("settings.imgui was called with an invalid imgui func")
        end
        if changed then
            local newSetting = {};
            newSetting[property] = newValue;
            settings.saveConfig(newSetting)
        end

        return {changed, newValue}
    end

    return settings
end

local modUtils = {}

modUtils.getType = getType;
modUtils.getSingletonData = getSingletonData;
modUtils.getSingletonField = getSingletonField;
modUtils.getEnumMap = getEnumMap;
modUtils.checkIfInBattle = checkIfInBattle;
modUtils.getCurrentPlayer = getCurrentPlayer;
modUtils.getPlayerCount = getPlayerCount;
modUtils.checkIfInMultiplayer = checkIfInMultiplayer;
modUtils.getConfigHandler = getConfigHandler;
modUtils.callSingletonFunc = callSingletonFunc;
modUtils.printDebugInfo = printDebugInfo;
modUtils.info = info;
modUtils.getQuestStatus = getQuestStatus;

return modUtils
