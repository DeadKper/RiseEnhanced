-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Tweaks", {
        enabled = true,
        noHitStop = true,
        saveDelay = 5,
        useMultipliers = true,
        useSmartMultipliers = true,
        multipliers = utils.filledTable(#data.lang.Tweaks.multipliers, 5),
        smartMultipliers = {
            500000,
            5000,
            100,
            100,
            220,
        }
    }
)

local lastSave = 0

-- Main code

-- Hooks
-- set saved clock
sdk.hook(sdk.find_type_definition("snow.SnowSaveService"):get_method("saveCharaData"),
    function(args)
        lastSave = os.clock()
    end
)

-- set saved clock on village return
sdk.hook(sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
    function (args)
        lastSave = os.clock()
    end
)

-- skip autosave
sdk.hook(sdk.find_type_definition("snow.SnowSaveService"):get_method("requestAutoSaveAll"),
    function(args)
        if module.enabled() and os.clock() < lastSave + settings.get("saveDelay") * 60 then
            return sdk.PreHookResult.SKIP_ORIGINAL
        end
    end
)

-- remove hit stop
sdk.hook(sdk.find_type_definition("snow.player.PlayerQuestBase"):get_method("updateHitStop"),
    function(args)
        if module.enabled("noHitStop") then
            sdk.to_managed_object(args[2]):call("resetHitStop")
        end
    end
)

sdk.hook(sdk.find_type_definition("snow.QuestManager"):get_method("onQuestEnd"),
    function (args)
        if not module.enabled("useMultipliers") then return end
        local multipliers = settings.get("multipliers")
        local questManager = sdk.get_managed_singleton("snow.QuestManager")
        local useSmart = settings.get("useSmartMultipliers")

        if useSmart then
            local ammount
            local dataManager = sdk.get_managed_singleton("snow.data.DataManager")
            local progressManager = sdk.get_managed_singleton("snow.progress.ProgressManager")
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
    end
)

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    lastSave = os.clock()
end

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()

    settings.call("noHitStop", imgui.checkbox, data.lang.Tweaks.noHitStop)
    settings.slider("saveDelay",
        data.lang.Tweaks.saveDelay,
        0,
        30,
        utils.durationText(
            settings.get("saveDelay"),
            data.lang.minuteText,
            data.lang.minutesText,
            data.lang.disabled
        )
    )
    settings.call("useMultipliers", imgui.checkbox, data.lang.Tweaks.useMultipliers)
    settings.call("useSmartMultipliers", imgui.checkbox, data.lang.Tweaks.useSmartMultipliers)
    if imgui.tree_node(data.lang.Tweaks.configureMultipliers) then
        for i, text in pairs(data.lang.Tweaks.multipliers) do
            settings.slider({ "multipliers", i }, text, 0, 5, nil, 0.1)
        end
        imgui.tree_pop()
    end
    if imgui.tree_node(data.lang.Tweaks.configureSmartThresh) then
        local table = {"smartMultipliers", 1}
        settings.slider(
                table,
                data.lang.Tweaks.multipliers[1],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), data.lang.always),
                10000
        )
        table = {"smartMultipliers", 2}
        settings.slider(
                table,
                data.lang.Tweaks.multipliers[2],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), data.lang.always),
                100
        )
        table = {"smartMultipliers", 3}
        settings.slider(
                table,
                data.lang.Tweaks.multipliers[3],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), data.lang.always)
        )
        table = {"smartMultipliers", 4}
        settings.slider(
                table,
                data.lang.Tweaks.multipliers[4],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), data.lang.always)
        )
        table = {"smartMultipliers", 5}
        settings.slider(
                table,
                data.lang.Tweaks.multipliers[5],
                0,
                settings.getDefault(table),
                utils.formatNumber(settings.get(table), data.lang.always),
                20
        )
        imgui.tree_pop()
    end
end

return module