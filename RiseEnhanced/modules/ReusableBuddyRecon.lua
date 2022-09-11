local module = {
	folder = "Reusable Buddy Recon",
}

local config
local modUtils
local settings

-- infinite_buddy_recon.lua : written by arcwizard1204

local travelCount
local multiplier

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
		local usedPoints = settings.data.cost * multiplier * travelCount
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
		config.OtomoReconManager:set_field("UseOtomoReconFastTravelVillagePoint", settings.data.cost * multiplier)
	end

	return sdk.PreHookResult.CALL_ORIGINAL
end

function module.init()
	config = require("RiseEnhanced.utils.config")
	modUtils = require("RiseEnhanced.utils.mod_utils")
	multiplier = 10
	settings = modUtils.getConfigHandler({
		enable = true,
		cost = 100 / multiplier,
	}, config.folder .. "/" .. module.folder)

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
		settings.imgui("enable", imgui.checkbox, config.lang.enable)
		settings.imgui("cost", imgui.slider_int, config.lang.buddyRecon.cost, 0, 1000 / multiplier, settings.data.cost * multiplier)
		if imgui.button(config.lang.reset) then
            settings.update(true, "enable")
			settings.update(math.floor(100 / multiplier), "cost")
        end
		imgui.tree_pop()
	end
end

return module