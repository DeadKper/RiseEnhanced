local module = {
	name = "Auto Dango",
}

local info
local modUtils
local settings

local allManagersRetrieved
local gm

local DataShortcut
local isOrdering

local function CreateOrder(setID)
    local Kitchen = gm.FacilityDataManager.d:call("get_Kitchen")
    if not Kitchen then return end
    Kitchen = Kitchen:call("get_MealFunc")
    if not Kitchen then return end

    return Kitchen:call("getMySetList"):call("get_Item", setID - 1)
end

local function OrderFood(order)
    local Kitchen = gm.FacilityDataManager.d:call("get_Kitchen")
    if not Kitchen then return end
    Kitchen = Kitchen:call("get_MealFunc")
    if not Kitchen then return end

    Kitchen:call("resetDailyDango")

    if Kitchen:get_field("_AvailableWaitTimer") > 0.0 then return end

    log.debug(order:call("get__DangoId"):call("get_Item", 0))

    if order:call("get__DangoId"):call("get_Item", 0) == 65 then
        gm.ChatManager.d:call("reqAddChatInfomation", "<COL RED>Cannot order from an empty set</COL>", settings.data.sounds and 2412657311 or 0)
        return
    end

    log.debug(order:call("get__DangoId"):call("get_Item", 0))

    if order:call("get__DangoId"):call("get_Item", 0) == 65 then
        gm.ChatManager.d:call("reqAddChatInfomation", "<COL RED>Cannot order from an empty set</COL>", settings.data.sounds and 2412657311 or 0)
        return
    end

    local facilityLevel = Kitchen:call("get_FacilityLv")

    local Vouchers = gm.ContentsIdDataManager.d:call("getItemData", 0x410007c)
    local VoucherCount = Vouchers:call("getCountInBox")

    log.debug(VoucherCount)

    if VoucherCount > 0 then
        Kitchen:set_field("_MealTicketFlag", settings.data.useVoucher)
    else
        Kitchen:set_field("_MealTicketFlag", false)
    end

    order:set_field("IsSpecialSkewer", settings.data.useHoppingSkewers)

    isOrdering = true
    Kitchen:call("order", order, settings.data.points and 1 or 0, facilityLevel)
    isOrdering = false

    local Player = gm.PlayerManager.d:call("findMasterPlayer")
    local PlayerData = Player:get_field("_refPlayerData")
    PlayerData:set_field("_vitalMax", PlayerData:get_field("_vitalMax") + 50)
    PlayerData:set_field("_staminaMax", PlayerData:get_field("_staminaMax") + 1500.0)

    local OrderName = order:call("get_OrderName")

    local Message = "<COL YEL>Automatically ate " .. OrderName .. (settings.data.useVoucher and (VoucherCount > 0 and (" with a voucher (" .. VoucherCount .. " remaining)") or ", but you are out of vouchers") or "") .. ".\nSkills activated:</COL>"
    local PlayerSkillData = Player:get_field("_refPlayerSkillList")
    PlayerSkillData = PlayerSkillData:call("get_KitchenSkillData")
    for i,v in pairs(PlayerSkillData:get_elements()) do
        if v:get_field("_SkillId") ~= 0 then
            Message = Message .. "\n" .. DataShortcut:call("getName(snow.data.DataDef.PlKitchenSkillId)", v:get_field("_SkillId")) .. (settings.data.useHoppingSkewers and (" <COL YEL>(lv " .. v:get_field("_SkillLv") .. ")</COL>") or "")
        end
    end
    Message = Message .. (settings.data.useHoppingSkewers and "\n<COL YEL>(Hopping skewer was used)</COL>" or "")

    if settings.data.notification then
        gm.ChatManager.d:call("reqAddChatInfomation", Message, settings.data.sounds and 2289944406 or 0)
    end

    Kitchen:set_field("_AvailableWaitTimer", Kitchen:call("get_WaitTime"))
end

function module.init()
	info = require "RiseEnhanced.misc.info"
	modUtils = require "RiseEnhanced.utils.mod_utils"

	allManagersRetrieved = false
	gm = {}
	gm.FacilityDataManager = {}
	gm.FacilityDataManager.n = "snow.data.FacilityDataManager"
	gm.ProgressManager = {}
	gm.ProgressManager.n = "snow.progress.ProgressManager"
	gm.PlayerManager = {}
	gm.PlayerManager.n = "snow.player.PlayerManager"
	gm.ChatManager = {}
	gm.ChatManager.n = "snow.gui.ChatManager"
	gm.ContentsIdDataManager = {}
	gm.ContentsIdDataManager.n = "snow.data.ContentsIdDataManager"
	gm.QuestManager = {}
	gm.QuestManager.n = "snow.QuestManager"

	for i,v in pairs(gm) do
		v.d = sdk.get_managed_singleton(v.n)
	end

	DataShortcut = sdk.create_instance("snow.data.DataShortcut", true):add_ref()
	isOrdering = false

	settings = modUtils.getConfigHandler({
		enable = true,
		sounds = true,
        useVoucher = false,
		useHoppingSkewers = false,
		points = false,
		notification = true,
		currentSet = 1,
	}, info.modName .. "/" .. module.name)

	sdk.hook(
		sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
		function(args)
			OrderFood(CreateOrder(settings.data.currentSet))
		end
	)

	sdk.hook(
		sdk.find_type_definition("snow.facility.MealOrderData"):get_method("canOrder"),
		function()end,
		function(ret)
			local bool
			if isOrdering then
				bool = sdk.create_instance("System.Boolean"):add_ref()
				bool:set_field("mValue", true)
				ret = sdk.to_ptr(bool)
			end
			log.debug(sdk.to_int64(ret))
		return ret end
	)

	re.on_frame(function()
		if allManagersRetrieved == false then
			local success = true
			for i,v in pairs(gm) do
				v.d = sdk.get_managed_singleton(v.n)
				if v.d == nil then success = false end
			end
			allManagersRetrieved = success
		end
	end)
end

function module.draw()
	if imgui.tree_node(module.name) then
        if allManagersRetrieved then
            local Kitchen = gm.FacilityDataManager.d:call("get_Kitchen")
            if Kitchen then
                Kitchen = Kitchen:call("get_MealFunc")
                if Kitchen then
                    settings.imgui("enable", imgui.checkbox, "Automatically eat")
                    imgui.new_line()
                    settings.imgui("currentSet", imgui.slider_int, "Current dango set", 1, 32, Kitchen:call("get_MySetDataList"):call("get_Item", settings.data.currentSet - 1):call("get_OrderName"))
                    settings.imgui("useHoppingSkewers", imgui.checkbox, "Use hopping skewers", settings.data.useHoppingSkewers)
                    settings.imgui("points", imgui.checkbox, "Pay with Kamura Points", settings.data.points)
                    settings.imgui("useVoucher", imgui.checkbox, "Use voucher on eating", settings.data.useVoucher)
                    imgui.new_line()
                    settings.imgui("notification", imgui.checkbox, "Enable eating notification", settings.data.notification)
                    settings.imgui("sounds", imgui.checkbox, "Enable notification sounds", settings.data.sounds)
                    imgui.new_line()

                    local manualText = "Manually trigger eating"
                    if Kitchen._AvailableWaitTimer > 0 then
                        manualText = "* Manually trigger eating (you have already eaten)"
                    end

                    if imgui.button(manualText) then
                        Kitchen:set_field("_AvailableWaitTimer", 0)
                        OrderFood(CreateOrder(settings.data.currentSet))
                    end
                else
                    imgui.text("Loading...")
                end
            else
                imgui.text("Loading...")
            end
        else
            imgui.text("Loading...")
        end
        imgui.tree_pop();
    end
end

return module