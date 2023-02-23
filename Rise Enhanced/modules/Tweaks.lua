-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")
local data = utils.getData()

-- Init module
local module, settings = mod.getDefaultModule(
    "Tweaks", {
        enabled = true,
        wirebugStart = true,
        wirebugRefresh = true,
        noHitStop = true,
        saveDelay = 5,
        useMultipliers = true,
        useSmartMultipliers = true,
        multipliers = utils.filledTable(#mod.lang.Tweaks.multipliers, 5),
        smartMultipliers = {
            500000,
            5000,
            100,
            160,
            220,
        },
    }
)

local baseWireBugTime = 90
local whispererBoost = 1.3
local extraWireBugTime = 30
local getWireBug = false
local lastSave = 0

-- Main code

---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    lastSave = os.clock()

    utils.setReference("_WireBugPowerUpTime", function ()
        return baseWireBugTime
    end)

    -- add wirebug
    utils.hook({"snow.player.PlayerManager", "update"}, function()
        if not module.enabled() or not getWireBug then return end
        local player = utils.getPlayer()
        if not player then return end
        getWireBug = false

        local timeMult = 1
        if utils.playerSkillLevel(104) > 0 then
            timeMult = whispererBoost
        end

        local time = (utils.reference("_WireBugPowerUpTime") + extraWireBugTime) * 60 * timeMult

        player:set_field("<HunterWireWildNum>k__BackingField", 1)
        player:set_field("_HunterWireNumAddTime", time)
    end)

    -- set saved clock
    utils.hook({"snow.SnowSaveService", "saveCharaData"}, function()
        lastSave = os.clock()
    end)

    -- set saved clock on village return
    utils.hook({"snow.gui.GuiManager", "notifyReturnInVillage"}, function ()
        lastSave = os.clock()
    end)

    -- skip autosave
    utils.hook({"snow.SnowSaveService", "requestAutoSaveAll"}, function()
        if module.enabled() and os.clock() < lastSave + settings.get("saveDelay") * 60 then
            return sdk.PreHookResult.SKIP_ORIGINAL
        end
    end)

    -- remove hit stop
    utils.hook({"snow.player.PlayerQuestBase", "updateHitStop"}, function(args)
        if module.enabled("noHitStop") then
            sdk.to_managed_object(args[2]):call("resetHitStop")
        end
    end)

    utils.hookTimer({"snow.QuestManager", "questStart"}, function()
        if not module.enabled("wirebugStart") then return end
        getWireBug = true
    end, 3)

    local isLargeMonster = utils.definition("snow.enemy.EnemyCharacterBase", "get_isBossEnemy")
    utils.hook({"snow.enemy.EnemyCharacterBase", "questEnemyDie"}, function (args)
        utils.timer(function ()
            if not module.enabled("wirebugRefresh")
                    or data.quest.isRampage
                    or not settings.get("largeMonsterRestock")
                    or not utils.playingQuest()
                    or not isLargeMonster(sdk.to_managed_object(args[2])) then
                return
            end

            getWireBug = true
        end, 5)
    end)

    utils.hookTimer({"snow.QuestManager", "notifyDeath"}, function()
        if not module.enabled("wirebugStart") then return end

        getWireBug = true
    end, 5)

    utils.hook({"snow.QuestManager", "onQuestEnd"}, nil, function (retval)
        if not module.enabled("useMultipliers") then return retval end
        local multipliers = settings.get("multipliers")
        local questManager = utils.singleton("snow.QuestManager")
        local useSmart = settings.get("useSmartMultipliers")

        if useSmart then
            local ammount
            local dataManager = utils.singleton("snow.data.DataManager")
            local progressManager = utils.singleton("snow.progress.ProgressManager")
            local threshold = settings.get({"smartMultipliers", 1})
            if threshold == 0 or threshold > dataManager:call("getHandMoney"):get_field("_Value") then
                local questLife = questManager:call("getQuestLife")
                ammount = questManager:call("getRemMoney") * multipliers[1]
                questManager:set_field("_StartRemMoney", ammount)
                questManager:set_field("_PenaltyMoney", ammount / questLife)
                questManager:set_field("_RemMoney", ammount)
            end
            threshold = settings.get({"smartMultipliers", 2})
            if threshold == 0 or threshold > dataManager:call("getVillagePoint"):call("get_Point") then
                ammount = questManager:call("getRemVillagePoint") * multipliers[2]
                questManager:set_field("_RemVillagePoint", ammount)
            end
            threshold = settings.get({"smartMultipliers", 3})
            if threshold == 0 or threshold > progressManager:call("get_HunterRank") then
                ammount = questManager:call("getRemRankPointAfterCalculation") * multipliers[3]
                questManager:set_field("_RemRankPoint", ammount)
            end
            threshold = settings.get({"smartMultipliers", 4})
            if threshold == 0 or threshold > progressManager:call("get_MasterRank") then
                ammount = questManager:call("getRemMasterRankPointAfterCalculation") * multipliers[4]
                questManager:set_field("_RemMasterRankPoint", ammount)
            end
            threshold = settings.get({"smartMultipliers", 5})
            if threshold == 0 or threshold > progressManager:call("get_MysteryResearchLevel") then
                ammount =
                        questManager:call("getRemMysteryResearchPointAfterCalculation") * multipliers[5]
                questManager:set_field("_RemMysteryResearchPoint", ammount / 1.1)
            end
        else
            local life = questManager:call("getQuestLife")
            local money = questManager:call("getRemMoney") * multipliers[1]
            local points = questManager:call("getRemVillagePoint") * multipliers[2]
            local hr = questManager:call("getRemRankPointAfterCalculation") * multipliers[3]
            local mr = questManager:call("getRemMasterRankPointAfterCalculation") * multipliers[4]
            local anomaly =
                    questManager:call("getRemMysteryResearchPointAfterCalculation") * multipliers[5]
            questManager:set_field("_StartRemMoney", money)
            questManager:set_field("_PenaltyMoney", money / life)
            questManager:set_field("_RemMoney", money)
            questManager:set_field("_RemVillagePoint", points)
            questManager:set_field("_RemRankPoint", hr)
            questManager:set_field("_RemMasterRankPoint", mr)
            questManager:set_field("_RemMysteryResearchPoint", anomaly / 1.1)
        end
        return retval
    end)
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("wirebugStart", imgui.checkbox, mod.lang.Tweaks.wirebugStart)
    settings.call("wirebugRefresh", imgui.checkbox, mod.lang.Tweaks.wirebugRefresh)
    settings.call("noHitStop", imgui.checkbox, mod.lang.Tweaks.noHitStop)
    settings.slider("saveDelay",
        mod.lang.Tweaks.saveDelay,
        0,
        30,
        utils.durationText(
            settings.get("saveDelay"),
            mod.lang.minuteText,
            mod.lang.minutesText,
            mod.lang.disabled
        )
    )
    settings.call("useMultipliers", imgui.checkbox, mod.lang.Tweaks.useMultipliers)
    settings.call("useSmartMultipliers", imgui.checkbox, mod.lang.Tweaks.useSmartMultipliers)
    if imgui.tree_node(mod.lang.Tweaks.configureMultipliers) then
        for i, text in pairs(mod.lang.Tweaks.multipliers) do
            settings.slider({ "multipliers", i }, text, 0, 5, nil, 0.1)
        end
        imgui.tree_pop()
    end
    if imgui.tree_node(mod.lang.Tweaks.configureSmartThresh) then
        local table = {"smartMultipliers", 1}
        settings.slider(
                table,
                mod.lang.Tweaks.multipliers[1],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), mod.lang.always),
                10000
        )
        table = {"smartMultipliers", 2}
        settings.slider(
                table,
                mod.lang.Tweaks.multipliers[2],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), mod.lang.always),
                100
        )
        table = {"smartMultipliers", 3}
        settings.slider(
                table,
                mod.lang.Tweaks.multipliers[3],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), mod.lang.always)
        )
        table = {"smartMultipliers", 4}
        settings.slider(
                table,
                mod.lang.Tweaks.multipliers[4],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), mod.lang.always)
        )
        table = {"smartMultipliers", 5}
        settings.slider(
                table,
                mod.lang.Tweaks.multipliers[5],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), mod.lang.always),
                20
        )
        imgui.tree_pop()
    end
end

return module