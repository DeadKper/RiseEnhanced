local module = {
	folder = "Template",
	managers = {},
	default = {
		enable = true,
	},
}

local config
local settings

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)
end

function module.draw()
	if imgui.tree_node(config.lang.template.name) then
		settings.imgui(imgui.checkbox, "enable", config.lang.enable)
		imgui.tree_pop()
	end
end

return module