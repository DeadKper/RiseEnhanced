-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Weakness", {
        enabled = true,
        onItembox = true,
        highlightExploit = true,
        highlightHighest = false,
    }
)

local weaknessSheet = {
    physical = {
        "sever",
        "blunt",
        "shell",
    },
    elemental = {
        "fire",
        "water",
        "ice",
        "thunder",
        "dragon",
    },
    exploit = {
        physical = 45,
        elembane = 25,
        elemental = 20,
    },
    types = {
        "sever",
        "blunt",
        "shell",
        "fire",
        "water",
        "ice",
        "thunder",
        "dragon",
    }
}

local hitZoneValues = nil
local questMonsterList = nil

local tableFlag = 2097152 -- 1 << 21
local columnFlag = 8 -- 1 << 3

-- Main code

local function makeHZVTable()
    if hitZoneValues ~= nil then
        return
    end
    local guiManager = utils.singleton("snow.gui.GuiManager")
    local monsterList = guiManager:call("get_refMonsterList")
    local monsterDataList = monsterList:get_field("_MonsterBossData"):get_field("_DataList")
    local getPartName = utils.definition("via.gui.message", "get(System.Guid, via.Language)")
    local getMonsterName = utils.definition("snow.gui.MessageManager",
            "getEnemyNameMessage(snow.enemy.EnemyDef.EmTypes)")
    hitZoneValues = {}
    local length = monsterDataList:call("get_Count") - 1
    for i = 0, length do
        local monster = monsterDataList:call("get_Item", i)
        local monsterId = monster:get_field("_EmType")
        local meatData = guiManager:call("getEnemyMeatData(snow.enemy.EnemyDef.EmTypes)", monsterId)
        local partDataList = monster:get_field("_PartTableData")
        local monsterTable = {
            name = getMonsterName(nil, monsterId),
            -- type = monsterId,
            parts = {}
        }

        local partLength = partDataList:call("get_Count") - 1
        for j = 0, partLength do
            local part = partDataList:call("get_Item", j)
            local partType = part:get_field("_Part")
            local partGUID = monsterList:call("getMonsterPartName(snow.data.monsterList.PartType)",
                    partType)
            local meatType = part:get_field("_EmPart")
            local partList = {
                name = getPartName(nil, partGUID, 1),
                -- type = partType,
                -- meat = meatType,
                hzv = {}
            }
            for k = 1, #weaknessSheet.types do
                partList.hzv[weaknessSheet.types[k]] = meatData:call("getMeatValue", meatType, 0, k - 1)
            end
            table.insert(monsterTable.parts, partList)
        end

        hitZoneValues[monsterId] = monsterTable
    end
end

local function updateMonsterList()
    local questManager = utils.singleton("snow.QuestManager")
    local targets = questManager:get_field("_QuestTargetEmTypeList")
    local targetCount = targets:call("get_Count") - 1
    if targetCount < 0 then
        local questData = questManager:get_field("_ActiveQuestData")
        if questData ~= nil then
            targets = questData:call("getTargetEmTypeList(System.Boolean)", true)
            targetCount = targets:call("get_Count") - 1
        end
    end
    if targetCount < 0 then
        questMonsterList = nil
        return
    end
    questMonsterList = {}
    for i = 0, targetCount do
        local target = targets:call("get_Item", i)
        if not utils.contains(questMonsterList, target) then
            table.insert(questMonsterList, target)
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()
    sdk.hook(utils.definition("snow.QuestManager", "questActivate(snow.LobbyManager.QuestIdentifier)"),
        utils.original,
        function (retval)
            makeHZVTable()
            updateMonsterList()
            return retval
        end
    )

    re.on_frame(function ()
        if not module.enabled() or questMonsterList == nil then return end
        local questManager = utils.singleton("snow.QuestManager")
        local questData = questManager:get_field("_ActiveQuestData")
        if questManager:get_field("_QuestStatus") ~= 0 or questData == nil then
            questMonsterList = nil
            return
        end

        if settings.get("onItembox")
                and utils.singleton("snow.gui.fsm.itembox.GuiItemBoxFsmManager") == nil then
            return
        end

        if imgui.begin_window(data.lang.Weakness.name, true, 4096 + 64) then
            for i = 1, #questMonsterList do
                local target = hitZoneValues[questMonsterList[i]]

                if imgui.begin_table("Hitzones", 10, tableFlag, 25) then

                    imgui.table_setup_column(target.name, columnFlag, 125)
                    for j = 1, #data.lang.Weakness.damageTypeShort do
                        imgui.table_setup_column(data.lang.Weakness.damageTypeShort[j], columnFlag, 25)
                    end
                    imgui.table_headers_row()

                    for j = 1, #target.parts do
                        local part = target.parts[j]
                        local highest = {
                            physical = math.max(table.unpack(
                                utils.filter(part.hzv, weaknessSheet.physical))),
                            elemental = math.max(table.unpack(
                                utils.filter(part.hzv, weaknessSheet.elemental))),
                        }

                        local highligth = {
                            physical = 1000,
                            elemental = 1000,
                        }
                        local exploit = settings.get("highlightExploit")

                        if exploit then
                            highligth.physical = weaknessSheet.exploit.physical
                            highligth.elemental = weaknessSheet.exploit.elemental
                        end

                        if settings.get("highlightHighest") then
                            if exploit then
                                highligth.physical =
                                        math.min(highest.physical, weaknessSheet.exploit.physical)
                                highligth.elemental =
                                        math.min(highest.elemental, weaknessSheet.exploit.elemental)
                            else
                                highligth.physical = highest.physical
                                highligth.elemental = highest.elemental
                            end
                        end

                        imgui.table_next_row()
                        imgui.table_next_column()
                        imgui.text(part.name)

                        for k = 1, #weaknessSheet.types do
                            imgui.table_next_column()
                            local zoneType = weaknessSheet.types[k]
                            local highlightZone = highligth.elemental
                            if utils.contains(weaknessSheet.physical, zoneType) then
                                highlightZone = highligth.physical
                            end

                            local zoneValue = part.hzv[zoneType]

                            if zoneValue >= highlightZone then
                                imgui.button(zoneValue)
                            else
                                imgui.text(zoneValue)
                            end
                        end
                    end
                    imgui.end_table()
                end
                if i < #questMonsterList then imgui.spacing() end
            end
        end
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    local questManager = utils.singleton("snow.QuestManager")
    if questManager == nil
            or questManager:get_field("_QuestStatus") ~= 0
            or questManager:get_field("_ActiveQuestData") == nil then
        return
    end
    makeHZVTable()
    updateMonsterList()
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("onItembox", imgui.checkbox, data.lang.Weakness.onItembox)
    settings.call("highlightExploit", imgui.checkbox, data.lang.Weakness.highlightExploit)
    settings.call("highlightHighest", imgui.checkbox, data.lang.Weakness.highlightHighest)
end

return module