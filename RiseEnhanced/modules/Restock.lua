local module = {
	name = "Auto Restock",
}

local info
local modUtils
local settings
local restockTimeTreshold
local restockTime
local timedRestock
local lastRestock

----------- Helper Functions ----------------
local ChatManager = sdk.get_managed_singleton("snow.gui.ChatManager")

local function FindIndex(table, value)
    for i = 1, #table do
        if table[i] == value then
            return i;
        end
    end

    return nil;
end

local function GetEnumMap(enumTypeName)
    local t = sdk.find_type_definition(enumTypeName)
    if not t then return {} end

    local fields = t:get_fields()
    local enum = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local raw_value = field:get_data(nil)
            enum[raw_value] = name
        end
    end

    return enum
end

local CycleTypeMap = GetEnumMap("snow.data.CustomShortcutSystem.SycleTypes")

------------- Config Management --------------
local Languages = {"en-US", "zh-CN"}

local function SendMessage(text)
    if not settings.data.notification then return end
    if ChatManager == nil then
        ChatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
    end
    ChatManager:call("reqAddChatInfomation", text, 2289944406)
end

----------- Item Loadout Management ----------
local SystemDataManager = sdk.get_managed_singleton("snow.data.SystemDataManager")
local ShortcutManager = nil
if SystemDataManager then
    ShortcutManager = SystemDataManager:call("getCustomShortcutSystem")
end
local DataManager = sdk.get_managed_singleton("snow.data.DataManager")

-- itemSetIndex starts from 0
local function GetItemLoadout(loadoutIndex)
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    -- snow.data.ItemMySet, snow.data.PlItemPouchMySetData
    return DataManager:call("get_ItemMySet"):call("getData", loadoutIndex)

    -- get_DangoMySet, snow.facility.DangoMySet
end

-- itemSetIndex starts from 0
local function ApplyItemLoadout(loadoutIndex)
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    -- snow.data.ItemMySet, snow.data.PlItemPouchMySetData
    return DataManager:call("get_ItemMySet"):call("applyItemMySet", loadoutIndex)

    -- get_DangoMySet, snow.facility.DangoMySet
end

local function GetItemLoadoutName(loadoutIndex)
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    return GetItemLoadout(loadoutIndex):call("get_Name")
end

----------- Equipment Loadout Managementt ----
local PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager")

local function GetCurrentWeaponType()
    if PlayerManager == nil then PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager") end
    if PlayerManager == nil then return end
    local MasterPlayer = PlayerManager:call("findMasterPlayer")
    if MasterPlayer == nil then return end

    local weaponType = MasterPlayer:get_field("_playerWeaponType")
    return weaponType
end

local EquipDataManager = sdk.get_managed_singleton("snow.data.EquipDataManager")

local function GetEquipmentLoadout(loadoutIndex)
    if EquipDataManager == nil then EquipDataManager = sdk.get_managed_singleton("snow.data.EquipDataManager") end
    local data = EquipDataManager:call("get_PlEquipMySetList"):call("get_Item", loadoutIndex) -- snow.equip.PlEquipMySetData
    return data
end

local function GetEquipmentLoadoutWeaponType(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("getWeaponData"):call("get_PlWeaponType")
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

local LocalizedStrings = {
    ["en-US"] = {
        WeaponNames = {
            [0] = "Great Sword",
            [1] = "Swtich Axe",
            [2] = "Long Sword",
            [3] = "Light Bowgun",
            [4] = "Heavy Bowgun",
            [5] = "Hammer",
            [6] = "Gunlance",
            [7] = "Lance",
            [8] = "Sword & Shield",
            [9] = "Dual Blades",
            [10] = "Hunting Horn",
            [11] = "Charge Blade",
            [12] = "Insect Glaive",
            [13] = "Bow",
        },
        UseDefaultItemSet = "Use Default Setting",
        WeaponTypeNotSetUseDefault = "%s not set, use default setting %s",
        UseWeaponTypeItemSet = "Use %s setting: %s",

        FromLoadout = "Restock for equipment loadout [<COL YEL>%s</COL>] from item loadout [<COL YEL>%s</COL>]",
        MismatchLoadout = "Current equipment doesn't match any equipment loadout.\n",
        FromWeaponType = "Restock for weapon type [<COL YEL>%s</COL>] from item loadout [<COL YEL>%s</COL>].",
        MismatchWeaponType = "Current equipment doesn't match any equipment loadout, and weapon type [<COL YEL>%s</COL>] has no settings.\n",
        FromDefault = "Restock from default item loadout [<COL YEL>%s</COL>].",
        OutOfStock = "Restock [<COL YEL>%s</COL>] cancelled due to <COL RED>out of stock</COL>.",

        PaletteNilError = "<COL RED>ERROR</COL>: Radial set is nil.",
        PaletteApplied = "Radial set [<COL YEL>%s</COL>] applied.",
        PaletteListEmpty = "Radial set list is empty, skipped.",
    },
    ["zh-CN"] = {
        WeaponNames = {
            [0] = "大剑",
            [1] = "斩斧",
            [2] = "太刀",
            [3] = "轻弩",
            [4] = "重弩",
            [5] = "大锤",
            [6] = "铳枪",
            [7] = "长枪",
            [8] = "片手",
            [9] = "双刀",
            [10] = "笛子",
            [11] = "盾斧",
            [12] = "操虫棍",
            [13] = "弓",
        },
        UseDefaultItemSet = "使用默认设置",
        WeaponTypeNotSetUseDefault = "%s无设定，使用默认设置：%s",
        UseWeaponTypeItemSet = "使用%s设置：%s",

        FromLoadout = "已从个人组合[<COL YEL>%s</COL>]指定的[<COL YEL>%s</COL>]补充道具。",
        MismatchLoadout = "当前装备不匹配个人组合。\n",
        FromWeaponType = "已从武器类型[<COL YEL>%s</COL>]指定的[<COL YEL>%s</COL>]补充道具。",
        MismatchWeaponType = "当前装备不匹配个人组合，且武器类型[<COL YEL>%s</COL>]没有指定设置。\n",
        FromDefault = "已从默认设置[<COL YEL>%s</COL>]补充道具。",
        OutOfStock = "因<COL RED>库存不足</COL>,从[<COL YEL>%s</COL>]补充道具取消。",

        PaletteNilError = "<COL RED>发生了错误</COL>：轮盘组合为空。",
        PaletteApplied = "使用了轮盘组合[<COL YEL>%s</COL>]。",
        PaletteListEmpty = "没有轮盘组合，不应用。",
    }
}

local function Localized()
    return LocalizedStrings[settings.data.language]
end

local function GetWeaponName(weaponType)
    if weaponType == nil then return "<ERROR>:GetWeaponName failed" end
    return Localized().WeaponNames[weaponType]
end

local function UseDefaultItemSet()
    return Localized().UseDefaultItemSet
end

local function WeaponTypeNotSetUseDefault(weaponName, itemName)
    return string.format(Localized().WeaponTypeNotSetUseDefault, weaponName, itemName)
end

local function UseWeaponTypeItemSet(weaponName, itemName)
    return string.format(Localized().UseWeaponTypeItemSet, weaponName, itemName)
end

local function FromLoadout(equipName, itemName)
    return string.format(Localized().FromLoadout, equipName, itemName)
end

local function FromWeaponType(equipName, itemName, mismatch)
    local msg = ""
    if mismatch then
        msg = Localized().MismatchLoadout
    end
    return msg .. string.format(Localized().FromWeaponType, equipName, itemName)
end

local function FromDefault(itemName, mismatch)
    local msg = ""
    if mismatch then
        msg = string.format(Localized().MismatchWeaponType, GetWeaponName(GetCurrentWeaponType()))
    end
    return msg .. string.format(Localized().FromDefault, itemName)
end

local function OutOfStock(itemName)
    return string.format(Localized().FromDefault, itemName)
end

local function PaletteNilError()
    return Localized().PaletteNilError
end

local function PaletteApplied(paletteName)
    return string.format(Localized().PaletteApplied, paletteName)
end

local function PaletteListEmpty()
    return Localized().PaletteListEmpty
end

local function EquipmentChanged()
    return "Equipment changed since last apply equipment loadout."
end

---------------      CORE      ----------------
-- Get Quest State [ 0 = Lobby, 1 = Ready/Loading, 2 = Quest, 3 = End, 5 = Abandoned, 7 = Returned ]
local function getQuestStatus()
    local questManager = sdk.get_managed_singleton("snow.QuestManager")
    if not questManager then return end
    return questManager:get_field("_QuestStatus")
end

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
            return WeaponTypeNotSetUseDefault(GetWeaponName(weaponType), GetItemLoadoutName(settings.data.default))
        end

        return UseWeaponTypeItemSet(GetWeaponName(weaponType), GetItemLoadoutName(got))
    end
    return GetItemLoadoutName(got)
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
            return got, "Loadout", GetEquipmentLoadoutName(loadoutIndex)
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
                    return got, "Loadout", GetEquipmentLoadoutName(cachedLoadoutIndex)
                end
            else
                -- SendMessage(EquipmentChanged())
            end
        end

        if not cacheHit then
            -- SendMessage("searching Loadout")
            local found = false
            for i = 1, 112, 1 do
                loadoutIndex = i - 1
                if EquipmentLoadoutIsEquipped(loadoutIndex) then
                    found = true
                    lastHitLoadout = i
                    local got = settings.data.loadoutConfig[i]
                    if (got ~= nil) and (got ~= -1) then
                        return got, "Loadout", GetEquipmentLoadoutName(loadoutIndex)
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
        weaponType = GetCurrentWeaponType()
    end
    local got = settings.data.weaponConfig[weaponType+1]
    if (got ~= nil) and (got ~= -1) then
        return got, "WeaponType", GetWeaponName(weaponType), loadoutMismatch
    end

    return settings.data.default, "Default", "", loadoutMismatch
end

------------------------

local function Restock(loadoutIndex)
    if settings.data.enable == false then return end

    local itemLoadoutIndex, matchedType, matchedName, loadoutMismatch = AutoChooseItemLoadout(loadoutIndex)
    local loadout = GetItemLoadout(itemLoadoutIndex)
    local itemLoadoutName = loadout:call("get_Name")

    local returnFlag = false

    returnFlag = timedRestock and
        restockTimeTreshold > info.time - restockTime and
        lastRestock == itemLoadoutName

    returnFlag = returnFlag or (
        not timedRestock and
        lastRestock == itemLoadoutName
    )

    restockTime = info.time
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
            local paletteList = ShortcutManager:call("getPaletteSetList", 0) -- 0 is Quest
            if paletteList then
                local palette = paletteList:call("get_Item", radialSetIndex)
                if palette then
                    msg = msg .. "\n" .. PaletteApplied(palette:call("get_Name"))
                end
            else
                msg = msg .. "\n" .. PaletteListEmpty()
            end
            ShortcutManager:call("setUsingPaletteIndex", 0, radialSetIndex)
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
	info = require "RiseEnhanced.misc.info"
	modUtils = require "RiseEnhanced.utils.mod_utils"
    restockTimeTreshold = 60 * 30
    restockTime = 0

	local weaponDefault = {}
	for i = 1, 14, 1 do
		if weaponDefault[i] == nil then
			weaponDefault[i] = -1
		end
	end
	local loadoutDefault = {}
	for i = 1, 112, 1 do
		if loadoutDefault[i] == nil then
			loadoutDefault[i] = -1
		end
	end

	lastRestock = nil
    timedRestock = false

	settings = modUtils.getConfigHandler({
		enable = true,
		notification = true,
		default = 1,
		language = "en-US",
		weaponConfig = weaponDefault,
		loadoutConfig = loadoutDefault,
	}, info.modName .. "/" .. module.name)

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
        if getQuestStatus() == 2 and settings.data.enable and not timedRestock then
            timedRestock = true
            restockTime = info.time
        elseif getQuestStatus() ~= 2 and timedRestock then
            timedRestock = false
        end
    end)

    -- Reset lastRestock then dying
    sdk.hook(sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"), resetRestock)

    -- Reset lastRestock when killing a monster
    sdk.hook(sdk.find_type_definition("snow.enemy.EnemyCharacterBase"):get_method("questEnemyDie"), resetRestock)

    -- Reset lastRestock when returning to village
	sdk.hook(
	    sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"), resetRestock)

	re.on_frame(function()
		if ChatManager == nil then ChatManager = sdk.get_managed_singleton("snow.gui.ChatManager") end
		if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
		if EquipDataManager == nil then EquipDataManager = sdk.get_managed_singleton("snow.data.EquipDataManager") end
		if ShortcutManager == nil then ShortcutManager = sdk.get_managed_singleton("snow.data.CustomShortcutSystem") end
		if PlayerManager == nil then PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager") end

		if SystemDataManager == nil then SystemDataManager = sdk.get_managed_singleton("snow.data.SystemDataManager") end
		if ShortcutManager == nil and SystemDataManager ~= nil then
			ShortcutManager = SystemDataManager:call("getCustomShortcutSystem")
		end
	end)
end

function module.draw()
	if imgui.tree_node(module.name) then
		if ChatManager ~= nil and DataManager ~= nil and EquipDataManager ~= nil then
			settings.imgui("enable", imgui.checkbox, "Enabled")
			settings.imgui("notification", imgui.checkbox, "Enable Notification")

			local change
			local langIdx = FindIndex(Languages, settings.data.language)
            change, langIdx = imgui.combo("Language", langIdx, Languages)
			settings.handleChange(change, Languages[langIdx], "language")

			settings.imgui("default", imgui.slider_int, "Default Item Set", 0, 39,
			GetItemLoadoutName(settings.data.default))

            if imgui.tree_node("Weapon Type") then
                for i = 1, 14, 1 do
                    local weaponType = i - 1
					settings.imguit("weaponConfig", i, imgui.slider_int, GetWeaponName(weaponType), -1, 39, GetWeaponTypeItemLoadoutName(weaponType))
                end
                imgui.tree_pop()
            end

            if imgui.tree_node("Equipment Loadout") then
                for i = 1, 112, 1 do
                    local loadoutIndex = i - 1
                    local name = GetEquipmentLoadoutName(loadoutIndex)
                    local isUsing = EquipmentLoadoutIsNotEmpty(loadoutIndex)
                    if name and isUsing then
                        local same = EquipmentLoadoutIsEquipped(loadoutIndex)
                        local msg = ""
                        if same then msg = " (Current)" end
						settings.imguit("loadoutConfig", i, imgui.slider_int, name .. msg, -1, 39, GetLoadoutItemLoadoutIndex(loadoutIndex))
                    end
                end
                imgui.tree_pop();
            end
        else
            imgui.text("Loading...")
        end
		imgui.tree_pop()
	end
end

return module