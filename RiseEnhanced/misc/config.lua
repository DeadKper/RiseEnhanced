local modUtils
local PlayerManager
local languageTable
local languages = {
	["en_US"] = require("RiseEnhanced.languages.en_US"),
}

local config = {
	folder = "Rise Enhanced",
	version = "2.0.0",
	time = 0,
}

function config.getWeaponType()
    if PlayerManager == nil then PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager") end
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

local function findIndex(table, value)
    for i = 1, #table do
        if table[i] == value then
            return i;
        end
    end

    return nil;
end

function config.init()
	modUtils = require("RiseEnhanced.utils.mod_utils")

	languageTable = {}
	local index = 1
	for key,_ in pairs(languages) do
		languageTable[index] = key
		index = index + 1
	end

	config.settings = modUtils.getConfigHandler({
		language = "en_US",
	}, config.folder)

	config.lang = languages[config.settings.data.language]
	PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager")
end

function config.draw()
	local change, index
	if imgui.tree_node(config.lang.config.name) then

		index = findIndex(languageTable, config.settings.data.language)
		change, index = imgui.combo(config.lang.language, index, languageTable)

		if change then
			config.settings.update(languageTable[index], "language")
			config.lang = languages[config.settings.data.language]
		end
		imgui.tree_pop()
	end
end

return config
