local module = {
	name = "Template",
}

local info
local modUtils
local settings

function module.init()
	info = require "RiseEnhanced.misc.info"
	modUtils = require "RiseEnhanced.utils.mod_utils"
	settings = modUtils.getConfigHandler({
		enable = true,
	}, info.modName .. "/" .. module.name)
end

function module.draw()
	if imgui.tree_node(module.name) then
		settings.imgui("enable", imgui.checkbox, "Enabled")
		imgui.tree_pop()
	end
end

return module