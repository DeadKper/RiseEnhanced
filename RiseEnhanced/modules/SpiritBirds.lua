local module = {
	folder = "Spirit Birds",
    managers = {
        "PlayerManager",
        "EnvironmentCreatureManager",
    },
    default = {
        enable = true,
        spawnPrism = false,
        spiritBirds = { 5, 3, 0, 0 },
        spawned = false,
        spawnedBirds = {},
    },
}

local config
local settings

-- Sprit Bird types w/ index for EnvironmentCreatureManager#_EcPrefabList.mItems
local SPIRIT_BIRDS
local next_stamina_max
local next_player

-- Get the player
local function getPlayer()
    local player = config.PlayerManager:call("findMasterPlayer")
    if not player then return end
    player = player:call("get_GameObject")
    return player
end

-- Get the player's location
local function getPlayerLocation()
    local player = getPlayer()
    if not player then return end
    local location = player:call("get_Transform"):call("get_Position")
    if not location then return end
    return location
end

-- Function to get length of table
local function getLength(obj)
    local count = 0
    for _ in pairs(obj) do count = count + 1 end
    return count
end

local function clearBirds()
    for _, bird in pairs(settings.data.spawnedBirds) do bird:call("destroy", bird) end
    settings.reset("spawned")
    settings.reset("spawnedBirds")
end

-- Spawn the bird
local function spawnBird(type)
    if not config.isEnabled(settings.data.enable, module.managers) then return end
    local location = getPlayerLocation()

    -- Create the bird
    local ecList = config.EnvironmentCreatureManager:get_field("_EcPrefabList"):get_field("mItems"):get_elements()
    local ecBird = ecList[SPIRIT_BIRDS[type]]
    if not ecBird:call("get_Standby") then ecBird:call("set_Standby", true) end

    -- Set the bird as active
    local bird = ecBird:call("instantiate(via.vec3)", location)

    -- If the bird isn't managed, try spawning another (This prevents the having to spawn twice if bird doesn't exist in level)
    if not sdk.is_managed_object(bird) then
        spawnBird(type)
    else
        settings.insert("spawnedBirds", bird)
    end
end

function module.init()
    config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)
    if config.getQuestStatusName() ~= "quest" then
        settings.reset("spawned")
        settings.reset("spawnedBirds")
    end

    SPIRIT_BIRDS = {
        atk = 11,
        def = 12,
        hp = 13,
        spd = 14,
        all = 15,
        gold = 31
    }

    next_stamina_max = 0.0

    -- Watch for Auto-Spawn of Prism and clear spawned birds after quest ends
    re.on_pre_application_entry("UpdateBehavior", function()
        -- If Auto spawn is enabled and quest status says it's active
        if config.getQuestStatus() == 2 and settings.data.enable and not settings.data.spawned then
            if not settings.data.spawned then
                if settings.data.spawnPrism then
                    spawnBird("all")
                else
                    for _ = 1, settings.data.spiritBirds[1] do spawnBird("hp")  end
                    for _ = 1, settings.data.spiritBirds[2] do spawnBird("spd") end
                    for _ = 1, settings.data.spiritBirds[3] do spawnBird("atk") end
                    for _ = 1, settings.data.spiritBirds[4] do spawnBird("def") end
                end

                settings.update("spawned", true)
            end

            -- If the quest status is not active, clear the spawned birds, and set spawned to false
        elseif config.getQuestStatus() ~= 2 and getLength(settings.data.spawnedBirds) > 0 then
            clearBirds()
        end
    end)

    sdk.hook(
        sdk.find_type_definition("snow.player.PlayerQuestBase"):get_method("calcLvBuffStamina"),
        function(args)
            local player = sdk.to_managed_object(args[2])
            local count = sdk.to_int64(args[3])

            next_stamina_max = count * 30.0
            next_player = player
        end,
        function(retval)
            next_player:call("calcStaminaMax", next_stamina_max, false)
        end
    )

    -- Remove any spawned birds on script reset
    re.on_script_reset(clearBirds)
end

function module.draw()
    if imgui.tree_node(config.lang.birds.name) then
        settings.imgui(imgui.checkbox, "enable", config.lang.birds.autoSpawn)
        settings.imgui(imgui.slider_int, { "spiritBirds", 1 }, config.lang.birds.health, 0, 10)
        settings.imgui(imgui.slider_int, { "spiritBirds", 2 }, config.lang.birds.stamina, 0, 10)
        settings.imgui(imgui.slider_int, { "spiritBirds", 3 }, config.lang.birds.attack, 0, 10)
        settings.imgui(imgui.slider_int, { "spiritBirds", 4 }, config.lang.birds.defense, 0, 10)
        settings.imgui(imgui.checkbox, "spawnPrism", config.lang.birds.spawnPrism)
        if imgui.button(config.lang.reset) then
            settings.reset()
        end
        if imgui.tree_node("Manual spawn") then
            if imgui.button(config.lang.birds.healthButton) then spawnBird("hp") end
            imgui.same_line()
            if imgui.button(config.lang.birds.staminaButton) then spawnBird("spd") end
            if imgui.button(config.lang.birds.attackButton) then spawnBird("atk") end
            imgui.same_line()
            if imgui.button(config.lang.birds.defenseButton) then spawnBird("def") end
            if imgui.button(config.lang.birds.rainbowButton) then spawnBird("all") end
            if imgui.button(config.lang.birds.goldenButton) then spawnBird("gold") end
            imgui.tree_pop()
        end
        
		imgui.tree_pop()
	end
end

return module