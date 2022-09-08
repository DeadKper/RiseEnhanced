log.info("[VIP Dango Ticket] started loading")

local module = {
	name = "VIP Dango Ticket",
}

local info
local modUtils
local settings

local VIPDT_debugLogs

local function VIPDT_logDebug(argStr)
	local debugString = "[VIP Dango Ticket] "..argStr;
	if VIPDT_debugLogs then
		log.info(debugString);
	end
end

local DangoListType
local SavedDangoChance
local SavedDango
local DangoTicketState

function module.init()
	VIPDT_debugLogs = false
	DangoListType = sdk.find_type_definition("System.Collections.Generic.List`1<snow.data.DangoData>")
	SavedDangoChance = 100
	SavedDango = nil
	DangoTicketState = false

	info = require "RiseEnhanced.misc.info"
	modUtils = require "RiseEnhanced.utils.mod_utils"

	local temp = {4, 3, 1}

	settings = modUtils.getConfigHandler({
		enable = true,
		infiniteDangoTickets = false,
		ticketByDefault = true,
		showAllDango = false,
		skewerLevels = {4, 3, 1}
	}, info.modName .. "/" .. module.name)

	sdk.hook(sdk.find_type_definition("snow.data.DangoData"):get_method("get_SkillActiveRate"),
		--force 100% activation
		function(args)
			if not settings.data.enable then
				return
			end
			local FacilityManager = sdk.get_managed_singleton("snow.data.FacilityDataManager");
			local KitchenMealFunc = FacilityManager:get_field("_Kitchen"):get_field("_MealFunc");

			DangoTicketState = KitchenMealFunc:call("getMealTicketFlag");
			if DangoTicketState then
				SavedDango = sdk.to_managed_object(args[2]);
				SavedDangoChance = SavedDango:get_field("_Param"):get_field("_SkillActiveRate")
				SavedDango:get_field("_Param"):set_field("_SkillActiveRate", 100);
			end
		end,
		function(retval)
			if not settings.data.enable then
				return retval
			end
			if DangoTicketState then
				SavedDango:get_field("_Param"):set_field("_SkillActiveRate", SavedDangoChance);
			end
			return retval;
		end
	);

	sdk.hook(sdk.find_type_definition("snow.gui.fsm.kitchen.GuiKitchen"):get_method("setDangoDetailWindow"),
		--inform Gui of Dango Lv changes
		function(args)
			if not settings.data.enable then
				return
			end
			local thisGui = sdk.to_managed_object(args[2])
			local SkewerLvList = thisGui:get_field("SpecialSkewerDangoLv")
			for i=0,2 do
				local newSkewerLv = sdk.create_instance("System.UInt32")
				newSkewerLv:set_field("mValue", settings.data.skewerLevels[i+1])
				SkewerLvList[i] = newSkewerLv
			end
		end,
		function(retval)
			return retval;
		end
	);

	sdk.hook(sdk.find_type_definition("snow.facility.kitchen.MealFunc"):get_method("updateList"),
		--inform Dango order constructor of Dango Lv changes
		function(args)
			if not settings.data.enable then
				return
			end
			local FacilityManager = sdk.get_managed_singleton("snow.data.FacilityDataManager");
			local KitchenMealFunc = FacilityManager:get_field("_Kitchen"):get_field("_MealFunc");
			if settings.data.ticketByDefault then
				KitchenMealFunc:call("setMealTicketFlag", true)
			end
			local SkewerLvList = KitchenMealFunc:get_field("SpecialSkewerDangoLv")
			for i=0,2 do
				local newSkewerLv = sdk.create_instance("System.UInt32")
				newSkewerLv:set_field("mValue", settings.data.skewerLevels[i+1])
				SkewerLvList[i] = newSkewerLv
			end
		end,
		function(retval)
			if not settings.data.enable then
				return retval
			end
			if settings.data.showAllDango then
				local FacilityManager = sdk.get_managed_singleton("snow.data.FacilityDataManager")
				local KitchenMealFunc = FacilityManager:get_field("_Kitchen"):get_field("_MealFunc")
				local DangoData = KitchenMealFunc:get_field("<DangoDataList>k__BackingField"):call("ToArray")
				local FlagManager = sdk.get_managed_singleton("snow.data.FlagDataManager");
				for i, dango in ipairs(DangoData) do
					local isDangoUnlock = FlagManager:call("isUnlocked(snow.data.DataDef.DangoId)", dango:get_field("_Param"):get_field("_Id"))
					if isDangoUnlock then
						dango:get_field("_Param"):set_field("_DailyRate", 0)
					end
				end
			end
			return retval;
		end
	);

	sdk.hook(sdk.find_type_definition("snow.facility.kitchen.MealFunc"):get_method("order"),
		function(args)

		end,
		function(retval)
			if settings.data.infiniteDangoTickets then
				local DataManager = sdk.get_managed_singleton("snow.data.DataManager");
				local ItemBox = DataManager:get_field("_PlItemBox")
				ItemBox:call("tryAddGameItem(snow.data.ContentsIdSystem.ItemId, System.Int32)", 68157564, 1)
			end
			return retval;
		end
	);
end

function module.draw()
	if imgui.tree_node(module.name) then
		settings.imgui("enable", imgui.checkbox, "Enable VIP Ticket (100% chance on dangos with ticket)")
		settings.imgui("infiniteDangoTickets", imgui.checkbox, "Infinite Tickets")
		settings.imgui("ticketByDefault", imgui.checkbox, "Use Dango Ticket by default")
		settings.imgui("showAllDango", imgui.checkbox, "Show all available Dango (including daily)")
		imgui.text("Note: To toggle OFF requires game restart after.")
		imgui.new_line()
		if imgui.tree_node("Configure Hopping Skewer Dango Levels") then
			settings.imguit("skewerLevels", 1, imgui.slider_int, "Top Dango", 1, 4)
			settings.imguit("skewerLevels", 2, imgui.slider_int, "Mid Dango", 1, 4)
			settings.imguit("skewerLevels", 3, imgui.slider_int, "Bot Dango", 1, 4)
			if imgui.button("Reset to Defaults") then
				settings.update({4, 3, 1}, "skewerLevels")
			end
			imgui.tree_pop()
		end
		imgui.tree_pop()
	end
end

log.info("[VIP Dango Ticket] finished loading")

return module