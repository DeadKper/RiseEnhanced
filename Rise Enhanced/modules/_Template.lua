-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings, cache = mod.getDefaultModule(
    "Template", {
        enabled = true,
    }
)

-- Main code

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()

end

---@diagnostic disable-next-line: duplicate-set-field
function module.init()

end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
end

return module