local module = {
	folder = "Auto Cohoot Nest",
	managers = {
        "VillageAreaManager",
        "ProgressOwlNestManager",
    },
	default = {
		enable = true,
		maxStock = 5,
	},
}

local config
local settings

local function autoPickNest()
	if not config.isEnabled(settings.data.enable, module.managers) then return end

	local villageNum = config.VillageAreaManager:call("get__CurrentAreaNo")
	local progressOwlNestSaveData = config.ProgressOwlNestManager:call("get_SaveData")

	if not progressOwlNestSaveData then
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
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

	sdk.hook(sdk.find_type_definition("snow.VillageMapManager"):get_method("getCurrentMapNo"),
	nil,
	autoPickNest)
end

function module.draw()
	if imgui.tree_node(config.lang.cohoot.name) then
		settings.imgui(imgui.checkbox, "enable", config.lang.enable)
		settings.imgui(imgui.slider_int, "maxStock", config.lang.cohoot.maxStock, 1, 5)

		imgui.tree_pop()
	end
end

return module