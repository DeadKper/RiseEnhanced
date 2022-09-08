local info = require("RiseEnhanced.misc.info")
local modUtils = require("RiseEnhanced.utils.mod_utils")
local modules = {
	cohoot = require("RiseEnhanced.modules.CohootNest"),
	dango = require("RiseEnhanced.modules.Dango"),
	npc = require("RiseEnhanced.modules.NPC"),
	dangoTicket = require("RiseEnhanced.modules.DangoTicket"),
	revive = require("RiseEnhanced.modules.NearestCampRevive"),
	restock = require("RiseEnhanced.modules.Restock"),
	birds = require("RiseEnhanced.modules.SpiritBirds")
}

local settings = modUtils.getConfigHandler({
    isMenuOpen = false,
}, info.modName)

local menu = {
	name = "Menu",
	wasOpen = false,
	window = nil,
}

function menu.init()
	menu.window = {
		position = { 480, 100 },
		pivot = { 0, 0 },
		size = { 540, 540 },
		flags = 0x10120,
	}

	menu.wasOpen = settings.data.isMenuOpen

	for _, current_module in pairs(modules) do
		current_module.init()
	end
end

function menu.draw()
	imgui.set_next_window_pos(menu.window.position, 1 << 3, menu.window.pivot);
	imgui.set_next_window_size(menu.window.size, 1 << 3);

	settings.data.isMenuOpen = imgui.begin_window(
		info.modName .. " " .. info.version, settings.data.isMenuOpen,
		menu.window.flags);

	if not settings.data.isMenuOpen then
		imgui.end_window();
		return;
	end

	modules.cohoot.draw()
	modules.dango.draw()
	modules.npc.draw()
	modules.restock.draw()
	modules.revive.draw()
	modules.birds.draw()
	modules.dangoTicket.draw()

	imgui.end_window();
end

menu.init()

re.on_draw_ui(function()
	if imgui.button("[ " .. info.modName .. " ]") then
		settings.update(not settings.data.isMenuOpen, "isMenuOpen")
		menu.wasOpen = settings.data.isMenuOpen
	end
end);

re.on_frame(function()
	info.time = info.time + 1

	if settings.data.isMenuOpen ~= menu.wasOpen then
		settings.update(settings.data.isMenuOpen, "isMenuOpen")
		menu.wasOpen = settings.data.isMenuOpen
	end

	if not reframework:is_drawing_ui() then
		return
	end

	if settings.data.isMenuOpen then
		pcall(menu.draw);
	end
end);