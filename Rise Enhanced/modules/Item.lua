-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Item", {
        enabled = true,
        autoItems = true,
        infiniteItems = false,
        combatRefresh = true,
        itemList = utils.filledTable(#data.lang.Item.itemList, 1),
        defaultSet = 1,
        weaponSet = utils.filledTable(#data.lang.weaponNames + 1, 0),
        notification = true,
        notificationSound = false
    }
)

local function makeItemData(id, effect, types, fieldData)
    return {
        id = id,
        effect = effect,
        types = types,
        data = fieldData
    }
end

local consumables = {
    -- attack items
    makeItemData(68157917, 110, { "buff" },
            { { "_AtkUpAlive", "_DemondrugAtkUp", false } }),
    makeItemData(68157918, 110, { "buff" },
            { { "_AtkUpAlive", "_GreatDemondrugAtkUp", false } }),
    makeItemData(68157919, 110, { "buff" },
            { { "_AtkUpBuffSecond", "_MightSeedAtkUp", false },
                { "_AtkUpBuffSecondTimer", "_MightSeedTimer", true }}),
    makeItemData(68157920, 110, { "buff" },
            { { "_AtkUpItemSecond", "_DemondrugPowderAtkUp", false },
                { "_AtkUpItemSecondTimer", "_DemondrugPowderTimer", true }}),

    -- defense items
    makeItemData(68157922, 110, { "buff" },
            { { "_DefUpAlive", "_ArmorSkinDefUp", false } }),
    makeItemData(68157923, 110, { "buff" },
            { { "_DefUpAlive", "_GreatArmorSkinDefUp", false } }),
    makeItemData(68157924, 110, { "buff" },
            { { "_DefUpBuffSecond", "_AdamantSeedDefUp", false },
                { "_DefUpBuffSecondTimer", "_AdamantSeedTimer", true }}),
    makeItemData(68157925, 110, { "buff" },
            { { "_DefUpItemSecond", "_ArmorSkinPowderDefUp", false },
                { "_DefUpItemSecondTimer", "_ArmorSkinPowderTimer", true }}),

    -- misc buff items
    makeItemData(68157909, 100, { "buff" },
            { { "_FishRegeneEnableTimer", "_WellDoneFishEnableTimer", true } }),
    makeItemData(68157911, 102, { "buff" },
            { { "_VitalizerTimer", "_VitalizerTimer", true } }),
    makeItemData(68157913, 102, { "buff", "stamina" },
            { { "_StaminaUpBuffSecondTimer", "_StaminaUpBuffSecond", true } }),

    -- misc items
    -- makeItemData(0, -1, { "sharpness" }),
    -- makeItemData(68157445, 100, { "health" }),
    -- makeItemData(68157912, -1, { "stamina" }),

    -- misc supply items
    -- makeItemData("EZ Ration", 68157940, -1, { "stamina" }),
    -- makeItemData("First-aid Med", 68157941, -1, { "health" }),
    -- makeItemData("First-aid Med+", 68157942, -1, { "health" }),
    -- makeItemData("EZ Max Potion", 68157943, -1, { "health" }),
}

local polishSkill = { [0] = 0, 30, 60, 90 }
local freeMealSkill = { [0] = 0, 10, 25, 45 }
local itemProlongerSkill = { [0] = 1, 1.1, 1.25, 1.5 }
local dataTable = {
    playerDataManager = {},
    playerList = {},
    player = {},
    playerIndex = {},
    dataItemList = {},
    pouchItems = {},
    itemProlongerLevel = 0,
    freeMealLevel = 0,
    polishLevel = 0,
    inCombat = false,
    isUpdated = false,
}

-- Main code

local function getItemSet(weapon)
    local loadout = settings.get("weaponSet")[weapon]

    if loadout == 0 then
        return settings.get("defaultSet"), true
    end

    return loadout, false
end

local function getItemSetById(id, _dataManager)
    if _dataManager == nil then
        _dataManager = sdk.get_managed_singleton("snow.data.DataManager")
    end
    if _dataManager == nil then return end
    local itemSet = _dataManager:call("get_ItemMySet")
    return itemSet:call("getData", id)
end

local function getItemSetName(id, _dataManager)
    local itemSet = getItemSetById(id, _dataManager)
    if itemSet == nil then
        return "? ? ? ? ? ? ? ?"
    end
    local setName = itemSet:get_field("_Name")
    if string.len(setName) == 0 then
        return "? ? ? ? ? ? ? ?"
    end
    return setName
end

local function restock()
    if not module.enabled() then return end
    local dataManager = sdk.get_managed_singleton("snow.data.DataManager")
    if not dataManager then return end
    local itemBox = dataManager:get_field("_ItemMySet")
    local itemSetId = getItemSet(utils.getPlayerWeapon() + 1) - 1
    local itemSet = getItemSetById(itemSetId, dataManager)
    ---@diagnostic disable-next-line: need-check-nil
    local itemSetName = itemSet:get_field("_Name")

    -- empty set
    if string.len(itemSetName) == 0 then
        utils.chat("<COL RED>%s</COL>",
                settings.get("notificationSound") and 2412657311 or 0, data.lang.Item.emptySet)
        return
    end

    itemBox:call("applyItemMySet", itemSetId)

    local message = "<COL YEL>" .. string.format(data.lang.Item.restocked, "</COL>" .. itemSetName)

    ---@diagnostic disable-next-line: need-check-nil
    local radialSetId = itemSet:call("get_PaletteSetIndex")
    if radialSetId == nil then
        message = message .. "\n<COL RED>" .. data.lang.Item.nilRadial .. "</COL>"
    else
        local shortcutManager = sdk.get_managed_singleton("snow.data.SystemDataManager")
                :call("getCustomShortcutSystem")
        local radialSet = radialSetId:call("GetValueOrDefault")
        local radialList = shortcutManager:call("getPaletteSetList", 0) -- current set
        if radialList then
            local radial = radialList:call("get_Item", radialSet)
            if radial then
                message = message .. string.format(
                        "\n<COL YEL>" .. data.lang.Item.radialApplied .. "</COL>",
                        "</COL>" .. radial:call("get_Name"))
                shortcutManager:call("setUsingPaletteIndex", 0, radialSet)
            else
                message = message .. data.lang.Item.emptyRadial
            end
        end
    end

    -- not enough items
    ---@diagnostic disable-next-line: need-check-nil
    if not itemSet:call("isEnoughItem") then
        message = message .. "\n<COL RED>" .. data.lang.Item.outOfStock .. "</COL>"
    end

    if settings.get("notification") then
        utils.chat(message, settings.get("notificationSound") and 2289944406 or 0)
    end
end

local function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

local function getPouchItemList()
    -- get inventory --
    local dataManager = sdk.get_managed_singleton("snow.data.DataManager")
    local inventory = dataManager:get_field("_ItemPouch")
    inventory = inventory:get_field("<VirtualSortInventoryList>k__BackingField"):get_elements()
    local inventoryList = inventory[1]:get_field("mItems"):get_elements()

    local itemList = {}
    for _, item in pairs(inventoryList) do
        itemList[item:call("getItemId")] = item:call("getNum")
    end

    return itemList
end

local function consume(id)
    sdk.find_type_definition("snow.data.DataShortcut"):get_method("consumeItemFromPouch"):call(nil, id, 1)
end

local function updateDataTable()
    dataTable.itemProlongerLevel = dataTable.playerDataManager:call("getHasPlayerSkillLvInQuestAndTrainingArea", dataTable.playerIndex, 88)
    dataTable.freeMealLevel = dataTable.playerDataManager:call("getHasPlayerSkillLvInQuestAndTrainingArea", dataTable.playerIndex, 90)
    dataTable.polishLevel = dataTable.playerDataManager:call("getHasPlayerSkillLvInQuestAndTrainingArea", dataTable.playerIndex, 25)
    dataTable.pouchItems = getPouchItemList()
    dataTable.inCombat = utils.inBattle()
    dataTable.isUpdated = true
end

local function makeDataTable()
    dataTable.playerDataManager = sdk.get_managed_singleton("snow.player.PlayerManager")
    dataTable.playerList = dataTable.playerDataManager:get_field("<PlayerData>k__BackingField"):get_elements()
    dataTable.player = utils.getPlayer()
    dataTable.playerIndex = dataTable.player:call("getPlayerIndex")

    dataTable.dataItemList = dataTable.playerDataManager:get_field("_PlayerUserDataItemParameter")

    updateDataTable()
end

local function useItem(item)
    local playerRef = dataTable.playerList[dataTable.playerIndex + 1]
    local isBuff = contains(item.types, "buff")

    if isBuff then
        for _, value in pairs(item.data) do
            if playerRef:get_field(value[1]) ~= 0 then
                return false, false -- buff already active
            end
        end
    end

    if not dataTable.isUpdated then
        updateDataTable()
    end

    local player = dataTable.player
    local pouchItems = dataTable.pouchItems
    local free = false
    local applied = false

    -- consume items
    if not settings.get("infiniteItems") and item.id ~= 0 then
        free = freeMealSkill[dataTable.freeMealLevel] >= math.random(100)
        if pouchItems[item.id] == nil or pouchItems[item.id] == 0 then
            return false, false
        end
        if not free then
            consume(item.id)
        end
    end

    -- handle stamina before buff in case dash juice doesn't increase stamina
    if contains(item.types, "stamina") then
        local staminaMax = player:get_field("_staminaMax")

        if player:get_field("_stamina") < staminaMax then
            applied = true
            player:set_field("_stamina", staminaMax)
        end
    end

    -- if contains(item.types, "health") and not dataTable.inCombat then
    --     local maxHp = player:get_field("_vitalMax")
    --     if player:get_field("_r_Vital") < maxHp then
    --         applied = true
    --         player:set_field("_r_Vital", maxHp)
    --     end
    -- end

    local itemProlongerMultiplier = itemProlongerSkill[dataTable.itemProlongerLevel]

    -- if contains(item.types, "sharpness") then
    --     local maxSharpness = player:get_field("<SharpnessGaugeMax>k__BackingField")
    --     local currentSharpness = player:get_field("<SharpnessGauge>k__BackingField")

    --     if currentSharpness ~= maxSharpness then
    --         -- check protective polish --
    --         player:set_field("_SharpnessGaugeBoostTimer",
    --                 polishSkill[dataTable.polishLevel] * 60 * itemProlongerMultiplier)
    --         -- heal sharpness guage --
    --         player:set_field("<SharpnessGauge>k__BackingField", maxSharpness)
    --         applied = true
    --     end
    -- end

    if contains(item.types, "buff") then
        local dataList = dataTable.dataItemList
        for _, value in pairs(item.data) do
            local name, buff, hasDuration = table.unpack(value)

            applied = true
            if hasDuration then
                playerRef:set_field(name, dataList:get_field(buff) * 60 * itemProlongerMultiplier)
            else
                playerRef:set_field(name, dataList:get_field(buff))
            end
        end
    end

    if applied and item.effect > 0 then
        player:call("setEffect", 100, item.effect)
    end

    return applied, free
end

local pauseAutoItems = true
local drawFlag = false
local combatFlag = false
local questStartTrigger = false

local function autoItems()
    local activationLevel = 5

    if utils.isWeaponSheathed() then
        drawFlag = true
    elseif drawFlag then
        activationLevel = 4
        drawFlag = false
    end

    if not utils.inBattle() then
        combatFlag = true
    elseif combatFlag or settings.get("combatRefresh") then
        activationLevel = 3
        combatFlag = false
    end

    local item, used, free, message
    local activateList = {}
    for key, value in pairs(settings.get("itemList")) do
        if value >= activationLevel or (questStartTrigger and value == 2) then
            -- why lua doesn't have "continue"? so dumb
            item = consumables[key]
            used, free = useItem(item)
            if used then
                message = data.lang.Item.itemList[key]
                if free then
                    message = message .. " (free meal)"
                end
                table.insert(activateList, message)
            end
        end
    end

    if questStartTrigger then
        questStartTrigger = false
    end

    dataTable.isUpdated = false

    if #activateList == 0 or not settings.get("notification") then
        return
    end

    message = "<COL YEL>" .. data.lang.Item.usedItems .. "</COL>"
    for _, value in pairs(activateList) do
        message = message .. "\n" .. value
    end
    utils.chat(message, settings.get("notificationSound") and 2289944406 or false)
end

local function inQuest()
    return utils.getQuestStatus() == 2 and utils.getQuestEndFlow() == 0
end

-- Hooks

re.on_frame(function ()
    if pauseAutoItems or not module.enabled() or not inQuest() or not settings.get("autoItems") then
        return
    end
    autoItems()
end)

-- check for items every second
re.on_pre_application_entry("UpdateBehavior", function()
    if not inQuest() then return end
    makeDataTable()

    -- set flags
    drawFlag = utils.isWeaponSheathed()
    combatFlag = not utils.inBattle()

    utils.addTimer(3, function ()
        pauseAutoItems = false
    end)
end)

-- event callback hook for restocking inside quest
sdk.hook(sdk.find_type_definition("snow.QuestManager"):get_method("questStart"),
    function(args)
        if not module.enabled() then return end
        utils.addTimer(2, function ()
            restock()
            questStartTrigger = true
            pauseAutoItems = false
        end)
    end
)

-- restock on cart
sdk.hook(sdk.find_type_definition("snow.QuestManager"):get_method("notifyDeath"),
    function(args)
        if not module.enabled() then return end
        pauseAutoItems = true
        utils.addTimer(5, function ()
            restock()
            pauseAutoItems = false
        end)
    end
)

-- pause auto items
sdk.hook(sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
    function (args)
        pauseAutoItems = true
    end
)

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("autoItems", imgui.checkbox, data.lang.Item.autoItems)
    settings.call("infiniteItems", imgui.checkbox, data.lang.Item.infiniteItems)
    settings.call("combatRefresh", imgui.checkbox, data.lang.Item.combatRefresh)
    settings.call("notification", imgui.checkbox, data.lang.notification)
    settings.call("notificationSound", imgui.checkbox, data.lang.sounds)

    local dataManager = sdk.get_managed_singleton("snow.data.DataManager")
    if not dataManager then
        imgui.text("\n" .. data.lang.loading)
        return
    end

    local setName = getItemSetName(settings.get("defaultSet") - 1, dataManager)
    local defaultSet = string.format(data.lang.useDefault, setName)

    settings.sliderInt("defaultSet", data.lang.Item.useDefaultItemSet, 1, 40, setName)
    if imgui.tree_node(data.lang.Item.perWeapon) then
        for key, value in pairs(data.lang.weaponNames) do
            settings.sliderInt(
                {"weaponSet", key + 1},
                value,
                1,
                40,
                getItemSetName(getItemSet(key + 1) - 1, dataManager),
                defaultSet
            )
        end
        imgui.tree_pop()
    end
    if imgui.tree_node(data.lang.Item.itemConfig) then
        for key, value in pairs(data.lang.Item.itemList) do
            local current = settings.get("itemList")[key]
            settings.sliderInt(
                {"itemList", key},
                value,
                1,
                5,
                data.lang.Item.triggerList[current]
            )
        end
        module.resetButton("itemList")
        imgui.tree_pop()
    end
end

return module