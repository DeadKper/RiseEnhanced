local module = {
	folder = "Reusable Buddy Recon",
	managers = {
		"OtomoManager",
		"OtomoReconManager",
	},
	default = {
		enable = true,
		cost = 100,
	},
}

local config
local settings

-- infinite_buddy_recon.lua : written by arcwizard1204

local travelCount

local function on_pre_onCompleteReconOtomoAct(args)
	if settings.data.enable then
		return sdk.PreHookResult.SKIP_ORIGINAL
	else
		return sdk.PreHookResult.CALL_ORIGINAL
	end
end

local function on_post_onCompleteReconOtomoAct(retval)
	if settings.data.enable then
		config.OtomoManager._RefOtReconManager:removeReconOtomo()
	end
    return retval
end

local function on_pre_showReconOtomo(args)
	if settings.data.enable then
		travelCount = travelCount + 1
	end
	return sdk.PreHookResult.CALL_ORIGINAL
end

local function on_pre_initRewardList(args)
	if settings.data.enable then
		local usedPoints = settings.data.cost * travelCount
		if travelCount > 0 then
			config.OtomoReconManager:set_field("_IsUseOtomoReconFastTravel", true)
		end
		config.OtomoReconManager:set_field("UseOtomoReconFastTravelVillagePoint", usedPoints)
	end

	return sdk.PreHookResult.CALL_ORIGINAL
end

local function on_pre_initQuestStart(args)
	if settings.data.enable then
		if travelCount > 0 then
			travelCount = 0
			config.OtomoReconManager:set_field("_IsUseOtomoReconFastTravel", false)
		end
		config.OtomoReconManager:set_field("UseOtomoReconFastTravelVillagePoint", settings.data.cost)
	end

	return sdk.PreHookResult.CALL_ORIGINAL
end

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

	travelCount = 0
	config.OtomoReconManager = nil

	sdk.hook(sdk.find_type_definition("snow.otomo.OtomoReconCharaManager"):get_method("onCompleteReconOtomoAct"), on_pre_onCompleteReconOtomoAct, on_post_onCompleteReconOtomoAct)

	sdk.hook(sdk.find_type_definition("snow.otomo.OtomoReconCharaManager"):get_method("showReconOtomo"), on_pre_showReconOtomo)

	sdk.hook(sdk.find_type_definition("snow.gui.GuiQuestResultFsmManager"):get_method("initRewardList"), on_pre_initRewardList)

	sdk.hook(sdk.find_type_definition("snow.SnowSessionManager"):get_method("initQuestStart"),
		on_pre_initQuestStart)
end

function module.draw()
	if imgui.tree_node(config.lang.buddyRecon.name) then
		settings.imgui(imgui.checkbox, "enable", config.lang.enable)
		settings.slider_int("cost", config.lang.buddyRecon.cost, 0, 1000, settings.data.cost, 10)
		if imgui.button(config.lang.reset) then
			settings.reset()
        end
		imgui.tree_pop()
	end
end

return module