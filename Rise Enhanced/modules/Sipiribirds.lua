-- Import libraries
local data = require("Rise Enhanced.utils.data")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings, cache = data.getDefaultModule(
    "Spiribirds", {
        enabled = true,
        prism = true,
        birds = {
            hp  = 5,
            spd = 5,
            atk = 5,
            def = 5,
        }
    }
)

local birdsTable = {
    atk = 11,
    def = 12,
    hp = 13,
    spd = 14,
    prism = 15,
    gold = 31
}

local stamina = {
    max = 0,
    player = nil,
}

local spawned = {}

-- Main code

local function getPlayerLocation()
    local player = utils.getPlayerObject()
    if not player then return end
    local location = player:call("get_Transform"):call("get_Position")
    if not location then return end
    return location
end

-- clear spawned birds
local function clear()
    for _, bird in pairs(spawned) do
        bird:call("destroy", bird)
    end
    spawned = {}
end

local function spawn(type)
    if not utils.getQuestStatusName() == "quest" then return end

    local location = getPlayerLocation()
    local manager = sdk.get_managed_singleton("snow.envCreature.EnvironmentCreatureManager")
    if manager == nil then return end

    -- create bird
    local ecList = manager:get_field("_EcPrefabList"):get_field("mItems"):get_elements()
    local ecBird = ecList[birdsTable[type]]
    if not ecBird:call("get_Standby") then ecBird:call("set_Standby", true) end

    -- set bird as active
    local bird = ecBird:call("instantiate(via.vec3)", location)

    -- if bird isn't managed, try spawning another (prevents having to spawn twice if bird doesn't exist in level)
    if not sdk.is_managed_object(bird) then
        spawn(type)
    else
        table.insert(spawned, bird)
    end

    cache.set("spawned", true)
end

local function spawnBirds()
    if settings.get("prism") then
        spawn("prism")
    else
        for k, v in pairs(settings.get("birds")) do
            for _ = 1, v do spawn(k) end
        end
    end
end

-- Hooks

-- spawn birds
re.on_pre_application_entry("UpdateBehavior",
    function()
        if utils.getQuestStatusName() == "quest" then
            if cache.get("spawned") then return end
            if not module.enabled() then return end

            utils.addTimer(3, spawnBirds)
        elseif #spawned > 0 then
            clear()
        end
    end
)

-- fill stamina when picking up spiribird
sdk.hook(sdk.find_type_definition("snow.player.PlayerQuestBase"):get_method("calcLvBuffStamina"),
    function (args)
        stamina.player = sdk.to_managed_object(args[2])
        stamina.max = sdk.to_int64(args[3]) * 30.0
    end,
    function (retval)
        stamina.player:call("calcStaminaMax", stamina.max, false)
        return retval
    end
)

-- clear cache
sdk.hook(sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
    function (args)
        cache.set("spawned", false)
    end
)

-- remove spiribirds on script reset
re.on_script_reset(function()
    clear()
end)

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.init()
    cache.setNil("spawned", false)
end

---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("prism", imgui.checkbox, data.lang.Spiribirds.spawnPrism)
    settings.sliderInt({ "birds", "hp"  }, data.lang.Spiribirds.health,  0, 10)
    settings.sliderInt({ "birds", "spd" }, data.lang.Spiribirds.stamina, 0, 10)
    settings.sliderInt({ "birds", "atk" }, data.lang.Spiribirds.attack,  0, 10)
    settings.sliderInt({ "birds", "def" }, data.lang.Spiribirds.defense, 0, 10)

    if utils.getQuestStatusName() ~= "quest" then return end
    if imgui.tree_node("Manual spawn") then
        utils.imguiButton(data.lang.Spiribirds.healthButton,  spawn, "hp" )
        imgui.same_line()
        utils.imguiButton(data.lang.Spiribirds.staminaButton, spawn, "spd")
        utils.imguiButton(data.lang.Spiribirds.attackButton,  spawn, "atk")
        imgui.same_line()
        utils.imguiButton(data.lang.Spiribirds.defenseButton, spawn, "def")
        utils.imguiButton(data.lang.Spiribirds.rainbowButton, spawn, "prism")
        utils.imguiButton(data.lang.Spiribirds.goldenButton,  spawn, "gold")
        imgui.tree_pop()
    end
end

return module