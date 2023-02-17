-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Tweaks", {
        enabled = true,
        saveDelay = 5,
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

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    lastSave = os.clock()
end

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()

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
end

return module