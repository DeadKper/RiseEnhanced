local module = {
	folder = "Skip Intro Logos & Online Warnings",
}

local config
local modUtils
local settings

local FINISHED
local LOADING_STATES

local function isLoading()
	local GuiGameStartFsmManager = sdk.get_managed_singleton("snow.gui.fsm.title.GuiGameStartFsmManager")
	if GuiGameStartFsmManager then
		return LOADING_STATES[GuiGameStartFsmManager:get_field("<GameStartState>k__BackingField")] 
	end
	return false
end

local function isTitleSkip(retval)
	if isLoading() then
		return sdk.to_ptr(1)
	end
	return retval
end

local function notifyActionEnd(args)
	sdk.to_managed_object(args[3]):call("notifyActionEnd")
end

local function playMovie(args)
	if isLoading() then
		local movie = sdk.to_managed_object(args[2])
		if movie then
			movie:seek(movie:get_DurationTime())
		end
	end
end

local function ClearFadeWithAction(args)
	sdk.to_managed_object(args[3]):call("notifyActionEnd")
	local FadeManager = sdk.get_managed_singleton("snow.SnowSingletonBehaviorRoot`1<snow.FadeManager>")
	if FadeManager then 
		FadeManager = FadeManager:get_field("_Instance") 
		if FadeManager then
			FadeManager:set_field("<FadeMode>k__BackingField", FINISHED)
			FadeManager:set_field("fadeOutInFlag",false)
		end
	end
end
local function ClearFade(args)
	local FadeManager = sdk.get_managed_singleton("snow.SnowSingletonBehaviorRoot`1<snow.FadeManager>")
	if FadeManager then 
		FadeManager = FadeManager:get_field("_Instance") 
		if FadeManager then
			FadeManager:set_field("<FadeMode>k__BackingField", FINISHED)
			FadeManager:set_field("fadeOutInFlag",false)
		end
	end
end

function module.init()
	config = require "RiseEnhanced.utils.config"
	modUtils = require "RiseEnhanced.utils.mod_utils"
	settings = modUtils.getConfigHandler({
		intro = true,
		online = true,
	}, config.folder .. "/" .. module.folder)

	LOADING_STATES = {
		[sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsmManager.GameStartStateType"):get_field("Health_Caution"):get_data()] = true, -- 6
		[sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsmManager.GameStartStateType"):get_field("CAPCOM_Logo"):get_data()] = true, -- 1
		[sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsmManager.GameStartStateType"):get_field("Blank"):get_data()] = true, -- 5
		[sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsmManager.GameStartStateType"):get_field("Re_Logo"):get_data()] = true -- 2
	}

	FINISHED = sdk.find_type_definition("snow.FadeManager.MODE"):get_field("FINISH"):get_data()

	if settings.data.intro then
		-- Fast forward movies to the end to mute audio
		sdk.hook(sdk.find_type_definition("via.movie.Movie"):get_method("play"),
		playMovie, function(ret) return ret end)

		-- clear fadeout
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsm_CautionFadeIn"):get_method("update"),
		ClearFade, function(ret) return ret end)
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsm_CAPCOMLogoFadeIn"):get_method("update"),
		ClearFade, function(ret)return ret end)
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsm_HealthCautionFadeIn"):get_method("update"),
		ClearFade, function(ret)return ret end)

		-- Actual skip actions
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsm_RELogoFadeIn"):get_method("update"),
		ClearFadeWithAction, function(ret)return ret end)
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsm_OtherLogoFadeIn"):get_method("update"),
		ClearFadeWithAction, function(ret)return ret end)
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiGameStartFsm_AutoSaveCaution_Action"):get_method("start"),
		notifyActionEnd, function(ret) return ret end)
		sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiTitleFsm_PressAnyButton_Action"):get_method("start"),
		notifyActionEnd, function(ret) return ret end)

		-- Fake title skip input for HEALTH/Capcom
		sdk.hook(sdk.find_type_definition("snow.gui.StmGuiInput"):get_method("getTitleDispSkipTrg"),
		function(args)end, isTitleSkip)
	end

	if settings.data.online then
		sdk.hook(sdk.find_type_definition("snow.SnowSessionManager"):get_method("reqOnlineWarning()"), function() return sdk.PreHookResult.SKIP_ORIGINAL end, function() end)
	end
end

function module.draw()
	if imgui.tree_node(config.lang.skips.name) then
		settings.imgui("intro", imgui.checkbox, config.lang.skips.intro)
		settings.imgui("online", imgui.checkbox, config.lang.skips.online)
		imgui.text(config.lang.restartNote)
		imgui.tree_pop()
	end
end

return module