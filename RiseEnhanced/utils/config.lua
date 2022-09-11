local modUtils
local PlayerManager
local languageTable
local languageIndex
local questManager

local currentQuestStatus
local currentQuestTime

local languages = {
	["en_US"] = require("RiseEnhanced.languages.en_US"),
}

local config = {
	folder = "Rise Enhanced",
	version = "2.1.0",
}

function config.getWeaponType()
    if PlayerManager == nil then return end
    local MasterPlayer = PlayerManager:call("findMasterPlayer")
    if MasterPlayer == nil then return end

    local weaponType = MasterPlayer:get_field("_playerWeaponType")
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

function config.init()
	modUtils = require("RiseEnhanced.utils.mod_utils")

	languageTable = {}
	local index = 1
	for key, _ in pairs(languages) do
		languageTable[index] = key
		index = index + 1
	end

	config.settings = modUtils.getConfigHandler({
		language = "en_US",
	}, config.folder)

	languageIndex = config.findIndex(languageTable, config.settings.data.language)

	config.lang = languages[config.settings.data.language]
	PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager")
	questManager = sdk.get_managed_singleton("snow.QuestManager")

	re.on_pre_application_entry("UpdateBehavior", function()
		local status = questManager:get_field("_QuestStatus")
		if currentQuestStatus ~= status then
			currentQuestTime = config.time()
			currentQuestStatus = status
		end
    end)
end

function config.draw()
	local change
	if imgui.tree_node(config.lang.config.name) then
		change, languageIndex = imgui.combo(config.lang.language, languageIndex, languageTable)

		if change then
			config.settings.update(languageTable[languageIndex], "language")
			config.lang = languages[config.settings.data.language]
		end

		-- imgui.text(config.time())
		imgui.tree_pop()
	end
end

return config
