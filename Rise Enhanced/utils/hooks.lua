local utils = require("Rise Enhanced.utils.utils")

local data = utils.getData()

data.enemy = {}
data.quest = {
    active = false,
    isRampage = false,
    largeMonsterList = {},
}

data.damage = {
    types = {
        "sever",
        "blunt",
        "shell",
        "fire",
        "water",
        "ice",
        "thunder",
        "dragon",
    },
}

local function makeHZVTable()
    if data.enemy.hzv ~= nil then
        return
    end

    local guiManager = utils.singleton("snow.gui.GuiManager")
    local monsterList = guiManager:call("get_refMonsterList")
    local monsterDataList = monsterList:get_field("_MonsterBossData"):get_field("_DataList")
    local getPartName = utils.definition("via.gui.message", "get(System.Guid, via.Language)")
    local getMonsterName = utils.definition("snow.gui.MessageManager",
            "getEnemyNameMessage(snow.enemy.EnemyDef.EmTypes)")
    local length = monsterDataList:call("get_Count") - 1

    data.enemy.hzv = {}

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
            for k = 1, #data.damage.types do
                partList.hzv[data.damage.types[k]] = meatData:call("getMeatValue", meatType, 0, k - 1)
            end
            table.insert(monsterTable.parts, partList)
        end

        data.enemy.hzv[monsterId] = monsterTable
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
        return
    end
    for i = 0, targetCount do
        local target = targets:call("get_Item", i)
        if not utils.contains(data.quest.largeMonsterList, target)
                and data.enemy.hzv[target] ~= nil then
            table.insert(data.quest.largeMonsterList, target)
        end
    end
end

local function updateActiveQuest()
    data.quest.active = true
    data.quest.isRampage = utils.singleton("snow.QuestManager", "getHyakuryuCategory") ~= 2
    updateMonsterList()
end

local function clearActiveQuest()
    data.quest.active = false
    data.quest.isRampage = false
    for k in pairs(data.quest.largeMonsterList) do
        data.quest.largeMonsterList[k] = nil
    end
end

utils.hook({"snow.QuestManager", "questActivate(snow.LobbyManager.QuestIdentifier)"}, nil, updateActiveQuest)

utils.hook({"snow.QuestManager", "questCancel"}, clearActiveQuest)

utils.hook({"snow.QuestManager", "onQuestEnd"}, clearActiveQuest)

-- init data

local function init(retval)
    data.loaded = true
    makeHZVTable()
    if utils.singleton("snow.QuestManager"):get_field("_ActiveQuestData") then
        updateActiveQuest()
    end
    return retval
end

-- init when already loaded (for script reset)
if utils.singleton("snow.player.PlayerManager") ~= nil then init() end

utils.hook({"snow.data.DataManager", "onLoad(snow.SaveDataBase)"}, nil, init)

utils.hook({"snow.VillageState", "onEnterTitleFromVillage"}, function () data.loaded = false end)