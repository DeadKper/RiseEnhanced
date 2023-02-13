-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init library

utils.init(data.folder, data.cacheFile)

local module, settings, cache = data.getDefaultModule(
    data.folder, {
        enabled = true,
        lang = "en_US",
    }
)

utils.setShouldSaveCacheFunction(settings.get, "enabled")
utils.addLanguage("en_US", require("Rise Enhanced.languages.en_US"))

-- Load modules
local modules = {
    -- Used for code completion only, will always be ignored
    [0] = require("Rise Enhanced.modules._Template")
}
modules[#modules+1] = require("Rise Enhanced.modules.Item")
modules[#modules+1] = require("Rise Enhanced.modules.Dango")
modules[#modules+1] = require("Rise Enhanced.modules.Sipiribirds")

-- Init variables
local initiated = false
local mod

local isWindowSet = false
local windowLangSet = {}
local window = {
    position = { 370, 50 },
    debugPosition = { 880, 50 },
    pivot = { 0, 0 },
    size = { 500, 570 },
    debugSize = { 460, 670 },
    condition =  8,
    showCloseButton = true,
    flags = 0x10120,
}

-- Set initial language
local function setLanguage(change, value)
    if not change then return end
    isWindowSet = windowLangSet[value]
    if isWindowSet == nil then windowLangSet[value] = true end
    settings.set("lang", value)
    utils.setLanguage(value)
    data.lang = utils.getLanguage()
end

setLanguage(true, settings.get("lang"))

-- Draw functions
local function debugWindow()
    utils.imguiButton(data.lang.debug.button,
    cache.set, "isDebugOpen", not cache.get("isDebugOpen"))

    if not cache.get("isDebugOpen") then return end

    imgui.set_next_window_pos(window.debugPosition, window.condition, window.pivot)
    imgui.set_next_window_size(window.debugSize, window.condition)

    if not imgui.begin_window(
        data.lang.debug.button,
        window.showCloseButton,
        window.flags
    ) then
        cache.set("isDebugOpen", false)
    end

    data.print()
    utils.printInfoNodes()
    utils.treeText(data.lang.modName, settings.data, "settings.data")
    for i = 1, #modules do
        mod = modules[i]
        utils.treeText(mod.getName(), {
            settings = mod.getSettings(),
            enabled = mod.enabled(),
        }, "settings.data")
    end

    imgui.end_window()
end

local function drawTree(text)
    if imgui.tree_node(text) then
        _, data.enabled = settings.call("enabled", imgui.checkbox, data.lang.enabled)
        setLanguage(settings.combo("lang", data.lang.language, utils.getLanguageTable()))

        if data.beta then
            debugWindow()
        end
        imgui.tree_pop()
    end
end

local function drawWindow()
    utils.imguiButton("[ " .. data.lang.modName .. " ]",
        cache.set, "isMenuOpen", not cache.get("isMenuOpen"))

    if not cache.get("isMenuOpen") then return end

    if not isWindowSet then
        isWindowSet = true
        imgui.set_next_window_pos(window.position, window.condition, window.pivot)
        imgui.set_next_window_size(window.size, window.condition)
    end

    if not imgui.begin_window(
        data.lang.modName .. " v" .. data.version .. (data.beta and "-BETA" or ""),
        window.showCloseButton,
        window.flags
    ) then
        cache.set("isMenuOpen", false)
    end

    drawTree(data.lang.config.name)

    for i = 1, #modules do
        mod = modules[i]
        mod.drawUi()
    end

    imgui.end_window()
end

---@diagnostic disable-next-line: duplicate-set-field
function module.getName()
    return data.lang.modName
end

---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    if initiated then return end
    if not settings.get("enabled") then return end
    initiated = true
    cache.setNil("isMenuOpen", false)
    cache.setNil("isDebugOpen", false)

    for i = 1, #modules do -- start on 1 to ignore template module
        mod = modules[i]
        mod.init()
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawUi()
    if initiated then
        drawWindow()
    else
        drawTree(module.getName())
        module.init()
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function module.onFrame()
    for i = 1, #modules do
        mod = modules[i]
        mod.onFrame()
    end
end

module.init()
re.on_draw_ui(module.drawUi)
re.on_frame(module.onFrame)