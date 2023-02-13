-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings, cache = data.getDefaultModule(
	"Dango", {
		enabled = true,
		increasedChance = true,
		ticket = true,
		skewers = true,
		kamuraPoints = false,
		infiniteTickets = true,
		showAllDango = false,
		skewerLevels = {4, 3, 1},
		autoEat = true,
        eatOnQuest = true,
        disableTimer = true,
		defaultSet = 1,
        defaultCartSet = 1,
		weaponSet = utils.filledTable(13, 0),
		cartWeaponSet = utils.filledTable(13, 0),
		notification = true,
        notificationSound = false
	}
)

local dango = {
    saved = nil,
    chance = 100,
    ticket = false
}

local dataShortcut = sdk.create_instance("snow.data.DataShortcut", true):add_ref()

-- Main code

-- get meal function
local function getMealFunction()
    local kitchen =
        sdk.get_managed_singleton("snow.data.FacilityDataManager"):call(
            "get_Kitchen")
    if not kitchen then return nil end
    kitchen = kitchen:call("get_MealFunc")

    if not kitchen then return nil end
    return kitchen
end

local function getDangoSet(weapon, forceCarted)
    local loadout = settings.get("weaponSet")[weapon]
    local isDefault = false
    if loadout == 0 then
        loadout = settings.get("defaultSet")
        isDefault = true
    end

    if cache.get("carted") or forceCarted then
        local carted = settings.get("cartWeaponSet")[weapon]
        if carted == 0 then
            if isDefault then
                carted = settings.get("defaultCartSet")
            else
                isDefault = true
            end
        end
        if carted ~= 0 then
            loadout = carted
        end
    end

    return loadout, isDefault
end

-- order dango function
local function autoDango()
    if not cache.get("shouldEat") then return end
    if not module.enabled() then return end
    if utils.getQuestStatus() ~= 0 and utils.getQuestStatus() ~= 2 then
        return true
    end

    -- if can't get kitchen return
    local kitchen = getMealFunction()
    if not kitchen then return false end

    if kitchen:get_field("_AvailableWaitTimer") > 0 then return true end

    -- get dango set for current weapon
    local dangoSet = getDangoSet(utils.getPlayerWeapon() + 1)

    -- get order
    local order = kitchen:call("getMySetList"):call("get_Item", dangoSet - 1)

    kitchen:call("resetDailyDango")

    local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")

    if order:call("get__DangoId"):call("get_Item", 0) == 65 then
        chatManager:call(
                "reqAddChatInfomation",
                "<COL RED>" .. data.lang.Dango.emptySet .. "</COL>",
                settings.get("notificationSound") and 2412657311 or 0)
        return false
    end

    local facilityLevel = kitchen:call("get_FacilityLv")

    local contentsIdDataManager = sdk.get_managed_singleton("snow.data.ContentsIdDataManager")
    local tickets = contentsIdDataManager:call("getItemData", 0x410007c)
    local ticketCount = tickets:call("getCountInBox")

    if ticketCount > 0 then
        kitchen:set_field("_MealTicketFlag", settings.get("ticket"))
    else
        kitchen:set_field("_MealTicketFlag", false)
    end

    order:set_field("IsSpecialSkewer", settings.get("skewers"))

	cache.set("isOrdering", true)
    kitchen:call("order", order, settings.get("kamuraPoints") and 1 or 0, facilityLevel)
    cache.set("isOrdering", false)

    local playerManager = sdk.get_managed_singleton("snow.player.PlayerManager")
    local player = playerManager:call("findMasterPlayer")

    local orderName = order:call("get_OrderName")
    local message = string.format("<COL YEL>" .. data.lang.Dango.eatMessage, orderName)
    if settings.get("ticket") then
        if ticketCount > 0 then
            message = message .. " (" .. string.format(data.lang.Dango.ticketRemaining, ticketCount) .. ")"
        else
            message = message .. "</COL><COL RED> (" ..
                    data.lang.Dango.outOufTickets .. ")</COL><COL YEL>"
        end
    end
    message = message .. "</COL>"

    local skillData = player:get_field("_refPlayerSkillList"):call("get_KitchenSkillData")
    local skillCount = 0
    for _, value in pairs(skillData:get_elements()) do
        if value:get_field("_SkillId") ~= 0 then
            message = message .. "\n" ..
                    dataShortcut:call("getName(snow.data.DataDef.PlKitchenSkillId)", value:get_field("_SkillId"))
            if settings.get("skewers") then
                message = message .. "<COL YEL> (lv " .. value:get_field("_SkillLv") .. ")</COL>"
            end
            skillCount = skillCount + 1
        end
    end

    if skillCount == 0 then
        chatManager:call("reqAddChatInfomation", "<COL RED>" .. data.lang.Dango.eatingFailed .. "</COL>", settings.get("notificationSound") and 2289944406 or 0)
        return false
    end

    if settings.get("skewers") then
        message = message .. "\n<COL YEL>(" .. data.lang.Dango.hoppingSkewers .. ")</COL>"
    end

    if settings.get("notification") then
        chatManager:call("reqAddChatInfomation", message, settings.get("notificationSound") and 2289944406 or 0)
    end

    if not settings.get("disableTimer") then
        kitchen:set_field("_AvailableWaitTimer", kitchen:call("get_WaitTime"))
    end
    return true
end

local function getDangoSetName(kitchen, id, default)
    if id < 0 or id > 31 then
        return default
    end
    return kitchen:call("get_MySetDataList"):call("get_Item", id):call("get_OrderName")
end

local function getDangoSetByWeapon(kitchen, weapon, carted)
    local id, default = getDangoSet(weapon, carted)
    local name = getDangoSetName(kitchen, id - 1)
    if default then
        return string.format(data.lang.useDefault, name)
    end
    return name
end

-- Hooks

-- increase chance for dango skills on ticket when option is enabled
sdk.hook(sdk.find_type_definition("snow.data.DangoData"):get_method("get_SkillActiveRate"),
    function(args)
        if not module.enabled() then return end

        if not settings.get("increasedChance") then return end
        local kitchen = getMealFunction()
        if not kitchen then return false end

        dango.ticket = kitchen:call("getMealTicketFlag")
        if dango.ticket then
            dango.saved = sdk.to_managed_object(args[2])
            dango.chance = dango.saved:get_field("_Param"):get_field("_SkillActiveRate")
            dango.saved:get_field("_Param"):set_field("_SkillActiveRate", 100)
        end
    end,
    function(retval)
        if not module.enabled() then return retval end

        if settings.get("increasedChance") and dango.ticket then
            dango.saved:get_field("_Param"):set_field("_SkillActiveRate", dango.chance)
        end

        return retval
    end
)

-- inform GUI of dango levels
sdk.hook(sdk.find_type_definition("snow.gui.fsm.kitchen.GuiKitchen"):get_method("setDangoDetailWindow"),
    function(args)
        if not module.enabled() then return end

        local gui = sdk.to_managed_object(args[2])
        local skewerLevel = gui:get_field("SpecialSkewerDangoLv")
        for i=0,2 do
            local newSkewerLevel = sdk.create_instance("System.UInt32")
            newSkewerLevel:set_field("mValue", settings.get("skewerLevels")[i+1])
            skewerLevel[i] = newSkewerLevel
        end
    end,
    function(retval)
        return retval
    end
)

--inform dango order constructor of dango levels
sdk.hook(sdk.find_type_definition("snow.facility.kitchen.MealFunc"):get_method("updateList"),
    function(args)
        if not module.enabled() then return end
        local kitchen = getMealFunction()
        if not kitchen then return false end
        if settings.get("ticket") then
            kitchen:call("setMealTicketFlag", true)
        end
        local skewerLevel = kitchen:get_field("SpecialSkewerDangoLv")
        for i=0,2 do
            local newSkewerLevel = sdk.create_instance("System.UInt32")
            newSkewerLevel:set_field("mValue", settings.get("skewerLevels")[i+1])
            skewerLevel[i] = newSkewerLevel
        end
    end,
    function(retval)
        if not module.enabled() then return retval end

        if settings.get("showAllDango") then
            local kitchen = getMealFunction()
            if not kitchen then return false end
            local dangoData = kitchen:get_field("<DangoDataList>k__BackingField"):call("ToArray")
            for _, value in ipairs(dangoData) do
                local flagDataManager = sdk.get_managed_singleton("snow.data.FlagDataManager")
                local isDangoUnlock = flagDataManager:call("isUnlocked(snow.data.DataDef.DangoId)", value:get_field("_Param"):get_field("_Id"))
                if isDangoUnlock then
                    value:get_field("_Param"):set_field("_DailyRate", 0)
                end
            end
        end
        return retval
    end
)

-- return ticket and remove timer when respective option is enabled
sdk.hook(sdk.find_type_definition("snow.facility.kitchen.MealFunc"):get_method("order"),
    function(args)
    end,
    function(retval)
        if cache.get("shouldEat") then
            cache.set("shouldEat", false)
        end

        if not module.enabled() then return retval end

        if settings.get("disableTimer") then
            local kitchen = getMealFunction()
            if kitchen then
                kitchen:set_field("_AvailableWaitTimer", 0)
            end
        end
        if settings.get("infiniteTickets") then
            local dataManager = sdk.get_managed_singleton("snow.data.DataManager")
            local itemBox = dataManager:get_field("_PlItemBox")
            itemBox:call("tryAddGameItem(snow.data.ContentsIdSystem.ItemId, System.Int32)", 68157564, 1)
        end
        return retval
    end
)

-- auto eat when joining quest
sdk.hook(
    sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
    function(args)
        if not module.enabled() then return end

        if settings.get("eatOnQuest") then return end
        autoDango()
    end
)

-- event callback hook for eating inside quest
re.on_pre_application_entry("UpdateBehavior",
    function()
        if utils.getQuestStatusName() ~= "quest" or cache.get("questCheck") then return end
        if not module.enabled() then return end

        cache.set("questCheck", true)
        if settings.get("eatOnQuest") then
            utils.addTimer(2, autoDango)
        end
    end
)

-- bypass check for eating
sdk.hook(
    sdk.find_type_definition("snow.facility.MealOrderData"):get_method("canOrder"),
    function(args)
    end,
    function(retval)
        if not module.enabled() then return retval end

        local bool
        if cache.get("isOrdering") then
            bool = sdk.create_instance("System.Boolean"):add_ref()
            bool:set_field("mValue", true)
            retval = sdk.to_ptr(bool)
        end
        return retval
    end
)

-- auto eat on cart
sdk.hook(sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"),
    function(args)
        if module.enabled() then
            cache.set("carted", true)
            cache.set("shouldEat", true)
            utils.addTimer(5, autoDango)
        end
    end
)

-- clear eat stats from cache
sdk.hook(sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
    function (args)
        cache.set("shouldEat", true)
        cache.set("carted", false)
        cache.set("questCheck", false)
    end
)

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    cache.setNil("shouldEat", true)
    cache.setNil("isOrdering", false)
    cache.setNil("carted", false)
    cache.setNil("questCheck", false)
end

local function drawWeaponSliders(name, kitchen, property, carted)
    if imgui.tree_node(name) then
        for i = 1, 14 do
            settings.sliderInt(
                {property, i},
                data.lang.weaponNames[i - 1],
                0,
                32,
                getDangoSetByWeapon(kitchen, i, carted)
            )
        end
        imgui.tree_pop()
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("ticket", imgui.checkbox, data.lang.Dango.useTicket)
    settings.call("increasedChance", imgui.checkbox, data.lang.Dango.increasedChance)
    settings.call("skewers", imgui.checkbox, data.lang.Dango.useHoppingSkewers)
    settings.call("kamuraPoints", imgui.checkbox, data.lang.Dango.usePoints)
    settings.call("infiniteTickets", imgui.checkbox, data.lang.Dango.infiniteTickets)
    settings.call("showAllDango", imgui.checkbox, data.lang.Dango.showAllDango)
    imgui.text(data.lang.restartNote)
    if imgui.tree_node(data.lang.Dango.hoppingSkewersLevels) then
		settings.sliderInt({ "skewerLevels", 1 }, data.lang.Dango.top, 1, 4)
		settings.sliderInt({ "skewerLevels", 2 }, data.lang.Dango.mid, 1, 4)
		settings.sliderInt({ "skewerLevels", 3 }, data.lang.Dango.bot, 1, 4)
		module.resetButton("skewerLevels")
		imgui.tree_pop()
	end
    settings.call("autoEat", imgui.checkbox, data.lang.Dango.autoEat)
    settings.call("eatOnQuest", imgui.checkbox, data.lang.Dango.eatOnQuest)
    imgui.text(data.lang.Dango.eatOnQuestNote)
    settings.call("disableTimer", imgui.checkbox, data.lang.Dango.disableTimer)
    settings.call("notification", imgui.checkbox, data.lang.Dango.notify)
    settings.call("notificationSound", imgui.checkbox, data.lang.Dango.sound)

    local kitchen = getMealFunction()
    if not kitchen then
        imgui.text("\n" .. data.lang.loading)
        return
    end

    local setName = getDangoSetName(kitchen, settings.get("defaultSet") - 1)
    local defaultSet = string.format(data.lang.useDefault, setName)

    settings.sliderInt("defaultSet", data.lang.Dango.defaultSet, 1, 32, setName)
    settings.sliderInt("defaultCartSet", data.lang.Dango.defaultCartSet, 0, 32, getDangoSetName(kitchen, settings.get("defaultCartSet") - 1, defaultSet))
    drawWeaponSliders(data.lang.Dango.perWeapon, kitchen, "weaponSet", false)
    drawWeaponSliders(data.lang.Dango.perWeaponCart, kitchen, "cartWeaponSet", true)

    local questStatus = utils.getQuestStatus()
    if questStatus == 0 or questStatus == 2 then
        if imgui.button(data.lang.Dango.manualEat) then
            if kitchen:get_field("_AvailableWaitTimer") > 0 then
                kitchen:set_field("_AvailableWaitTimer", 0)
            end
            if not cache.get("shouldEat") then
                cache.set("shouldEat", true)
            end
            autoDango()
        end
    end
end

return module