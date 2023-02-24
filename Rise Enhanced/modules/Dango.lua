-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = mod.getDefaultModule(
    "Dango", {
        enabled = true,
        increasedChance = true,
        ticket = true,
        skewers = true,
        kamuraPoints = false,
        infiniteTickets = false,
        showAllDango = false,
        skewerLevels = {4, 3, 1},
        autoEat = true,
        disableTimer = true,
        defaultSet = 1,
        defaultCartSet = 0,
        weaponSet = utils.filledTable(#mod.lang.weaponNames + 1, 0),
        cartWeaponSet = utils.filledTable(#mod.lang.weaponNames + 1, 0),
        notification = true,
        notificationSound = false
    }
)

local dango = {
    saved = nil,
    chance = 100,
    ticket = false
}

local isOrdering = false
local needStats = false
local carted = false
-- Main code

-- get meal function
local function getMeal()
    return utils.singleton("snow.data.FacilityDataManager", "get_Kitchen", "get_MealFunc")
end

local function getDangoSet(weapon, forceCarted)
    local set = 0
    local isDefault = false
    if carted or forceCarted then
        set = settings.get("cartWeaponSet")[weapon]
        if set == 0 then
            set = settings.get("defaultCartSet")
            isDefault = true
        end
    end

    if set == 0 then
        set = settings.get("weaponSet")[weapon]
        if set == 0 then
            set = settings.get("defaultSet")
            isDefault = true
        end
    end

    return set, isDefault
end

-- order dango function
local function autoDango()
    if not module.enabled() then return end
    if utils.getQuestStatus() ~= 0 and utils.getQuestStatus() ~= 2 then
        return true
    end

    -- if can't get kitchen return
    local kitchen = getMeal()
    if not kitchen then return false end

    if kitchen:get_field("_AvailableWaitTimer") > 0 then return true end

    -- get dango set for current weapon
    local dangoSet = getDangoSet(utils.getPlayerWeapon() + 1)

    -- get order
    local order = kitchen:call("getMySetList"):call("get_Item", dangoSet - 1)

    kitchen:call("resetDailyDango")

    if order:call("get__DangoId"):call("get_Item", 0) == 65 then
        utils.chat("<COL RED>%s</COL>",
                settings.get("notificationSound") and 2412657311 or 0, mod.lang.Dango.emptySet)
        return false
    end

    local facilityLevel = kitchen:call("get_FacilityLv")

    local contentsIdDataManager = utils.singleton("snow.data.ContentsIdDataManager")
    local tickets = contentsIdDataManager:call("getItemData", 0x410007c)
    local ticketCount = tickets:call("getCountInBox")

    if ticketCount > 0 then
        kitchen:set_field("_MealTicketFlag", settings.get("ticket"))
    else
        kitchen:set_field("_MealTicketFlag", false)
    end

    order:set_field("IsSpecialSkewer", settings.get("skewers"))

    isOrdering = true
    kitchen:call("order", order, settings.get("kamuraPoints") and 1 or 0, facilityLevel)
    isOrdering = false

    local orderName = order:call("get_OrderName")
    local message = string.format("<COL YEL>" .. mod.lang.Dango.eatMessage, orderName)
    if settings.get("ticket") then
        if ticketCount > 0 then
            message = message .. " (" .. string.format(mod.lang.Dango.ticketRemaining, ticketCount) .. ")"
        else
            message = message .. "</COL><COL RED> (" ..
                    mod.lang.Dango.outOufTickets .. ")</COL><COL YEL>"
        end
    end
    message = message .. "</COL>"

    local skillData = utils.getPlayer():get_field("_refPlayerSkillList"):call("get_KitchenSkillData")
    local dataShortcut = utils.reference("snow.data.DataShortcut")
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
        utils.chat("<COL RED>%s</COL>",
                settings.get("notificationSound") and 2412657311 or 0, mod.lang.Dango.eatingFailed)
        return false
    end

    if needStats then
        needStats = false
        -- set player hp and stamina when eating
        utils.hook({"snow.player.PlayerManager", "update"}, function()
            local playerData = utils.getPlayerData()
            local newHp = playerData:get_field("_vitalMax") + 50
            local newStamina = playerData:get_field("_staminaMax") + 1500
            playerData:set_field("_vitalMax", newHp)
            playerData:set_field("_r_Vital", newHp)
            playerData:call("set__vital", newHp + .0) -- context dependent
            playerData:set_field("_staminaMax", newStamina)
            playerData:set_field("_stamina", newStamina)
        end, nil, true)
    end

    if settings.get("skewers") then
        message = message .. "\n<COL YEL>(" .. mod.lang.Dango.hoppingSkewers .. ")</COL>"
    end

    if settings.get("notification") then
        utils.chat(message, settings.get("notificationSound") and 2289944406 or 0)
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

local function getDangoSetByWeapon(kitchen, weapon, hasCarted)
    local id, default = getDangoSet(weapon, hasCarted)
    local name = getDangoSetName(kitchen, id - 1)
    if default then
        return string.format(mod.lang.useDefault, name)
    end
    return name
end

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()
    -- Hooks

end

---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    utils.setReference("snow.data.DataShortcut", function ()
        return sdk.create_instance("snow.data.DataShortcut", true):add_ref()
    end)

    -- increase chance for dango skills on ticket when option is enabled
    utils.hook({"snow.data.DangoData", "get_SkillActiveRate"},
        function(args)
            if not module.enabled("increasedChance") then return end

            local kitchen = getMeal()
            if not kitchen then return false end

            dango.ticket = kitchen:call("getMealTicketFlag")
            if dango.ticket then
                dango.saved = sdk.to_managed_object(args[2])
                dango.chance = dango.saved:get_field("_Param"):get_field("_SkillActiveRate")
                dango.saved:get_field("_Param"):set_field("_SkillActiveRate", 100)
            end
        end, function(retval)
            if not module.enabled("increasedChance") and dango.ticket then return retval end

            dango.saved:get_field("_Param"):set_field("_SkillActiveRate", dango.chance)
            return retval
        end
    )

    -- inform GUI of dango levels
    utils.hook({"snow.gui.fsm.kitchen.GuiKitchen", "setDangoDetailWindow"}, function(args)
        if not module.enabled() then return end

        local gui = sdk.to_managed_object(args[2])
        local skewerLevel = gui:get_field("SpecialSkewerDangoLv")
        for i=0,2 do
            local newSkewerLevel = sdk.create_instance("System.UInt32")
            newSkewerLevel:set_field("mValue", settings.get("skewerLevels")[i+1])
            skewerLevel[i] = newSkewerLevel
        end
    end)

    -- inform dango order constructor of dango levels
    utils.hook({"snow.facility.kitchen.MealFunc", "updateList"},
        function()
            if not module.enabled() then return end
            local kitchen = getMeal()
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
            if not module.enabled("showAllDango") then return retval end

            local kitchen = getMeal()
            if not kitchen then return false end
            local dangoData = kitchen:get_field("<DangoDataList>k__BackingField"):call("ToArray")
            for _, value in ipairs(dangoData) do
                local flagDataManager = utils.singleton("snow.data.FlagDataManager")
                local isDangoUnlock = flagDataManager:call("isUnlocked(snow.data.DataDef.DangoId)", value:get_field("_Param"):get_field("_Id"))
                if isDangoUnlock then
                    value:get_field("_Param"):set_field("_DailyRate", 0)
                end
            end
            return retval
        end
    )

    -- return ticket and remove timer when respective option is enabled
    utils.hook({"snow.facility.kitchen.MealFunc", "order"}, nil, function(retval)
        if not module.enabled() then return retval end

        if settings.get("disableTimer") then
            local kitchen = getMeal()
            if kitchen then
                kitchen:set_field("_AvailableWaitTimer", 0)
            end
        end
        if settings.get("infiniteTickets") then
            local dataManager = utils.singleton("snow.data.DataManager")
            local itemBox = dataManager:get_field("_PlItemBox")
            itemBox:call("tryAddGameItem(snow.data.ContentsIdSystem.ItemId, System.Int32)", 68157564, 1)
        end
        return retval
    end)

    -- bypass check for eating
    utils.hook({"snow.facility.MealOrderData", "canOrder"}, nil, function(retval)
        if not module.enabled("autoEat") or not isOrdering then return retval end

        local bool = sdk.create_instance("System.Boolean"):add_ref()
        bool:set_field("mValue", true)
        return sdk.to_ptr(bool)
    end)

    -- clear carted state
    utils.hook({"snow.QuestManager", "onQuestEnd"}, function ()
        carted = false
    end)

    -- auto eat on cart
    utils.hookTimer({"snow.QuestManager", "notifyDeath"}, function()
        if not module.enabled("autoEat") then return end
        carted = true
        autoDango()
    end, 5)

    -- auto eat inside quest
    utils.hookTimer({"snow.QuestManager", "questStart"}, function ()
        if not module.enabled("autoEat") then return end
        needStats = true
        autoDango()
    end, 3)
end

-- Draw module
local function drawWeaponSliders(name, kitchen, property, hasCarted)
    if imgui.tree_node(name) then
        for key, value in pairs(mod.lang.weaponNames) do
            settings.slider(
                {property, key + 1},
                value,
                0,
                32,
                getDangoSetByWeapon(kitchen, key + 1, hasCarted)
            )
        end
        module.resetButton(property)
        imgui.tree_pop()
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("ticket", imgui.checkbox, mod.lang.Dango.useTicket)
    settings.call("increasedChance", imgui.checkbox, mod.lang.Dango.increasedChance)
    settings.call("skewers", imgui.checkbox, mod.lang.Dango.useHoppingSkewers)
    settings.call("kamuraPoints", imgui.checkbox, mod.lang.Dango.usePoints)
    settings.call("infiniteTickets", imgui.checkbox, mod.lang.Dango.infiniteTickets)
    settings.call("showAllDango", imgui.checkbox, mod.lang.Dango.showAllDango)
    imgui.text(mod.lang.restartNote)
    if imgui.tree_node(mod.lang.Dango.hoppingSkewersLevels) then
        for i, text in pairs(mod.lang.Dango.usableDangos) do
            settings.slider({ "skewerLevels", i }, text, 1, 4)
        end
        module.resetButton("skewerLevels")
        imgui.tree_pop()
    end
    settings.call("autoEat", imgui.checkbox, mod.lang.Dango.autoEat)
    settings.call("disableTimer", imgui.checkbox, mod.lang.Dango.disableTimer)
    settings.call("notification", imgui.checkbox, mod.lang.notification)
    settings.call("notificationSound", imgui.checkbox, mod.lang.sounds)

    local kitchen = getMeal()
    if not kitchen then
        imgui.text("\n" .. mod.lang.loading)
        return
    end

    local questStatus = utils.getQuestStatus()
    if (questStatus == 0 or questStatus == 2) and kitchen:get_field("_AvailableWaitTimer") > 0 then
        if imgui.button(mod.lang.Dango.resetEatTimer) then
            kitchen:set_field("_AvailableWaitTimer", 0)
        end
    end

    local setName = getDangoSetName(kitchen, settings.get("defaultSet") - 1)
    local defaultSet = string.format(mod.lang.useDefault, setName)

    settings.slider("defaultSet", mod.lang.Dango.defaultSet, 1, 32, setName)
    settings.slider("defaultCartSet", mod.lang.Dango.defaultCartSet, 1, 32, getDangoSetName(kitchen, settings.get("defaultCartSet") - 1), defaultSet)
    drawWeaponSliders(mod.lang.Dango.perWeapon, kitchen, "weaponSet", false)
    drawWeaponSliders(mod.lang.Dango.perWeaponCart, kitchen, "cartWeaponSet", true)
end

return module