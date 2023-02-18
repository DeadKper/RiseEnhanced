local utils = require("Rise Enhanced.utils.utils")

local data = {
    file = "config",
    folder = "Rise Enhanced",
    cacheFile = "cache",
    version = "4.0.1",
    beta = false,
    enabled = true,
    lang = require("Rise Enhanced.languages.en_US")
}

function data.getDefaultModule(name, _defaults, _file, _folder)
    if _folder == nil then
        _folder = data.folder
    else
        _folder = data.folder .. "/" .. _folder
    end

    if _file == nil then
        _file = name
    end

    if _defaults == nil then _defaults = { enabled = true } end

    local module = {
        file = _file,
        folder = _folder,
        default = _defaults,
    }

    local settings, cache = utils.getHandlers(
        module.default,
        module.folder,
        module.file,
        name
    )

    module.settings = settings
    module.cache = cache

    function module.init() end

    function module.getName()
        return data.lang[name].name
    end

    function module.getSettings()
        return utils.copy(module.settings.data)
    end

    function module.enabledCheck(_value, _label)
        settings.call(
            _value ~= nil and _value or "enabled",
            imgui.checkbox,
            _label ~= nil and _label or data.lang.enabled
        )
    end

    function module.resetButton(_value, _label)
        utils.imguiButton(
            _label ~= nil and _label or data.lang.reset,
            settings.reset,
            _value
        )
    end

    -- If inner returns true a reset to default button will appear below automatically.
    -- Will print an enabled button and return nil if not overriden
    function module.drawInnerUi()
        module.enabledCheck()
    end

    local value
    function module.drawUi()
        if imgui.tree_node(module.getName()) then
            value = module.drawInnerUi()
            if value then
                if type(value) ~= "string" and type(value) ~= "table" then value = nil end
                module.resetButton(value)
            end
            imgui.tree_pop()
        end
    end

    -- check other properties to determine wheter the option is enabled or not
    function module.enabled(...)
        local table = {...}
        local globalEnable = data.enabled and settings.get("enabled")
        if #table == 0 then
            return globalEnable
        end
        local check = false
        for _, v in pairs(table) do
            check = check or settings.get(v)
        end
        return globalEnable and check
    end

    return module, settings, cache
end

function data.print()
    local copy = utils.copy(data)
    copy.lang = nil
    utils.treeText("Data", copy, "data")
end

return data