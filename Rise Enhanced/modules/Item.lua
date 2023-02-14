-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings, cache = data.getDefaultModule(
    "Item", {
        enabled = true,
        restockOnQuest = true,
        defaultSet = 1,
        weaponSet = utils.filledTable(13, 0),
        notification = true,
        notificationSound = false
    }
)

-- Main code

local function getItemSet(weapon)
    local loadout = settings.get("weaponSet")[weapon]

    if loadout == 0 then
        return settings.get("defaultSet"), true
    end

    return loadout, false
end

local function getItemSetId(itemBox, id)
    local itemList = itemBox:get_field("_MySetList"):call("ToArray")
    return itemList[id]
end

local function getItemSetName(itemBox, id)
    local itemSet = getItemSetId(itemBox, id)
    local setName = itemSet:get_field("_Name")
    if string.len(setName) == 0 then
        return "? ? ? ? ? ? ? ?"
    end
    return setName
end

local function restock()
    if not module.enabled() then return end
    local itemBox = sdk.get_managed_singleton("snow.data.DataManager"):get_field("_ItemMySet")
    if not itemBox then return end
    local itemSet = getItemSet(utils.getPlayerWeapon() + 1)
    itemBox:call("applyItemMySet", itemSet - 1)
    local itemSetId = getItemSetId(itemBox, itemSet - 1)
    local itemSetName = itemSetId:get_field("_Name")
    local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")

    -- empty set
    if string.len(itemSetId:get_field("_Name")) == 0 then
        chatManager:call("reqAddChatInfomation", "<COL RED>" .. data.lang.Item.emptySet .. "</COL>", settings.get("notificationSound") and 2289944406 or 0)
        return
    end

    local message = "<COL YEL>" .. string.format(data.lang.Item.restocked, "</COL>" .. itemSetName .. "<COL YEL>" ) .. "</COL>"

    -- not enough items
    if not itemSetId:call("isEnoughItem") then
        message = message .. "\n<COL RED>" .. data.lang.Item.outOfStock .. "</COL>"
    end

    if settings.get("notification") then
        chatManager:call("reqAddChatInfomation", message, settings.get("notificationSound") and 2289944406 or 0)
    end
end

-- Hooks

-- restock when joining quest
sdk.hook(
    sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
    function(args)
        if not module.enabled() then return end

        if settings.get("restockOnQuest") then return end
        restock()
    end
)

-- event callback hook for restocking inside quest
re.on_pre_application_entry("UpdateBehavior",
    function()
        if utils.getQuestStatusName() ~= "quest" or cache.get("questCheck") then return end
        if not module.enabled() then return end

        cache.set("questCheck", true)
        if settings.get("restockOnQuest") then
            utils.addTimer(2, restock)
        end
    end
)

-- restock on cart
sdk.hook(sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"),
    function(args)
        if module.enabled() then
            utils.addTimer(5, restock)
        end
    end
)

-- clear cache
sdk.hook(sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
    function (args)
        cache.set("questCheck", false)
    end
)

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    cache.setNil("questCheck", false)
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("restockOnQuest", imgui.checkbox, data.lang.Item.restockOnQuest)
    settings.call("notification", imgui.checkbox, data.lang.Item.notify)
    settings.call("notificationSound", imgui.checkbox, data.lang.Item.sound)

    local itemBox = sdk.get_managed_singleton("snow.data.DataManager"):get_field("_ItemMySet")

    if not itemBox then return end

    local setName = getItemSetName(itemBox, settings.get("defaultSet") - 1)
    local defaultSet = string.format(data.lang.useDefault, setName)

    settings.sliderInt("defaultSet", data.lang.Item.useDefaultItemSet, 1, 40, setName)
    if imgui.tree_node(data.lang.Item.perWeapon) then
        for i = 1, 14 do
            settings.sliderInt(
                {"weaponSet", i},
                data.lang.weaponNames[i - 1],
                1,
                40,
                getItemSetName(itemBox, getItemSet(i) - 1),
                defaultSet
            )
        end
        imgui.tree_pop()
    end
end

return module