-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Item", {
        enabled = true,
        autoRestock = true,
        largeMonsterRestock = true,
        autoItems = true,
        infiniteItems = false,
        itemDuration = 0,
        buffRefreshCd = 0,
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
}

local isRampage = false

local freeMealSkill = { [0] = 0, 10, 25, 45 }
local itemProlongerSkill = { [0] = 1, 1.1, 1.25, 1.5 }

local pauseAutoItems = true
local drawFlag = false
local combatFlag = false
local questStartTrigger = false
local itemUsedTime = 0
local alwaysCd = 0.5

local player, playerIndex, playerRef

local itemProlonger = 1
local freeMeal = 0
local pouch = {}

-- Main code

local function getStaminaBuffCage()
    local stamina = 0
    local equipDataManager = utils.singleton("snow.data.EquipDataManager")
    local contentsIdDataManager = utils.singleton("snow.data.ContentsIdDataManager")
    local equipList = equipDataManager:get_field("<EquipDataList>k__BackingField"):get_elements()
    local buffCage = contentsIdDataManager:get_field("_NormalData")
    local buffCageList = buffCage:get_field("_BaseUserData"):get_field("_Param"):get_elements()
    local getLvBuffCageData = equipList[8]:call("getLvBuffCageData")
    local id = getLvBuffCageData:call("get_Id")
    local name = getLvBuffCageData:call("get_Name")

    for k, v in pairs(buffCageList) do
        local buffData = buffCageList[k]
        local buffDataId = buffData:get_field("_Id")
        local buffLimit = buffData:get_field("_StatusBuffLimit"):get_elements()

        if id == buffDataId then
            stamina = buffLimit[2]:get_field("mValue")
        end
    end

    return (stamina + 150) * 30
end

local function getItemSet(weapon)
    local loadout = settings.get("weaponSet")[weapon]

    if loadout == 0 then
        return settings.get("defaultSet"), true
    end

    return loadout, false
end

local function getItemSetById(id)
    local itemSet = utils.singleton("snow.data.DataManager", "get_ItemMySet")
    if itemSet == nil then return end
    return itemSet:call("getData", id)
end

local function getItemSetName(id)
    local itemSet = getItemSetById(id)
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
    local dataManager = utils.singleton("snow.data.DataManager")
    if not dataManager then return end
    local itemBox = dataManager:get_field("_ItemMySet")
    local itemSetId = getItemSet(utils.getPlayerWeapon() + 1) - 1
    local itemSet = getItemSetById(itemSetId)
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
        local shortcutManager = utils.singleton("snow.data.SystemDataManager", "getCustomShortcutSystem")
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

local function updateItemAndSkillData()
    itemProlonger = itemProlongerSkill[utils.playerSkillLevel(88, playerIndex)]
    freeMeal = freeMealSkill[utils.playerSkillLevel(90, playerIndex)]

    local dataManager = utils.singleton("snow.data.DataManager")
    local inventory = dataManager:get_field("_ItemPouch")
    inventory = inventory:get_field("<VirtualSortInventoryList>k__BackingField"):get_elements()
    local inventoryList = inventory[1]:get_field("mItems"):get_elements()

    local itemList = {}
    for _, item in pairs(inventoryList) do
        itemList[item:call("getItemId")] = item:call("getNum")
    end

    pouch = itemList
end

local function consume(id)
    utils.definition("snow.data.DataShortcut", "consumeItemFromPouch"):call(nil, id, 1)
end

local function useItem(item)
    local isBuff = utils.contains(item.types, "buff")

    if isBuff then
        for _, value in pairs(item.data) do
            if playerRef:get_field(value[1]) ~= 0 then
                return false, false -- buff already active
            end
        end
    end

    local free = false
    if not settings.get("infiniteItems") then
        free = freeMeal >= math.random(100)
        if pouch[item.id] == nil or pouch[item.id] == 0 then
            return false, false
        end
        if not free then
            consume(item.id)
        end
    end

    local applied = false

    -- handle stamina before buff in case dash juice doesn't increase stamina
    if utils.contains(item.types, "stamina") then
        local staminaCage = getStaminaBuffCage()
        if playerRef:get_field("_staminaMax") < staminaCage then
            playerRef:set_field("_staminaMax", staminaCage)
        end

        if playerRef:get_field("_stamina") < staminaCage then
            playerRef:set_field("_stamina", staminaCage)
        end
    end

    if utils.contains(item.types, "buff") then
        local dataList = utils.reference("_PlayerUserDataItemParameter")
        for _, value in pairs(item.data) do
            local name, buff, hasDuration = table.unpack(value)

            applied = true
            if hasDuration then
                local duration = settings.get("itemDuration") * 60 * itemProlonger
                if duration == 0 then
                    duration = dataList:get_field(buff) * 60 * itemProlonger
                end
                playerRef:set_field(name, duration)
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

local function inQuest()
    return utils.getQuestStatus() == 2 and utils.getQuestEndFlow() == 0
end

-- Hooks

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()
    re.on_frame(function ()
        if pauseAutoItems or not module.enabled("autoItems") or not inQuest() then
            return
        end

        local refreshLevel = 5
        local activationLevel = 5

        if utils.isWeaponSheathed() then
            drawFlag = true
        else
            refreshLevel = 4
            if drawFlag then
                activationLevel = 4
                drawFlag = false
            end
        end

        if not utils.inBattle() then
            combatFlag = true
        else
            refreshLevel = 3
            if combatFlag then
                activationLevel = 3
                combatFlag = false
            end
        end

        local cooldown = settings.get("buffRefreshCd")
        if cooldown > 0 and os.clock() - (itemUsedTime + cooldown) >= 0 then
            activationLevel = refreshLevel
        end

        if activationLevel == 5 and os.clock() - (itemUsedTime + math.max(alwaysCd, cooldown)) < 0 then
            return
        end

        updateItemAndSkillData()

        local item, used, free, message
        local usedFlag = false
        local activateList = {}
        for key, value in pairs(settings.get("itemList")) do
            if value >= activationLevel or (questStartTrigger and value == 2) then
                usedFlag = true
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

        if usedFlag then
            itemUsedTime = os.clock()
        end

        if questStartTrigger then
            questStartTrigger = false
        end

        if #activateList == 0 or not settings.get("notification") then
            return
        end

        message = "<COL YEL>" .. data.lang.Item.usedItems .. "</COL>"
        for _, value in pairs(activateList) do
            message = message .. "\n" .. value
        end
        utils.chat(message, settings.get("notificationSound") and 2289944406 or false)
    end)

    -- event hook for restocking inside quest
    sdk.hook(utils.definition("snow.QuestManager", "questStart"),
        function(args)
            if player == nil then
                player, playerIndex, playerRef, _ = utils.getPlayerData()
            end
            isRampage = utils.singleton("snow.QuestManager", "getHyakuryuCategory") ~= 2
            if not module.enabled("autoRestock") then return end
            utils.addTimer(3, function ()
                restock()
                questStartTrigger = true
                pauseAutoItems = false
            end)
        end,
        utils.retval
    )

    -- restock on cart
    sdk.hook(utils.definition("snow.QuestManager", "notifyDeath"),
        function(args)
            pauseAutoItems = true
            if not module.enabled() then return end
            utils.addTimer(5, function ()
                if settings.get("autoRestock") then
                    restock()
                end
                questStartTrigger = true
                pauseAutoItems = false
            end)
        end,
        utils.retval
    )

    -- restock on quest enemy kill
    local isLargeMonster = utils.definition("snow.enemy.EnemyCharacterBase", "get_isBossEnemy")
    sdk.hook(utils.definition("snow.enemy.EnemyCharacterBase", "questEnemyDie"),
        function (args)
            utils.addTimer(5, function ()
                if not settings.get("autoRestock")
                        or isRampage
                        or not settings.get("largeMonsterRestock")
                        or not inQuest()
                        or not isLargeMonster(sdk.to_managed_object(args[2])) then
                    return
                end

                restock()
            end)
        end,
        utils.retval
    )

    -- pause auto items
    sdk.hook(utils.definition("snow.gui.GuiManager", "notifyReturnInVillage"),
        function (args)
            pauseAutoItems = true
            itemUsedTime = 0
        end,
        utils.retval
    )
end

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    utils.setReference("_PlayerUserDataItemParameter", function ()
        return utils.singleton("snow.player.PlayerManager"):get_field("_PlayerUserDataItemParameter")
    end)
    if not inQuest() then return end
    if player == nil then
        player, playerIndex, playerRef, _ = utils.getPlayerData()
    end
    -- set flags
    isRampage = utils.singleton("snow.QuestManager", "getHyakuryuCategory") ~= 2

    drawFlag = utils.isWeaponSheathed()
    combatFlag = not utils.inBattle()

    pauseAutoItems = false
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("autoRestock", imgui.checkbox, data.lang.Item.autoRestock)
    settings.call("largeMonsterRestock", imgui.checkbox, data.lang.Item.largeMonsterRestock)
    if not utils.singleton("snow.data.DataManager") then
        settings.call("notification", imgui.checkbox, data.lang.notification)
        settings.call("notificationSound", imgui.checkbox, data.lang.sounds)
        imgui.text("\n" .. data.lang.loading)
        return
    end
    local setName = getItemSetName(settings.get("defaultSet") - 1)
    local defaultSet = string.format(data.lang.useDefault, setName)

    settings.slider("defaultSet", data.lang.Item.useDefaultItemSet, 1, 40, setName)
    if imgui.tree_node(data.lang.Item.perWeapon) then
        for key, value in pairs(data.lang.weaponNames) do
            settings.slider(
                {"weaponSet", key + 1},
                value,
                1,
                40,
                getItemSetName(getItemSet(key + 1) - 1),
                defaultSet
            )
        end
        module.resetButton("weaponSet")
        imgui.tree_pop()
    end
    settings.call("autoItems", imgui.checkbox, data.lang.Item.autoItems)
    settings.call("infiniteItems", imgui.checkbox, data.lang.Item.infiniteItems)
    settings.slider("itemDuration",
        data.lang.Item.itemDuration,
        0,
        600,
        utils.durationText(
            settings.get("itemDuration"),
            data.lang.secondText,
            data.lang.secondsText,
            data.lang.disabled
        ),
        10
    )
    settings.slider("buffRefreshCd",
        data.lang.Item.buffRefreshCd,
        0,
        10,
        utils.durationText(
            settings.get("buffRefreshCd"),
            data.lang.secondText,
            data.lang.secondsText,
            data.lang.disabled
        ),
        0.5
    )
    if imgui.tree_node(data.lang.Item.itemConfig) then
        for key, value in pairs(data.lang.Item.itemList) do
            local current = settings.get("itemList")[key]
            settings.slider(
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
    settings.call("notification", imgui.checkbox, data.lang.notification)
    settings.call("notificationSound", imgui.checkbox, data.lang.sounds)
end

return module