-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")
require("Rise Enhanced.utils.hooks") -- initialize data hooks only

-- Init library

utils.init(mod.folder, mod.cacheFile)

local module, settings = mod.getDefaultModule(
    mod.folder, {
        enabled = true,
        lang = "en_US",
        window = {
            resetOnStart = false,
            defaultOpen = false,
            position = { 370, 50 },
            size = { 500, 570 },
        },
        debugWindow = {
            resetOnStart = false,
            defaultOpen = false,
            position = { 880, 50 },
            size = { 460, 670 },
        },
    }
)

utils.addLanguage("en_US", require("Rise Enhanced.languages.en_US"))

-- Load modules
local modules = {
    -- Used for code completion only, will always be ignored
    [0] = require("Rise Enhanced.modules._Template")
}
modules[#modules+1] = require("Rise Enhanced.modules.Tweaks")
modules[#modules+1] = require("Rise Enhanced.modules.Item")
modules[#modules+1] = require("Rise Enhanced.modules.Dango")
modules[#modules+1] = require("Rise Enhanced.modules.Sipiribirds")
modules[#modules+1] = require("Rise Enhanced.modules.Weakness")
modules[#modules+1] = require("Rise Enhanced.modules.Cheats")

-- Init variables
local initiated = false

local isMenuOpen = false
local autoOpen = settings.get({"window", "defaultOpen"})
local isDebugOpen = false
local debugAutoOpen = settings.get({"debugWindow", "defaultOpen"})

local isWindowSet = false
local isDebugWindowSet = false

local window = {
    pivot = { 0, 0 },
    condition =  8,
    closeButton = true,
    flags = 0x10120,
}


-- Set initial language
local function setLanguage(change, value)
    if not change then return end
    settings.set("lang", value)
    utils.setLanguage(value)
    mod.lang = utils.getLanguage()
end

setLanguage(true, settings.get("lang"))

local function windowConfig(property)
    settings.call({property, "defaultOpen"}, imgui.checkbox, mod.lang.Config.openState)
    settings.call({property, "resetOnStart"}, imgui.checkbox, mod.lang.Config.resetOnStart)
    local displaySize = imgui.get_display_size()
    settings.slider(
        {property, "position", 1},
        mod.lang.Config.xPos,
        0,
        displaySize.x
    )
    settings.slider(
        {property, "position", 2},
        mod.lang.Config.yPos,
        0,
        displaySize.y
    )
    settings.slider(
        {property, "size", 1},
        mod.lang.Config.width,
        0,
        displaySize.x
    )
    settings.slider(
        {property, "size", 2},
        mod.lang.Config.height,
        0,
        displaySize.y
    )
    module.resetButton(property, mod.lang.Config.resetWindowConfig)
end

-- Draw functions
local function debugWindow()
    if not isDebugOpen then
        if not isDebugWindowSet and debugAutoOpen then
            isDebugOpen = true
        end
        return
    end

    if not isDebugWindowSet then
        isDebugWindowSet = true
        local debug = settings.get("debugWindow")
        if os.clock() <= 180 or debug.resetOnStart then
            imgui.set_next_window_pos(debug.position, window.condition, window.pivot)
            imgui.set_next_window_size(debug.size, window.condition)
        end
    end

    if not imgui.begin_window(
        mod.lang.Debug.button,
        window.closeButton,
        window.flags
    ) then
        isDebugOpen = false
    end

    mod.print()
    utils.printInfoNodes()
    utils.treeText(mod.lang.modName, settings.data, "settings.data")
    for i = 1, #modules do
        local _module = modules[i]
        utils.treeText(_module.getName(), {
            settings = _module.getSettings(),
            enabled = _module.enabled(),
        }, "settings.data")
    end

    imgui.end_window()
end

local function drawWindow()
    utils.imguiButton("[ " .. mod.lang.modName .. " ]", function ()
        isMenuOpen = not isMenuOpen
    end)

    if not isMenuOpen then
        if not isWindowSet and autoOpen then
            isMenuOpen = true
        end
        return
    end

    if not isWindowSet then
        isWindowSet = true
        local _window = settings.get("window")
        if os.clock() <= 180 or _window.resetOnStart then
            imgui.set_next_window_pos(_window.position, window.condition, window.pivot)
            imgui.set_next_window_size(_window.size, window.condition)
        end
    end

    if not imgui.begin_window(
        mod.lang.modName .. " v" .. mod.version .. (mod.beta and "-BETA" or ""),
        window.closeButton,
        window.flags
    ) then
        isMenuOpen = false
    end

    if imgui.tree_node(mod.lang.Config.name) then
        _, mod.enabled = settings.call("enabled", imgui.checkbox, mod.lang.enabled)
        if imgui.tree_node(mod.lang.Config.windowConfig) then
            windowConfig("window")
            imgui.tree_pop()
        end

        if mod.beta and imgui.tree_node(mod.lang.Config.debugConfig) then
            windowConfig("debugWindow")
            if imgui.button(mod.lang.Debug.button) then
                isDebugOpen = not isDebugOpen
            end
            imgui.tree_pop()
        end

        setLanguage(settings.combo("lang", mod.lang.language, utils.getLanguageTable()))

        imgui.tree_pop()
    end

    for i = 1, #modules do
        modules[i].drawUi()
    end

    imgui.end_window()
end

---@diagnostic disable-next-line: duplicate-set-field
function module.getName()
    return mod.lang.modName
end

---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    for i = 1, #modules do -- start on 1 to ignore template module
        local _module = modules[i]
        _module.init()
    end
end

if not initiated then
    initiated = true

    math.randomseed(os.time()) -- set seed for random method

    if utils.getData().loaded then
        module.init()
    else
        utils.hook({"snow.data.DataManager", "onLoad(snow.SaveDataBase)"}, nil, module.init)
    end
end


re.on_draw_ui(
    function ()
        drawWindow()
        debugWindow()
    end
)