-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")
local data = utils.getData()

-- Init module
local module, settings = mod.getDefaultModule(
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
    types = data.damage.types,
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
}

local tableFlag = 2097152 -- 1 << 21
local columnFlag = 8 -- 1 << 3

local function display()
    if not module.enabled() then return end
    local questStatus = utils.getQuestStatus()

    if questStatus == 0 then
        if settings.get("onItembox")
                and not utils.singleton("snow.gui.fsm.itembox.GuiItemBoxFsmManager") then
            return
        end
    elseif questStatus == 2 then
        if not settings.get("onCamp")
                or not utils.singleton("snow.gui.fsm.camp.GuiCampFsmManager") then
            return
        end
    else
        return
    end

    if imgui.begin_window(mod.lang.Weakness.name, true, 4096 + 64) then
        for i = 1, #data.quest.largeMonsterList do
            local target = data.enemy.hzv[data.quest.largeMonsterList[i]]

            if imgui.begin_table("Hitzones", 10, tableFlag, 25) then

                imgui.table_setup_column(target.name, columnFlag, 125)
                for j = 1, #mod.lang.Weakness.damageTypeShort do
                    imgui.table_setup_column(mod.lang.Weakness.damageTypeShort[j], columnFlag, 25)
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
            if i < #data.quest.largeMonsterList then imgui.spacing() end
        end
    end
end

local function condition()
    return next(data.quest.largeMonsterList) ~= nil
end

---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    utils.hookLoop({"snow.QuestManager", "questActivate(snow.LobbyManager.QuestIdentifier)"},
            display, nil, condition)
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("onItembox", imgui.checkbox, mod.lang.Weakness.onItembox)
    settings.call("onCamp", imgui.checkbox, mod.lang.Weakness.onCamp)
    settings.call("useElembane", imgui.checkbox, mod.lang.Weakness.useElembane)
    settings.call("highlightExploitPhys", imgui.checkbox, mod.lang.Weakness.highlightExploitPhys)
    settings.call("highlightExploitElem", imgui.checkbox, mod.lang.Weakness.highlightExploitElem)
    settings.call("highlightHighestPhys", imgui.checkbox, mod.lang.Weakness.highlightHighestPhys)
    settings.call("highlightHighestElem", imgui.checkbox, mod.lang.Weakness.highlightHighestElem)
end

return module