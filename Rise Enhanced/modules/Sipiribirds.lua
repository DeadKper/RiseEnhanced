-- Import libraries
local mod = require("Rise Enhanced.utils.mod")
local utils = require("Rise Enhanced.utils.utils")

-- Init module
local module, settings = mod.getDefaultModule(
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
    local player = utils.singleton("snow.player.PlayerManager", "findMasterPlayer", "get_GameObject")
    if not player then return end
    local location = player:call("get_Transform"):call("get_Position")
    if not location then return end
    return location
end

-- remove spawned birds
local function destroyBirds()
    if #spawned == 0 then return end
    for _, bird in pairs(spawned) do
        bird:call("destroy", bird)
    end
    spawned = {}
end

local function spawn(type)
    if not utils.getQuestStatusName() == "quest" then return end

    local location = getPlayerLocation()
    local manager = utils.singleton("snow.envCreature.EnvironmentCreatureManager")
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

---@diagnostic disable-next-line: duplicate-set-field
function module.hook()
        -- spawn birds on quest start
    utils.hook({"snow.QuestManager", "questStart"},
        function(args)
            if not module.enabled() then return end

            utils.addTimer(3, spawnBirds)
        end,
        utils.retval
    )

    -- remove birds on quest end
    utils.hook({"snow.QuestManager", "onQuestEnd"},
        destroyBirds,
        utils.retval
    )

    -- fill stamina when picking up spiribird
    utils.hook({"snow.player.PlayerQuestBase", "calcLvBuffStamina"},
        function (args)
            stamina.player = sdk.to_managed_object(args[2])
            stamina.max = sdk.to_int64(args[3]) * 30.0
        end,
        function (retval)
            stamina.player:call("calcStaminaMax", stamina.max, false)
            return retval
        end
    )

    -- remove spiribirds on script reset
    re.on_script_reset(destroyBirds)
end

-- Draw module
---@diagnostic disable-next-line: duplicate-set-field
function module.drawInnerUi()
    module.enabledCheck()
    settings.call("prism", imgui.checkbox, mod.lang.Spiribirds.spawnPrism)
    settings.slider({ "birds", "hp"  }, mod.lang.Spiribirds.health,  0, 10)
    settings.slider({ "birds", "spd" }, mod.lang.Spiribirds.stamina, 0, 10)
    settings.slider({ "birds", "atk" }, mod.lang.Spiribirds.attack,  0, 10)
    settings.slider({ "birds", "def" }, mod.lang.Spiribirds.defense, 0, 10)
    module.resetButton("birds")

    if utils.getQuestStatusName() ~= "quest" then return end
    if imgui.tree_node("Manual spawn") then
        utils.imguiButton(mod.lang.Spiribirds.healthButton,  spawn, "hp" )
        imgui.same_line()
        utils.imguiButton(mod.lang.Spiribirds.staminaButton, spawn, "spd")
        utils.imguiButton(mod.lang.Spiribirds.attackButton,  spawn, "atk")
        imgui.same_line()
        utils.imguiButton(mod.lang.Spiribirds.defenseButton, spawn, "def")
        utils.imguiButton(mod.lang.Spiribirds.rainbowButton, spawn, "prism")
        utils.imguiButton(mod.lang.Spiribirds.goldenButton,  spawn, "gold")
        imgui.tree_pop()
    end
end

return module