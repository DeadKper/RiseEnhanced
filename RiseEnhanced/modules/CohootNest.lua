local module = {
	name = "Auto Cohoot Nest",
}

local info
local modUtils
local settings

local function autoPickNest(retval)
	if not settings.data.enable then
		return
	end

	local villageAreaManager = sdk.get_managed_singleton("snow.VillageAreaManager")

	if not villageAreaManager then
		return
	end

	local villageNum = villageAreaManager:call("get__CurrentAreaNo")

	local owlNestManagerSingleton = sdk.get_managed_singleton("snow.progress.ProgressOwlNestManager")
	local progressOwlNestSaveData = owlNestManagerSingleton:call("get_SaveData")

	if not owlNestManagerSingleton or not progressOwlNestSaveData then
		return
	end

	local kamuraCount = progressOwlNestSaveData:get_field("_StackCount")
	local elgadoCount = progressOwlNestSaveData:get_field("_StackCount2")

	if kamuraCount >= settings.data.maxStock then
		villageAreaManager:call("set__CurrentAreaNo", 2)
		owlNestManagerSingleton:supply()
	end

	if elgadoCount >= settings.data.maxStock then
		villageAreaManager:call("set__CurrentAreaNo", 6)
		owlNestManagerSingleton:supply()
	end

	if villageNum ~= villageAreaManager:call("get__CurrentAreaNo") then
		villageAreaManager:call("set__CurrentAreaNo", villageNum)
	end
end

function module.init()
	info = require "RiseEnhanced.misc.info"
	modUtils = require "RiseEnhanced.utils.mod_utils"

	settings = modUtils.getConfigHandler({
		enable = true;
		maxStock = 5;
	}, info.modName .. "/" .. module.name)

	sdk.hook(sdk.find_type_definition("snow.VillageMapManager"):get_method("getCurrentMapNo"),
	nil,
	autoPickNest)
end

function module.draw()
	if imgui.tree_node(module.name) then
		settings.imgui("enable", imgui.checkbox, "Enabled")
		settings.imgui("maxStock", imgui.slider_int, "Maximum stock", 1, 5)

		imgui.tree_pop()
	end
end

return module