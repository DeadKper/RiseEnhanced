local module = {
	folder = "Auto Dango",
}

local config
local modUtils
local settings

local allManagersRetrieved
local gm

local DataShortcut
local isOrdering

local function GetCurrentSet()
    local loadout = settings.data.weapons[config.getWeaponType() + 1]
    if not settings.data.dangoPerWeapon or loadout == 0 then
        loadout = settings.data.currentSet
    end
    return loadout
end

local function getSetName(Kitchen, i)
    if settings.data.weapons[i] == 0 then
        return config.lang.useDefault
    end
    return Kitchen:call("get_MySetDataList"):call("get_Item", settings.data.weapons[i] - 1):call("get_OrderName")
end

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
        gm.ChatManager.d:call("reqAddChatInfomation", config.lang.dango.emptySet, settings.data.sounds and 2412657311 or 0)
        return
    end

    log.debug(order:call("get__DangoId"):call("get_Item", 0))

    if order:call("get__DangoId"):call("get_Item", 0) == 65 then
        gm.ChatManager.d:call("reqAddChatInfomation", config.lang.dango.emptySet, settings.data.sounds and 2412657311 or 0)
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

    local Message = string.format(config.lang.dango.eatMessage, OrderName) .. (settings.data.useVoucher and (VoucherCount > 0 and (string.format(config.lang.dango.voucherRemaining, VoucherCount)) or config.lang.dango.outOufVouchers) or "") .. config.lang.dango.skills

    local PlayerSkillData = Player:get_field("_refPlayerSkillList")
    PlayerSkillData = PlayerSkillData:call("get_KitchenSkillData")
    for i,v in pairs(PlayerSkillData:get_elements()) do
        if v:get_field("_SkillId") ~= 0 then
            Message = Message .. "\n" .. DataShortcut:call("getName(snow.data.DataDef.PlKitchenSkillId)", v:get_field("_SkillId")) .. (settings.data.useHoppingSkewers and (" <COL YEL>(lv " .. v:get_field("_SkillLv") .. ")</COL>") or "")
        end
    end
    Message = Message .. (settings.data.useHoppingSkewers and config.lang.dango.hoppingSkewers or "")

    if settings.data.notification then
        gm.ChatManager.d:call("reqAddChatInfomation", Message, settings.data.sounds and 2289944406 or 0)
    end

    Kitchen:set_field("_AvailableWaitTimer", Kitchen:call("get_WaitTime"))
end

function module.init()
	config = require "RiseEnhanced.utils.config"
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

	for _,v in pairs(gm) do
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
        dangoPerWeapon = false,
        weapons = {},
	}, config.folder .. "/" .. module.folder)

    for i = 1, 14, 1 do
		if settings.data.weapons[i] == nil then
			settings.data.weapons[i] = 0
		end
	end

	sdk.hook(
		sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
		function(args)
			OrderFood(CreateOrder(GetCurrentSet()))
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
    if imgui.tree_node(config.lang.dango.name) then
        if not allManagersRetrieved then
            imgui.text(config.lang.loading)
            return
        end

        local Kitchen = gm.FacilityDataManager.d:call("get_Kitchen")
        if not Kitchen then
            imgui.text(config.lang.loading)
            return
        end

        Kitchen = Kitchen:call("get_MealFunc")
        if not Kitchen then
            imgui.text(config.lang.loading)
            return
        end

        settings.imgui("enable", imgui.checkbox, config.lang.enable)
        imgui.new_line()

        settings.imgui("currentSet", imgui.slider_int, config.lang.dango.currentSet, 1, 32, Kitchen:call("get_MySetDataList"):call("get_Item", settings.data.currentSet - 1):call("get_OrderName"))

        settings.imgui("dangoPerWeapon", imgui.checkbox, config.lang.dango.dangoPerWeapon)
        if settings.data.dangoPerWeapon and imgui.tree_node(config.lang.weaponType) then
            for i = 1, 14, 1 do
                settings.imguit("weapons", i, imgui.slider_int, config.getWeaponName(i - 1), 0, 32, getSetName(Kitchen, i))
            end
            imgui.tree_pop();
        end

        imgui.new_line()
        settings.imgui("points", imgui.checkbox, config.lang.dango.points, settings.data.points)
        settings.imgui("useHoppingSkewers", imgui.checkbox, config.lang.dango.useHoppingSkewers, settings.data.useHoppingSkewers)
        settings.imgui("useVoucher", imgui.checkbox, config.lang.dango.useVoucher, settings.data.useVoucher)
        imgui.new_line()
        settings.imgui("notification", imgui.checkbox, config.lang.notification, settings.data.notification)
        settings.imgui("sounds", imgui.checkbox, config.lang.sounds, settings.data.sounds)
        imgui.new_line()

        local manualText = config.lang.dango.manualEat
        if Kitchen._AvailableWaitTimer > 0 then
            manualText = config.lang.dango.manualEatAgain
        end

        if imgui.button(manualText) then
            Kitchen:set_field("_AvailableWaitTimer", 0)
            OrderFood(CreateOrder(GetCurrentSet()))
        end
        imgui.tree_pop();
    end
end

return module