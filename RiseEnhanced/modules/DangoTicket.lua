local module = {
	folder = "VIP Dango Ticket",
	managers = {
        "FacilityDataManager",
        "ProgressManager",
        "PlayerManager",
        "ChatManager",
        "ContentsIdDataManager",
        "QuestManager",
    },
	default = {
		enable = true,
		infiniteDangoTickets = false,
		ticketByDefault = true,
		showAllDango = false,
		skewerLevels = {4, 3, 1}
	},
}

local config
local settings

local SavedDangoChance
local SavedDango
local DangoTicketState

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

	VIPDT_debugLogs = false
	SavedDangoChance = 100
	SavedDango = nil
	DangoTicketState = false

	sdk.hook(sdk.find_type_definition("snow.data.DangoData"):get_method("get_SkillActiveRate"),
		--force 100% activation
		function(args)
			if not settings.data.enable then
				return
			end
			local KitchenMealFunc = config.FacilityDataManager:get_field("_Kitchen"):get_field("_MealFunc");

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
			local KitchenMealFunc = config.FacilityDataManager:get_field("_Kitchen"):get_field("_MealFunc");
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
				local KitchenMealFunc = config.FacilityDataManager:get_field("_Kitchen"):get_field("_MealFunc")
				local DangoData = KitchenMealFunc:get_field("<DangoDataList>k__BackingField"):call("ToArray")
				for i, dango in ipairs(DangoData) do
					local isDangoUnlock = config.FlagManager:call("isUnlocked(snow.data.DataDef.DangoId)", dango:get_field("_Param"):get_field("_Id"))
					if isDangoUnlock then
						dango:get_field("_Param"):set_field("_DailyRate", 0)
					end
				end
			end
			return retval;
		end
	);

	sdk.hook(sdk.find_type_definition("snow.facility.kitchen.MealFunc"):get_method("order"),
		function()

		end,
		function(retval)
			if settings.data.infiniteDangoTickets then
				local ItemBox = config.DataManager:get_field("_PlItemBox")
				ItemBox:call("tryAddGameItem(snow.data.ContentsIdSystem.ItemId, System.Int32)", 68157564, 1)
			end
			return retval;
		end
	);
end

function module.draw()
	if imgui.tree_node(config.lang.dangoTicket.name) then
		settings.imgui(imgui.checkbox, "enable", config.lang.dangoTicket.enableVip)
		settings.imgui(imgui.checkbox, "infiniteDangoTickets", config.lang.dangoTicket.infiniteTickets)
		settings.imgui(imgui.checkbox, "ticketByDefault", config.lang.dangoTicket.ticketByDefault)
		settings.imgui(imgui.checkbox, "showAllDango", config.lang.dangoTicket.showAllDango)
		imgui.text(config.lang.restartNote)
		imgui.new_line()
		if imgui.tree_node(config.lang.dangoTicket.hoppingSkewers) then
			settings.imgui(imgui.slider_int, { "skewerLevels", 1 }, config.lang.dangoTicket.top, 1, 4)
			settings.imgui(imgui.slider_int, { "skewerLevels", 2 }, config.lang.dangoTicket.mid, 1, 4)
			settings.imgui(imgui.slider_int, { "skewerLevels", 3 }, config.lang.dangoTicket.bot, 1, 4)
			
			if imgui.button(config.lang.reset) then
				settings.reset("skewerLevels")
			end
			imgui.tree_pop()
		end
		imgui.tree_pop()
	end
end

return module