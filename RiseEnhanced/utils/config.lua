local modUtils
local languageTable
local languageIndex

local currentQuestStatus
local currentQuestTime

local cache
-- get_managed_singleton
local singletonManagersNames = {
	ChatManager = "snow.gui.ChatManager",
	ContentsIdDataManager = "snow.data.ContentsIdDataManager",
	ShortcutManager = "snow.data.CustomShortcutSystem",
	DataManager = "snow.data.DataManager",
	EquipDataManager = "snow.data.EquipDataManager",
	FacilityDataManager = "snow.data.FacilityDataManager",
	FadeManager = "snow.SnowSingletonBehaviorRoot`1<snow.FadeManager>",
	-- FadeManagerInstance
	FlagDataManager = "snow.data.FlagDataManager",
	GuiGameStartFsmManager = "snow.gui.fsm.title.GuiGameStartFsmManager",
	OtomoManager = "snow.otomo.OtomoManager",
	OtomoReconManager = "snow.data.OtomoReconManager",
	PlayerManager = "snow.player.PlayerManager",
	ProgressManager = "snow.progress.ProgressManager",
	ProgressOwlNestManager = "snow.progress.ProgressOwlNestManager",
	QuestManager = "snow.QuestManager",
	QuestMapManager = "snow.QuestMapManager",
	StageManager = "snow.stage.StageManager",
	StagePointManager = "snow.stage.StagePointManager",
	SystemDataManager = "snow.data.SystemDataManager",
	VillageAreaManager = "snow.VillageAreaManager",
}

local languages = {
	["en_US"] = require("RiseEnhanced.languages.en_US"),
}

local config = {
	folder = "Rise Enhanced",
	cacheFile = "cache",
	version = "3.0.0-Beta",
	initiated = false,
}

local timers

function config.getWeaponType()
    if config.PlayerManager == nil then return cache.data.weaponType end
    local MasterPlayer = config.PlayerManager:call("findMasterPlayer")
    if MasterPlayer == nil then return cache.data.weaponType end

    local weaponType = MasterPlayer:get_field("_playerWeaponType")
	if cache.data.weaponType ~= weaponType then
		cache.update(weaponType, "weaponType")
	end
    return weaponType
end

function config.getWeaponName(typeNumber)
	if typeNumber == nil then
		typeNumber = config.getWeaponType()
	end
	return config.lang.weaponNames[typeNumber]
end

function config.findIndex(table, value)
    for i = 1, #table do
        if table[i] == value then
            return i;
        end
    end

    return nil;
end

function config.time()
	return os.clock()
end

local questStatusName = {
	[0] = "lobby",
	[1] = "loading",
	[2] = "quest",
	[3] = "end",
	[5] = "abandoned",
	[7] = "returned",
}

function config.getQuestStatus()
    return currentQuestStatus
end

function config.getQuestStatusName()
    return questStatusName[currentQuestStatus]
end

function config.getQuestTime()
	return config.time() - currentQuestTime
end

function config.getQuestInitialTime()
	return currentQuestTime
end

function config.managersRetrieved(managers)
	if managers == nil then return true end
	for _, key in pairs(managers) do
		if config[key] == nil then return false end
	end
	return true
end

function config.isEnabled(enabled, managers)
	return enabled and config.managersRetrieved(managers)
end

local function retrieveManagers()
	for key, value in pairs(singletonManagersNames) do
		if config[key] == nil then
			config[key] = sdk.get_managed_singleton(value)
		end
	end

	if config.ShortcutManager == nil and config.SystemDataManager ~= nil then
		config.ShortcutManager = config.SystemDataManager:call("getCustomShortcutSystem")
	end

	if config.FadeManagerInstance == nil and config.FadeManager ~= nil then
		config.FadeManagerInstance = config.FadeManager:get_field("_Instance")
	end
end


local function updateQuestStatus()
	local status = config.QuestManager:get_field("_QuestStatus")
	if currentQuestStatus ~= status then
		currentQuestTime = config.time()
		currentQuestStatus = status
		config.getWeaponType()
	end
end

function config.addTimer(delay, func, ...)
	timers[timers.count] = {
		delay = config.time() + delay,
		action = func,
		args = {...}
	}
	timers.count = timers.count + 1
end

local function checkTimers()
	if timers.count == 0 then
		return
	end

	local newTimers = {}
	local count = 0
	for i = 0, timers.count - 1 do
		if timers[i].delay < config.time() then
			timers[i].action(table.unpack(timers[i].args))
		else
			newTimers[count] = timers[i]
			count = count + 1
		end
	end
	timers = newTimers
	timers.count = count
end

local function onFrame()
	retrieveManagers()
	checkTimers()
end

local function updateCache(args)
	local index = sdk.to_int64(args[3])
	config.getWeaponType()
	if index ~= cache.data.loadoutIndex then
		local loadout = config.EquipDataManager:call("get_PlEquipMySetList"):call("get_Item", index)
		cache.update(index, "loadoutIndex")
		cache.update(loadout:call("get_Name"), "loadoutName")
		cache.update(loadout:call("getWeaponData"):call("get_PlWeaponType"), "loadoutWeaponType")
	end
end

function config.fullInit()
	if config.initiated then return end

	config.initiated = true
	retrieveManagers()
	re.on_frame(onFrame);
	re.on_pre_application_entry("UpdateBehavior", updateQuestStatus)
	sdk.hook(
		sdk.find_type_definition("snow.data.EquipDataManager"):get_method("applyEquipMySet(System.Int32)"), updateCache)
end

function config.cache(index1, index2)
	return index2 ~= nil and cache.data[index1][index2] or cache.data[index1]
end

function config.init()
	modUtils = require("RiseEnhanced.utils.mod_utils")

	languageTable = {}
	local index = 1
	for key, _ in pairs(languages) do
		languageTable[index] = key
		index = index + 1
	end

	config.settings = modUtils.getConfigHandler({
		enable = true,
		language = "en_US",
	}, config.folder)

	cache = modUtils.getConfigHandler({
		weaponType = nil,
		loadoutIndex = nil,
		loadoutName = nil,
		loadoutWeaponType = nil,
	}, config.folder, config.cacheFile)

	languageIndex = config.findIndex(languageTable, config.settings.data.language)

	config.lang = languages[config.settings.data.language]

	timers = {
		count = 0
	}

	if config.settings.data.enable then
		config.fullInit()
	end
end

local function drawInner()
	local change
	config.settings.imgui("enable", imgui.checkbox, config.lang.enable)
	imgui.text(config.lang.resetScriptNote)
	change, languageIndex = imgui.combo(config.lang.language, languageIndex, languageTable)

	if change then
		config.settings.update(languageTable[languageIndex], "language")
		config.lang = languages[config.settings.data.language]
	end
	imgui.text(config.getWeaponType())
	if cache.data.loadoutIndex ~= nil then
		imgui.text(cache.data.loadoutIndex)
		imgui.text(cache.data.loadoutName)
		imgui.text(cache.data.loadoutWeaponType)
	end
end

function config.draw()
	if not config.initiated then
		drawInner()
		return
	end
	if imgui.tree_node(config.lang.config.name) then
		drawInner()
		imgui.tree_pop()
	end
end

return config
