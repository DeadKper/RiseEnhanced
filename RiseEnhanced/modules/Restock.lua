local function filledTable(size)
    local table = {}
    for i = 1, size do table[i] = -1 end
    return table
end
local module = {
	folder = "Auto Restock",
    managers = {
        "ChatManager",
        "DataManager",
        "EquipDataManager",
        "ShortcutManager",
        "PlayerManager",
        "SystemDataManager",
    },
    default = {
		enable = true,
        cartEnable = true,
		notification = true,
		default = 1,
		language = "en-US",
		weaponConfig = filledTable(14),
		loadoutConfig = filledTable(112),
	},
}

local config
local settings

local restockTimeTreshold
local restockTime
local timedRestock
local lastRestock

------------- Config Management --------------
local function SendMessage(text)
    if not settings.data.notification then return end

    config.ChatManager:call("reqAddChatInfomation", text, 2289944406)
end

----------- Item Loadout Management ----------
-- itemSetIndex starts from 0
local function GetItemLoadout(loadoutIndex)
    -- snow.data.ItemMySet, snow.data.PlItemPouchMySetData
    return config.DataManager:call("get_ItemMySet"):call("getData", loadoutIndex)

    -- get_DangoMySet, snow.facility.DangoMySet
end

-- itemSetIndex starts from 0
local function ApplyItemLoadout(loadoutIndex)
    -- snow.data.ItemMySet, snow.data.PlItemPouchMySetData
    return config.DataManager:call("get_ItemMySet"):call("applyItemMySet", loadoutIndex)

    -- get_DangoMySet, snow.facility.DangoMySet
end

local function GetItemLoadoutName(loadoutIndex)
    return GetItemLoadout(loadoutIndex):call("get_Name")
end

----------- Equipment Loadout Managementt ----
local function GetEquipmentLoadout(loadoutIndex)
    local data = config.EquipDataManager:call("get_PlEquipMySetList"):call("get_Item", loadoutIndex) -- snow.equip.PlEquipMySetData
    return data
end

local function GetEquipmentLoadoutWeaponType(loadoutIndex)
    local success, result = pcall(GetEquipmentLoadout, loadoutIndex)
    if not success then return config.getWeaponType() end
    success, result = pcall(result.call, "getWeaponData")
    if not success then return config.getWeaponType() end
    success, result = pcall(result.call, "get_PlWeaponType")
    if not success then return config.getWeaponType() end
    return result
end

local function GetEquipmentLoadoutName(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("get_Name")
end

local function EquipmentLoadoutIsNotEmpty(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("get_IsUsing")
end

local function EquipmentLoadoutIsEquipped(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("isSamePlEquipPack")
end

--------------- Temporary Data ----------------
local lastHitLoadout = -1 -- Cached loadout, avoid unnecessary search

---------------  Localization  ----------------

    -- ["zh-CN"] = { Will be useful later for translations
    --     WeaponNames = {
    --         [0] = "大剑",
    --         [1] = "斩斧",
    --         [2] = "太刀",
    --         [3] = "轻弩",
    --         [4] = "重弩",
    --         [5] = "大锤",
    --         [6] = "铳枪",
    --         [7] = "长枪",
    --         [8] = "片手",
    --         [9] = "双刀",
    --         [10] = "笛子",
    --         [11] = "盾斧",
    --         [12] = "操虫棍",
    --         [13] = "弓",
    --     },
    --     UseDefaultItemSet = "使用默认设置",
    --     WeaponTypeNotSetUseDefault = "%s无设定，使用默认设置：%s",
    --     UseWeaponTypeItemSet = "使用%s设置：%s",

    --     FromLoadout = "已从个人组合[<COL YEL>%s</COL>]指定的[<COL YEL>%s</COL>]补充道具。",
    --     MismatchLoadout = "当前装备不匹配个人组合。\n",
    --     FromWeaponType = "已从武器类型[<COL YEL>%s</COL>]指定的[<COL YEL>%s</COL>]补充道具。",
    --     MismatchWeaponType = "当前装备不匹配个人组合，且武器类型[<COL YEL>%s</COL>]没有指定设置。\n",
    --     FromDefault = "已从默认设置[<COL YEL>%s</COL>]补充道具。",
    --     OutOfStock = "因<COL RED>库存不足</COL>,从[<COL YEL>%s</COL>]补充道具取消。",

    --     PaletteNilError = "<COL RED>发生了错误</COL>：轮盘组合为空。",
    --     PaletteApplied = "使用了轮盘组合[<COL YEL>%s</COL>]。",
    --     PaletteListEmpty = "没有轮盘组合，不应用。",
    -- }

local function UseDefaultItemSet()
    return config.lang.restock.useDefaultItemSet
end

local function WeaponTypeNotSetUseDefault(weaponName, itemName)
    return string.format(config.lang.restock.weaponTypeNotSetUseDefault, weaponName, itemName)
end

local function UseWeaponTypeItemSet(weaponName, itemName)
    return string.format(config.lang.restock.useWeaponTypeItemSet, weaponName, itemName)
end

local function FromLoadout(equipName, itemName)
    return string.format(config.lang.restock.fromLoadout, equipName, itemName)
end

local function FromWeaponType(equipName, itemName, mismatch)
    local msg = ""
    if mismatch then
        msg = config.lang.restock.mismatchLoadout
    end
    return msg .. string.format(config.lang.restock.fromWeaponType, equipName, itemName)
end

local function FromDefault(itemName, mismatch)
    local msg = ""
    if mismatch then
        msg = string.format(config.lang.restock.mismatchWeaponType, config.getWeaponName())
    end
    return msg .. string.format(config.lang.restock.fromDefault, itemName)
end

local function OutOfStock(itemName)
    return string.format(config.lang.restock.fromDefault, itemName)
end

local function PaletteNilError()
    return config.lang.restock.paletteNilError
end

local function PaletteApplied(paletteName)
    return string.format(config.lang.restock.paletteApplied, paletteName)
end

local function PaletteListEmpty()
    return config.lang.restock.paletteListEmpty
end

---------------      CORE      ----------------
-- weaponType starts from 0
local function GetWeaponTypeItemLoadoutName(weaponType)
    local got = settings.data.weaponConfig[weaponType + 1]
    if (got == nil) or (got == -1) then
        return UseDefaultItemSet()
    end
    return GetItemLoadoutName(got)
end

-- loadoutIndex starts from 0
local function GetLoadoutItemLoadoutIndex(loadoutIndex)
    local got = settings.data.loadoutConfig[loadoutIndex + 1]
    if (got == nil) or (got == -1) then
        local weaponType = GetEquipmentLoadoutWeaponType(loadoutIndex)

        local got = settings.data.weaponConfig[weaponType+1]
        if (got == nil) or (got == -1) then
            return WeaponTypeNotSetUseDefault(config.getWeaponName(weaponType), GetItemLoadoutName(settings.data.default))
        end

        return UseWeaponTypeItemSet(config.getWeaponName(weaponType), GetItemLoadoutName(got))
    end
    return GetItemLoadoutName(got)
end

local function GetFromCache(miss)
    local loadoutIndex, itemLoadoutIndex
    loadoutIndex = config.cache("loadoutIndex")
    if loadoutIndex == nil then
        return { settings.data.default, "Default", "", miss }
    end

    itemLoadoutIndex = settings.data.loadoutConfig[loadoutIndex + 1]
    if itemLoadoutIndex ~= nil and itemLoadoutIndex ~= -1 then
        return { itemLoadoutIndex, "Loadout", config.cache("loadoutName"), miss }
    end
    itemLoadoutIndex = settings.data.weaponConfig[config.cache("loadoutWeaponType") + 1]

    if itemLoadoutIndex ~= nil and itemLoadoutIndex ~= -1 then
        return { itemLoadoutIndex, "WeaponType", config.getWeaponName(config.cache("loadoutWeaponType")), miss }
    end

    return { settings.data.default, "Default", "", miss }
end

-- arg loadoutIndex is set when player applying equipment loadout
-- If loadOutIndex == nil, use cached loadout. if cache missed, search all loadouts.
-- If no loadout matched, use weapon type.
-- If no weapon type setting, use default.
local function AutoChooseItemLoadout(loadoutIndex)
    local cacheHit = false
    local loadoutMismatch = false
    if loadoutIndex then
        -- player is applying loadout
        cacheHit = true
        -- Please note that the function is hooked in pre-function, so the player's current equipments haven't changed yet
        -- So here we do not determine whether the loadout is really equipped or not
        lastHitLoadout = loadoutIndex
        local got = settings.data.loadoutConfig[loadoutIndex + 1]
        if (got ~= nil) and (got ~= -1) then
            return { got, "Loadout", GetEquipmentLoadoutName(loadoutIndex) }
        end
    else
        -- player is accepting quest
        if lastHitLoadout ~= -1 then
            -- check the cached loadout first
            local cachedLoadoutIndex = lastHitLoadout
            if EquipmentLoadoutIsEquipped(cachedLoadoutIndex) then
                lastHitLoadout = cachedLoadoutIndex
                cacheHit = true
                local got = settings.data.loadoutConfig[cachedLoadoutIndex + 1]
                if (got ~= nil) and (got ~= -1) then
                    return { got, "Loadout", GetEquipmentLoadoutName(cachedLoadoutIndex) }
                end
            else
                -- SendMessage(EquipmentChanged())
            end
        end

        if not cacheHit then
            local got, type, name, _ = table.unpack(GetFromCache())
            if got ~= nil and got ~= -1 then
                return { got, type, name }
            end
        end

        if not cacheHit then
            local found = false
            for i = 1, 112, 1 do
                loadoutIndex = i - 1
                if EquipmentLoadoutIsEquipped(loadoutIndex) then
                    found = true
                    lastHitLoadout = i
                    local got = settings.data.loadoutConfig[i]
                    if (got ~= nil) and (got ~= -1) then
                        config.updateEquipmentLoadoutCache(loadoutIndex)
                        return { got, "Loadout", GetEquipmentLoadoutName(loadoutIndex) }
                    end
                    break
                end
            end
            if not found then
                loadoutMismatch = true
            end
        end
    end

    local weaponType
    if loadoutIndex then
        weaponType = GetEquipmentLoadoutWeaponType(loadoutIndex)
    else
        weaponType = config.getWeaponType()
    end
    local got = settings.data.weaponConfig[weaponType+1]
    if (got ~= nil) and (got ~= -1) then
        return { got, "WeaponType", config.getWeaponName(weaponType), loadoutMismatch }
    end

    return { settings.data.default, "Default", "", loadoutMismatch }
end

------------------------

local function Restock(loadoutIndex)
    if not config.isEnabled(settings.data.enable, module.managers) then return end
    if config.getQuestStatus() ~= 0 and config.getQuestStatus() ~= 2 then
        return
    end

    local itemLoadoutIndex, matchedType, matchedName, loadoutMismatch
    local success, result = pcall(AutoChooseItemLoadout, loadoutIndex)
    if success then
        itemLoadoutIndex, matchedType, matchedName, loadoutMismatch = table.unpack(result)
    else
        itemLoadoutIndex, matchedType, matchedName, loadoutMismatch = table.unpack(GetFromCache())
    end

    local loadout = GetItemLoadout(itemLoadoutIndex)
    local itemLoadoutName = loadout:call("get_Name")

    local returnFlag = false

    returnFlag = timedRestock and
        restockTimeTreshold > config.time() - restockTime and
        lastRestock == itemLoadoutName

    returnFlag = returnFlag or (
        not timedRestock and
        lastRestock == itemLoadoutName
    )

    restockTime = config.time()
    lastRestock = itemLoadoutName

    if returnFlag then return end

    local msg = ""
    if loadout:call("isEnoughItem") then
        -- loadout:call("exportToPouch", false)
        ApplyItemLoadout(itemLoadoutIndex)
        if matchedType == "Loadout" then
            msg = FromLoadout(matchedName, itemLoadoutName)
        elseif matchedType == "WeaponType" then
            msg = FromWeaponType(matchedName, itemLoadoutName, loadoutMismatch)
        else
            msg = FromDefault(itemLoadoutName, loadoutMismatch)
        end

        -- Apply Radial Menu
        local paletteIndex = loadout:call("get_PaletteSetIndex") -- Nullable type so we call GetValueOrDefault later
        if paletteIndex == nil then
            msg = msg .. "\n" .. PaletteNilError()
        else
            local radialSetIndex = paletteIndex:call("GetValueOrDefault")
            -- SendMessage(CycleTypeMap[0] .. " Palette: " .. radialSetIndex)
            local paletteList = config.ShortcutManager:call("getPaletteSetList", 0) -- 0 is Quest
            if paletteList then
                local palette = paletteList:call("get_Item", radialSetIndex)
                if palette then
                    msg = msg .. "\n" .. PaletteApplied(palette:call("get_Name"))
                end
            else
                msg = msg .. "\n" .. PaletteListEmpty()
            end
            config.ShortcutManager:call("setUsingPaletteIndex", 0, radialSetIndex)
        end
    else
        msg = OutOfStock(itemLoadoutName)
    end
    SendMessage(msg)
end

local function resetRestock(retval)
    lastRestock = nil
    return retval
end

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

    restockTimeTreshold = 30
    restockTime = 0

	lastRestock = nil
    timedRestock = false

	-- On apply equipment loadout
	sdk.hook(
		sdk.find_type_definition("snow.data.EquipDataManager"):get_method("applyEquipMySet(System.Int32)"),
		--snow.equip.PlEquipMySetData
		function(args)
			local idx = sdk.to_int64(args[3])
			Restock(idx)
		end
	)

	-- On accept quest
	sdk.hook(
		sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
		function(args)
			Restock()
		end
	)

    -- Only rembember last restock for 30 seconds while inside a quest
    re.on_pre_application_entry("UpdateBehavior", function()
        -- If Auto spawn is enabled and quest status says it's active
        if config.getQuestStatus() == 2 and settings.data.enable and not timedRestock then
            timedRestock = true
            restockTime = config.getQuestInitialTime()
        elseif config.getQuestStatus() ~= 2 and timedRestock then
            timedRestock = false
        end
    end)

    -- Reset lastRestock then dying
    sdk.hook(sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"), function ()
        resetRestock()
        if settings.data.cartEnable then
            config.addTimer(5, Restock)
        end
    end)

    -- Reset lastRestock when killing a monster
    sdk.hook(sdk.find_type_definition("snow.enemy.EnemyCharacterBase"):get_method("questEnemyDie"), resetRestock)

    -- Reset lastRestock when returning to village
	sdk.hook(
	    sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"), resetRestock)
end

function module.draw()
	if imgui.tree_node(config.lang.restock.name) then
        if not config.managersRetrieved(module.managers) then
            imgui.text(config.lang.loading)
            imgui.tree_pop()
        end

        settings.imgui("enable", imgui.checkbox, config.lang.enable)
        settings.imgui("cartEnable", imgui.checkbox, config.lang.restock.restockAfterDying)
        settings.imgui("notification", imgui.checkbox, config.lang.notification)

        settings.imgui("default", imgui.slider_int, config.lang.useDefault, 0, 39,
        GetItemLoadoutName(settings.data.default))

        if imgui.tree_node(config.lang.weaponType) then
            for i = 1, 14, 1 do
                local weaponType = i - 1
                settings.imguit("weaponConfig", i, imgui.slider_int, config.getWeaponName(weaponType), -1, 39, GetWeaponTypeItemLoadoutName(weaponType))
            end
            imgui.tree_pop()
        end

        if imgui.tree_node(config.lang.restock.equipmentLoadout) then
            for i = 1, 112, 1 do
                local loadoutIndex = i - 1
                local name = GetEquipmentLoadoutName(loadoutIndex)
                local isUsing = EquipmentLoadoutIsNotEmpty(loadoutIndex)
                if name and isUsing then
                    local same = EquipmentLoadoutIsEquipped(loadoutIndex)
                    local msg = ""
                    if same then msg = config.lang.restock.currentSet end
                    settings.imguit("loadoutConfig", i, imgui.slider_int, name .. msg, -1, 39, GetLoadoutItemLoadoutIndex(loadoutIndex))
                end
            end
            imgui.tree_pop();
        end
		imgui.tree_pop()
	end
end

return module