local module = {
	folder = "Auto Cohoot Nest",
}

local config
local modUtils
local settings

local function autoPickNest(retval)
	if not settings.data.enable then
		return
	end
	if not config.VillageAreaManager then
		return
	end

	local villageNum = config.VillageAreaManager:call("get__CurrentAreaNo")
	local progressOwlNestSaveData = config.ProgressOwlNestManager:call("get_SaveData")

	if not config.ProgressOwlNestManager or not progressOwlNestSaveData then
		return
	end

	local kamuraCount = progressOwlNestSaveData:get_field("_StackCount")
	local elgadoCount = progressOwlNestSaveData:get_field("_StackCount2")

	if kamuraCount >= settings.data.maxStock then
		config.VillageAreaManager:call("set__CurrentAreaNo", 2)
		config.ProgressOwlNestManager:supply()
	end

	if elgadoCount >= settings.data.maxStock then
		config.VillageAreaManager:call("set__CurrentAreaNo", 6)
		config.ProgressOwlNestManager:supply()
	end

	if villageNum ~= config.VillageAreaManager:call("get__CurrentAreaNo") then
		config.VillageAreaManager:call("set__CurrentAreaNo", villageNum)
	end
end

function module.init()
	config = require "RiseEnhanced.utils.config"
	modUtils = require "RiseEnhanced.utils.mod_utils"

	settings = modUtils.getConfigHandler({
		enable = true;
		maxStock = 5;
	}, config.folder .. "/" .. module.folder)

	sdk.hook(sdk.find_type_definition("snow.VillageMapManager"):get_method("getCurrentMapNo"),
	nil,
	autoPickNest)
end

function module.draw()
	if imgui.tree_node(config.lang.cohoot.name) then
		settings.imgui("enable", imgui.checkbox, config.lang.enable)
		settings.imgui("maxStock", imgui.slider_int, config.lang.cohoot.maxStock, 1, 5)

		imgui.tree_pop()
	end
end

return module