local module = {
	folder = "Auto Dango",
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
        cartEnable = true,
		sounds = true,
        useVoucher = false,
		useHoppingSkewers = false,
		points = false,
		notification = true,
		currentSet = 1,
        weapons = {},
        hasMaxedStats = false,
	},
}

local config
local settings

local DataShortcut
local isOrdering

local function GetCurrentSet()
    local loadout = settings.data.weapons[config.getWeaponType() + 1]
    if loadout == 0 then
        loadout = settings.data.currentSet
    end
    return loadout
end

local function CreateOrder(setID)
    local Kitchen = config.FacilityDataManager:call("get_Kitchen")
    if not Kitchen then return end
    Kitchen = Kitchen:call("get_MealFunc")
    if not Kitchen then return end

    return Kitchen:call("getMySetList"):call("get_Item", setID - 1)
end

local function OrderFood(order)
    if config.getQuestStatus() ~= 0 and config.getQuestStatus() ~= 2 then
        return true
    end

    local Kitchen = config.FacilityDataManager:call("get_Kitchen")
    if not Kitchen then return false end
    Kitchen = Kitchen:call("get_MealFunc")
    if not Kitchen then return false end

    Kitchen:call("resetDailyDango")

    if Kitchen:get_field("_AvailableWaitTimer") > 0.0 then return true end

    log.debug(order:call("get__DangoId"):call("get_Item", 0))

    if order:call("get__DangoId"):call("get_Item", 0) == 65 then
        config.ChatManager:call("reqAddChatInfomation", config.lang.dango.emptySet, settings.data.sounds and 2412657311 or 0)
        return false
    end

    local facilityLevel = Kitchen:call("get_FacilityLv")

    local Vouchers = config.ContentsIdDataManager:call("getItemData", 0x410007c)
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

    local Player = config.PlayerManager:call("findMasterPlayer")
    local PlayerData = Player:get_field("_refPlayerData")
    if not settings.data.hasMaxedStats then
        PlayerData:set_field("_vitalMax", PlayerData:get_field("_vitalMax") + 50)
        PlayerData:set_field("_staminaMax", PlayerData:get_field("_staminaMax") + 1500.0)
        settings.update("hasMaxedStats", true)
    end

    local OrderName = order:call("get_OrderName")

    local Message = string.format(config.lang.dango.eatMessage, OrderName) .. (settings.data.useVoucher and (VoucherCount > 0 and (string.format(config.lang.dango.voucherRemaining, VoucherCount)) or config.lang.dango.outOufVouchers) or "") .. config.lang.dango.skills

    local PlayerSkillData = Player:get_field("_refPlayerSkillList")
    PlayerSkillData = PlayerSkillData:call("get_KitchenSkillData")
    local SkillsMessage = ""
    for _, v in pairs(PlayerSkillData:get_elements()) do
        if v:get_field("_SkillId") ~= 0 then
            SkillsMessage = SkillsMessage .. "\n" .. DataShortcut:call("getName(snow.data.DataDef.PlKitchenSkillId)", v:get_field("_SkillId")) .. (settings.data.useHoppingSkewers and (" <COL YEL>(lv " .. v:get_field("_SkillLv") .. ")</COL>") or "")
        end
    end
    if SkillsMessage == nil or SkillsMessage == "" or string.len(SkillsMessage) <= 5 then
        return false
    end
    Message = Message .. SkillsMessage .. (settings.data.useHoppingSkewers and config.lang.dango.hoppingSkewers or "")

    if settings.data.notification then
        config.ChatManager:call("reqAddChatInfomation", Message, settings.data.sounds and 2289944406 or 0)
    end

    Kitchen:set_field("_AvailableWaitTimer", Kitchen:call("get_WaitTime"))
    return true
end

local function orderDango()
    if not OrderFood(CreateOrder(GetCurrentSet())) then
        config.ChatManager:call("reqAddChatInfomation", config.lang.dangoTicket.eatingFailed, settings.data.sounds and 2289944406 or 0)
    end
end

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

	DataShortcut = sdk.create_instance("snow.data.DataShortcut", true):add_ref()
	isOrdering = false

    for i = 1, 14, 1 do
		if settings.data.weapons[i] == nil then
			settings.data.weapons[i] = 0
		end
	end

    if config.getQuestStatusName() ~= "quest" then settings.reset("hasMaxedStats") end

	sdk.hook(
		sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
		function(args)
            if config.isEnabled(settings.data.enable, module.managers) then
                orderDango()
            end
		end
	)

    re.on_pre_application_entry("UpdateBehavior", function()
        if not config.isEnabled(settings.data.enable, module.managers) then
            return
        end

        local Kitchen = config.FacilityDataManager:call("get_Kitchen")
        if not Kitchen then return end
        Kitchen = Kitchen:call("get_MealFunc")
        if config.getQuestStatus() ~= 2 and Kitchen:get_field("_AvailableWaitTimer") == 0 and settings.data.hasMaxedStats then
            settings.reset("hasMaxedStats")
        end
    end)

    sdk.hook(sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"), function(args)
        if config.isEnabled(settings.data.enable, module.managers) and settings.data.cartEnable then
            config.addTimer(5, orderDango)
        end
    end)

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
end

local currentSet
function module.draw()
    if imgui.tree_node(config.lang.dango.name) then
        if not config.managersRetrieved(module.managers) then
            imgui.text(config.lang.loading)
            imgui.tree_pop();
            return
        end

        local Kitchen = config.FacilityDataManager:call("get_Kitchen")
        if not Kitchen then
            imgui.text(config.lang.loading)
            imgui.tree_pop();
            return
        end

        Kitchen = Kitchen:call("get_MealFunc")
        if not Kitchen then
            imgui.text(config.lang.loading)
            imgui.tree_pop();
            return
        end

        settings.imgui(imgui.checkbox, "enable", config.lang.enable)
        settings.imgui(imgui.checkbox, "cartEnable", config.lang.dango.eatAfterDying)
        imgui.new_line()

        currentSet = Kitchen:call("get_MySetDataList"):call("get_Item", settings.data.currentSet - 1):call("get_OrderName")
        settings.imgui(imgui.slider_int, "currentSet", config.lang.dango.currentSet, 1, 32, currentSet)
        if imgui.tree_node(config.lang.weaponType) then
            for i = 1, 14, 1 do
                settings.slider_int(
                    { "weapons", i },
                    config.getWeaponName(i - 1),
                    1,
                    32,
                    settings.data.weapons[i] >= 1 and Kitchen:call("get_MySetDataList"):call("get_Item", settings.data.weapons[i] - 1):call("get_OrderName") or nil,
                    string.format(config.lang.useDefault, currentSet)
                )
            end
            imgui.tree_pop();
        end

        imgui.new_line()
        settings.imgui(imgui.checkbox, "points", config.lang.dango.points, settings.data.points)
        settings.imgui(imgui.checkbox, "useHoppingSkewers", config.lang.dango.useHoppingSkewers, settings.data.useHoppingSkewers)
        settings.imgui(imgui.checkbox, "useVoucher", config.lang.dango.useVoucher, settings.data.useVoucher)
        imgui.new_line()
        settings.imgui(imgui.checkbox, "notification", config.lang.notification, settings.data.notification)
        settings.imgui(imgui.checkbox, "sounds", config.lang.sounds, settings.data.sounds)
        imgui.new_line()

        local manualText = config.lang.dango.manualEat
        if Kitchen._AvailableWaitTimer > 0 then
            manualText = config.lang.dango.manualEatAgain
        end

        if imgui.button(manualText) then
            if Kitchen:get_field("_AvailableWaitTimer") > 0 then
                settings.update("hasMaxedStats", true)
                Kitchen:set_field("_AvailableWaitTimer", 0)
            end
            orderDango()
        end
        imgui.tree_pop();
    end
end

return module