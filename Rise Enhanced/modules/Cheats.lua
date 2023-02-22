-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = data.getDefaultModule(
    "Cheats", {
        enabled = false,
        unlimitedCoatings = true,
        unlimitedAmmo = true,
    }
)

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()
    sdk.hook(utils.definition("snow.data.bulletSlider.BottleSliderFunc", "consumeItem"),
        function(args)
            if module.enabled("unlimitedCoatings") then
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,
        utils.retval
    )

    sdk.hook(utils.definition("snow.data.bulletSlider.BulletSliderFunc", "consumeItem"),
        function(args)
            if module.enabled("unlimitedAmmo") then
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end, utils.retval
    )
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("unlimitedAmmo", imgui.checkbox, data.lang.Cheats.unlimitedAmmo)
    settings.call("unlimitedCoatings", imgui.checkbox, data.lang.Cheats.unlimitedCoatings)
end

return module