local module = {
	folder = "Skip Intro Logos & Online Warnings",
	managers = {
		"GuiGameStartFsmManager",
		"FadeManagerInstance",
	},
	default = {
		intro = true,
		online = true,
	},
}

local config
local settings

local FINISHED
local LOADING_STATES

local function isLoading()
	if config.GuiGameStartFsmManager then
		return LOADING_STATES[config.GuiGameStartFsmManager:get_field("<GameStartState>k__BackingField")] 
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
	if not config.FadeManagerInstance then
		return
	end

	config.FadeManagerInstance:set_field("<FadeMode>k__BackingField", FINISHED)
	config.FadeManagerInstance:set_field("fadeOutInFlag",false)
end
local function ClearFade(args)
	if not config.FadeManagerInstance then
		return
	end
	config.FadeManagerInstance:set_field("<FadeMode>k__BackingField", FINISHED)
	config.FadeManagerInstance:set_field("fadeOutInFlag",false)
end

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

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
		imgui.text(config.lang.resetScriptNote)
		imgui.tree_pop()
	end
end

return module