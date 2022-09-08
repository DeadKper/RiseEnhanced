local modUtils = require("RiseEnhanced.utils.mod_utils")

local info = {
	modName = "Rise Enhanced",
	version = "1.1.1",
	time = 0,
}

info.settings = modUtils.getConfigHandler({
	language = "en_us",
}, info.modName)

return info
