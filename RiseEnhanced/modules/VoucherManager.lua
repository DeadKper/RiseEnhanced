local module = {
	name = "Voucher Manager",
}

local info
local modUtils
local settings

local DlcManager

local function on_pre_title_hook(args)
end

local function on_post_title_hook(args)
    if settings.data.enable then
        DlcManager = sdk.get_managed_singleton("snow.DlcManager")
        if DlcManager then
			-- Doesn't seem to be working sadly
            DlcManager:get_field("_SystemSave"):set_field("_UseCharaMakeTicketCount", settings.data.desiredVoucherUseCount)
        end
    end
end

sdk.hook(sdk.find_type_definition("snow.gui.fsm.title.GuiTitleMenuFsmManager"):get_method("openTitle"),
    on_pre_title_hook, on_post_title_hook)

function module.init()
	info = require "RiseEnhanced.misc.info"
	modUtils = require "RiseEnhanced.utils.mod_utils"
	settings = modUtils.getConfigHandler({
		enable = true,
		desiredVoucherUseCount = 1,
	}, info.modName .. "/" .. module.name)
end

function module.draw()
	if imgui.tree_node(module.name) then
		settings.imgui("enable", imgui.checkbox, "Enabled")

        if settings.data.enable then
			settings.imgui("desiredVoucherUseCount", imgui.slider_int, "Voucher Count", 0, 12)
        end
		imgui.tree_pop()
	end
end

return module