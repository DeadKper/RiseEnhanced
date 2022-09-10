local module = {
	folder = "Template",
}

local config
local modUtils
local settings

function module.init()
	config = require "RiseEnhanced.misc.config"
	modUtils = require "RiseEnhanced.utils.mod_utils"
	settings = modUtils.getConfigHandler({
		enable = true,
	}, config.folder .. "/" .. module.folder)
end

function module.draw()
	if imgui.tree_node(config.lang.template.name) then
		settings.imgui("enable", imgui.checkbox, config.lang.enable)
		imgui.tree_pop()
	end
end

return module