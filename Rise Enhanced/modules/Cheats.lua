-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = mod.getDefaultModule(
    "Cheats", {
        enabled = false,
        unlimitedCoatings = true,
        unlimitedAmmo = true,
    }
)

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()
    utils.hook({"snow.data.bulletSlider.BottleSliderFunc", "consumeItem"},
        function(args)
            if module.enabled("unlimitedCoatings") then
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,
        utils.retval
    )

    utils.hook({"snow.data.bulletSlider.BulletSliderFunc", "consumeItem"},
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
    settings.call("unlimitedCoatings", imgui.checkbox, mod.lang.Cheats.unlimitedCoatings)
    settings.call("unlimitedAmmo", imgui.checkbox, mod.lang.Cheats.unlimitedAmmo)
end

return module