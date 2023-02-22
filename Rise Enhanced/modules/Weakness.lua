-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Weakness", {
        enabled = true,
        onItembox = true,
        onCamp = true,
        useElembane = false,
        highlightExploitPhys = true,
        highlightExploitElem = false,
        highlightHighestPhys = false,
        highlightHighestElem = true,
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
    local monsterTable = {}
    for i = 0, targetCount do
        local target = targets:call("get_Item", i)
        if not utils.contains(monsterTable, target) and hitZoneValues[target] ~= nil then
            table.insert(monsterTable, target)
        end
    end
    if #monsterTable > 0 then
        questMonsterList = monsterTable
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
        local questStatus = questManager:get_field("_QuestStatus")
        if questStatus ~= 0 or questStatus ~= 2 then
            return
        end
        local questData = questManager:get_field("_ActiveQuestData")
        if questData == nil then
            questMonsterList = nil
            return
        end

        if not (settings.get("onItembox")
                and utils.singleton("snow.gui.fsm.itembox.GuiItemBoxFsmManager"))
            and (not (settings.get("onCamp")
                and utils.singleton("snow.gui.fsm.camp.GuiCampFsmManager"))) then
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

                        local physExploit = settings.get("highlightExploitPhys")
                        local elemExploit = settings.get("highlightExploitElem")

                        if physExploit then
                            highligth.physical = weaknessSheet.exploit.physical
                        end
                        if elemExploit then
                            if settings.get("useElembane") then
                                highligth.elemental = weaknessSheet.exploit.elembane
                            else
                                highligth.elemental = weaknessSheet.exploit.elemental
                            end

                        end

                        if settings.get("highlightHighestPhys") then
                            if physExploit then
                                highligth.physical = math.min(highest.physical, highligth.physical)
                            else
                                highligth.physical = highest.physical
                            end
                        end

                        if settings.get("highlightHighestElem") then
                            if elemExploit then
                                highligth.elemental = math.min(highest.elemental, highligth.elemental)
                            else
                                highligth.elemental = highest.elemental
                            end
                        end

                        imgui.table_next_row()
                        imgui.table_next_column()
                        imgui.text(part.name)

                        for k = 1, #weaknessSheet.types do
                            imgui.table_next_column()
                            local zoneType = weaknessSheet.types[k]
                            local highlightZone
                            if utils.contains(weaknessSheet.physical, zoneType) then
                                highlightZone = highligth.physical
                            else
                                highlightZone = highligth.elemental
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
    if questManager == nil or questManager:get_field("_ActiveQuestData") == nil then
        return
    end
    makeHZVTable()
    updateMonsterList()
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("onItembox", imgui.checkbox, data.lang.Weakness.onItembox)
    settings.call("onCamp", imgui.checkbox, data.lang.Weakness.onCamp)
    settings.call("useElembane", imgui.checkbox, data.lang.Weakness.useElembane)
    settings.call("highlightExploitPhys", imgui.checkbox, data.lang.Weakness.highlightExploitPhys)
    settings.call("highlightExploitElem", imgui.checkbox, data.lang.Weakness.highlightExploitElem)
    settings.call("highlightHighestPhys", imgui.checkbox, data.lang.Weakness.highlightHighestPhys)
    settings.call("highlightHighestElem", imgui.checkbox, data.lang.Weakness.highlightHighestElem)
end

return module