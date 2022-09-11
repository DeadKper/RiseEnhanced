local modName = "Skip Dango Song"
local folderName = modName
local version = "Version: 1.5.0"
local author = "Made by Raff"
local credits =
    "Credits to DSC-173(DSC173 on Nexus) for the code for\n telling which skills have activated!"
local credits2 =
    "Credits to LatencyKG on Nexus for figuring out\n how to display HP and Stamina dynamically\n and how to go straight to the end of the animation\n when not skipping eating!"

local modUtils = require(folderName .. "/mod_utils")

modUtils.info(modName .. " " .. version .. " loaded!")

local localizedMessages = {
    ["English"] = {
        hpStaminaMessage = "<COL>Status Increased!</COL>"
            .. "\n<COL RED>  Health                         HP</COL>"
            .. "\n<COL RED>  Stamina                      ST</COL>",
        dangoSkillMessage = "<COL>Dango Skills activated!</COL>"
    },
    ["German"] = {
        hpStaminaMessage = "<COL>Status verbessert!</COL>"
            .. "\n<COL RED>  Gesundheit                         HP</COL>"
            .. "\n<COL RED>  Ausdauer                            ST</COL>",
        dangoSkillMessage = "<COL>Dango-Fähigkeit aktiv!</COL>"
    },
    ["Simplified Chinese"] = {
        hpStaminaMessage = "<COL>状态提升!</COL>"
            .. "\n<COL RED>  体力                         HP</COL>"
            .. "\n<COL RED>  耐力                         ST</COL>",
        dangoSkillMessage = "<COL>发动团子技能!</COL>"
    },
    ["Traditional Chinese"] = {
        hpStaminaMessage = "<COL>狀態上升!</COL>"
            .. "\n<COL RED>  體力                         HP</COL>"
            .. "\n<COL RED>  耐力                         ST</COL>",
        dangoSkillMessage = "<COL>發動糰子技能!</COL>"
    },
    ["Korean"] = {
        hpStaminaMessage = "<COL>스테이터스 상승!</COL>"
            .. "\n<COL RED>  체력                         HP</COL>"
            .. "\n<COL RED>  스태미나                  ST</COL>",
        dangoSkillMessage = "<COL>경단 스킬 발동!</COL>"
    },
    ["Japanese"] = {
        hpStaminaMessage = "<COL>ステータスが上昇！</COL>"
            .. "\n<COL RED>  体力                             HP</COL>"
            .. "\n<COL RED>  スタミナ                      ST</COL>",
        dangoSkillMessage = "<COL>おだんごスキルが発動！</COL>"
    }
}

local languages = {}
local n = 0

for k, v in pairs(localizedMessages) do
    n = n + 1
    languages[n] = k
end
table.sort(languages)

local settings = modUtils.getConfigHandler({
    skipDangoSong = true,
    skipEating = true,
    skipMotley = true,
    language = 1
}, folderName)

local getCookDemoHandler = modUtils.getType(
    "snow.gui.fsm.kitchen.GuiKitchenFsmManager"):get_method(
    "get_KitchenCookDemoHandler");
local getEatDemoHandler = modUtils.getType(
    "snow.gui.fsm.kitchen.GuiKitchenFsmManager"):get_method(
    "get_KitchenEatDemoHandler");
local setCookDemoSkip = modUtils.getType(
    "snow.gui.fsm.kitchen.GuiKitchenFsmManager"):get_method("set_IsCookDemoSkip");
local getBBQDemoHandler = modUtils.getType("snow.gui.GuiKitchen_BBQ"):get_field(
    "_DemoHandler");
local reqFinish = modUtils.getType("snow.eventcut.EventcutHandler"):get_method(
    "reqFinish");
local getPlaying = modUtils.getType("snow.eventcut.EventcutHandler"):get_method(
    "get_Playing");
local getLoadState =
    modUtils.getType("snow.eventcut.EventcutHandler"):get_method("get_LoadState");

local function assertSafety(obj, objName)
    if obj:get_reference_count() == 1 then
        modUtils.info(objName .. " was disposed by the game, breaking")
        error("")
    end
end

local function getMealFunc()
    local kitchen =
        sdk.get_managed_singleton("snow.data.FacilityDataManager"):call(
            "get_Kitchen")
    if not kitchen then return nil end
    local mealFunc = kitchen:call("get_MealFunc")
    if not mealFunc then return nil end
    return mealFunc
end

local lastCookHandlerStopped;
local lastEatHandlerStopped;
local lastMotleyHandlerStopped;
local skippedCutsceneThisFrame;

local function printSkills()
    local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
    local player = sdk.get_managed_singleton("snow.player.PlayerManager"):call(
        "findMasterPlayer")
    local get_localized_skill_name = sdk.find_type_definition("snow.data.DataShortcut"):get_method("getName(snow.data.DataDef.PlKitchenSkillId)")

    local mealfunc = getMealFunc()
    local health_gained  = 50
    local stamina_gained = 50

    if mealfunc then
        local facility_level = mealfunc:get_FacilityLv()
        health_gained  = mealfunc:getVitalBuff(facility_level)
        stamina_gained = mealfunc:getStaminaBuff(facility_level)
    end

    local messages = localizedMessages[languages[settings.data.language]]

    local message = messages["dangoSkillMessage"];
    local playerSkillData = player:get_field("_refPlayerSkillList")
    playerSkillData = playerSkillData:call("get_KitchenSkillData")
    for i, v in pairs(playerSkillData:get_elements()) do
        if v:get_field("_SkillId") ~= 0 then
            message = message .. "\n<COL RED>  "
                          .. get_localized_skill_name(nil, v:get_field("_SkillId")) .. "</COL>"
        end
    end

    local hpStaminaMessage = messages["hpStaminaMessage"]
        :gsub("HP", tostring(health_gained))
        :gsub("ST", tostring(stamina_gained))

    chatManager:call("reqAddChatInfomation", hpStaminaMessage, 0)
    chatManager:call("reqAddChatInfomation", message, 2289944406)
end

re.on_frame(function()
    if not settings.data.skipDangoSong and not settings.data.skipEating then
        return
    end

    pcall(function()
        local kitchen = sdk.get_managed_singleton(
            "snow.gui.fsm.kitchen.GuiKitchenFsmManager")

        if kitchen ~= nil then
            assertSafety(kitchen, "kitchen")
            local cookHandler = getCookDemoHandler:call(kitchen)
            assertSafety(kitchen, "kitchen")
            local eatHandler = getEatDemoHandler:call(kitchen)
            skippedCutsceneThisFrame = false

            if cookHandler ~= nil and settings.data.skipDangoSong then
                assertSafety(cookHandler, "cookHandler")
                local loadState = getLoadState:call(cookHandler)
                assertSafety(cookHandler, "cookHandler")
                local isPlaying = getPlaying:call(cookHandler)

                if loadState == 5 and isPlaying and cookHandler
                    ~= lastCookHandlerStopped then
                    modUtils.info("Requesting finish for cookHandler!")
                    assertSafety(cookHandler, "cookHandler")
                    lastCookHandlerStopped = cookHandler
                    skippedCutsceneThisFrame = true
                    reqFinish:call(cookHandler, 0)
                end
                if not settings.data.skipEating then kitchen:set_IsCookDemoSkip(true) end
            end
            if eatHandler ~= nil and settings.data.skipEating then
                if skippedCutsceneThisFrame then
                    modUtils.info(
                        "(eatHandler) Already skipped a cutscene on this frame. Waiting for the next one.")
                    return
                end

                assertSafety(eatHandler, "eatHandler")
                local loadState = getLoadState:call(eatHandler)
                assertSafety(eatHandler, "eatHandler")
                local isPlaying = getPlaying:call(eatHandler)

                if loadState == 5 and isPlaying and eatHandler
                    ~= lastEatHandlerStopped then
                    modUtils.info("Requesting finish for eatHandler!")
                    assertSafety(eatHandler, "eatHandler")
                    lastEatHandlerStopped = eatHandler
                    reqFinish:call(eatHandler, 0)
                    printSkills()
                end
            end

            local guiManager = sdk.get_managed_singleton("snow.gui.GuiManager")
            local bbq = guiManager:call("get_refGuiKichen_BBQ");

            assertSafety(bbq, "bbq")
            local motleyHandler = getBBQDemoHandler:get_data(bbq)

            if motleyHandler ~= nil and settings.data.skipMotley then
                assertSafety(motleyHandler, "motleyHandler")
                local loadState = getLoadState:call(motleyHandler)
                assertSafety(motleyHandler, "motleyHandler")
                local isPlaying = getPlaying:call(motleyHandler)

                if loadState == 5 and isPlaying and motleyHandler
                    ~= lastMotleyHandlerStopped then
                    modUtils.info("Requesting finish for motleyHandler!")
                    assertSafety(motleyHandler, "motleyHandler")
                    lastMotleyHandlerStopped = motleyHandler;
                    reqFinish:call(motleyHandler, 0)
                end
            end
        end
    end)
end)

re.on_draw_ui(function()
    if imgui.tree_node(modName) then
        local changedEnabled, userenabled =
            imgui.checkbox("Skip the song", settings.data.skipDangoSong)
        settings.handleChange(changedEnabled, userenabled, "skipDangoSong")

        local changedEating, userEating =
            imgui.checkbox("Skip eating", settings.data.skipEating)
        settings.handleChange(changedEating, userEating, "skipEating")

        local changedMotley, userMotley =
            imgui.checkbox("Skip Motley Mix", settings.data.skipMotley)
        settings.handleChange(changedMotley, userMotley, "skipMotley")

        imgui.push_item_width(150.0)
        imgui.text("Notification Language:")
        imgui.same_line()
        settings.imgui("language", imgui.combo, " ", languages)
        imgui.pop_item_width()

        if not settings.isSavingAvailable then
            imgui.text(
                "WARNING: JSON utils not available (your REFramework version may be outdated). Configuration will not be saved between restarts.")
        end

        imgui.text(version)
        imgui.text(author)
        imgui.text(credits)
        imgui.text(credits2)
        imgui.tree_pop()
    end
end)
