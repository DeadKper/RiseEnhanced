local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")
local data = utils.getData()

local module, settings, cache = mod.getDefaultModule(
    "Template", {
        enabled = true,
    }
)

---@diagnostic disable-next-line: duplicate-set-field
function module.init()

end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
end

return module