-- nearest_camp_revive.lua : written by archwizard1204
-- Only on NexusMods, my profile page: https://www.nexusmods.com/users/154089548?tab=user+files
local module = {
	folder = "Nearest Camp Revive",
    managers = {
        "QuestMapManager",
        "PlayerManager",
        "StagePointManager",
    },
    default = {
		enable = true
	},
}

local config
local settings

local skipCreateNeko
local skipWarpNeko
local reviveCamp
local nekoTaku
local nekoTakuList

local function getCurrentMapNo()
    return config.QuestMapManager:get_CurrentMapNo()
end

local function getCurrentPosition()
    local masterPlayer = config.PlayerManager:call("findMasterPlayer")
    return masterPlayer:call("get_GameObject"):call("get_Transform"):call("get_Position")
end

local function getCampList()
    return config.StagePointManager:get_field("_TentPositionList")
end

local function calculateDistance(point1, point2)
    return ((point1.x - point2.x) ^ 2 + (point1.z - point2.z) ^ 2) ^ 0.5
end

local function getFastTravelPt(index)
    return config.StagePointManager:get_field("_FastTravelPointList"):get_field("mItems"):get_element(index):get_field(
        "_PointArray"):get_element(0)
end

local function findNearestCamp(camps, nekoTakuPos)
    local nearestCampIndex = nil
    local nearestDistance = nil
    local nearestCamp = nil
    local currentPos = getCurrentPosition()

    for i = 0, camps:get_size(), 1 do
        local camp = camps:get_element(i)
        if camp then
            local distance = calculateDistance(currentPos, camp)
            if i == 0 then
                nearestCamp = camp
                nearestDistance = distance
                nearestCampIndex = i
            end

            if distance < nearestDistance and camp.x ~= 0.0 then
                nearestDistance = distance
                nearestCamp = camp
                nearestCampIndex = i
            end
        end
    end

    local fastTravelPt = getFastTravelPt(nearestCampIndex)

    if not fastTravelPt then
        fastTravelPt = nearestCamp
    end

    if nearestCampIndex ~= 0 then
        skipCreateNeko = true
        skipWarpNeko = true
        reviveCamp = Vector3f.new(fastTravelPt.x, fastTravelPt.y, fastTravelPt.z)
        nekoTaku = nekoTakuPos[nearestCampIndex]
        if not nekoTaku then
            nekoTaku = reviveCamp
        end
    end
end

local function initData(args)
    if not settings.data.enable then
        return sdk.PreHookResult.CALL_ORIGINAL
    end
    
    local camps = getCampList()
    local mapNo = getCurrentMapNo()
    skipCreateNeko = false
    skipWarpNeko = false
    reviveCamp = nil
    nekoTaku = nil

    if camps and nekoTakuList[mapNo] then
        findNearestCamp(camps, nekoTakuList[mapNo])
    end
    return sdk.PreHookResult.CALL_ORIGINAL
end

local function redirectNekotaku(args)
    if skipCreateNeko then
        skipCreateNeko = false
        local self = sdk.to_managed_object(args[2]) -- self
        self:call("CreateNekotaku", args[3], nekoTaku, args[5])
        return sdk.PreHookResult.SKIP_ORIGINAL
    end
    return sdk.PreHookResult.CALL_ORIGINAL
end

local function redirectWarpNeko(args)
    if skipWarpNeko then
        skipWarpNeko = false
        local self = sdk.to_managed_object(args[2]) -- self
        self:call("setPlWarpInfo(via.vec3, System.Single, snow.stage.StageManager.AreaMoveQuest)", reviveCamp, 0, 20)
        return sdk.PreHookResult.SKIP_ORIGINAL
    end
    return sdk.PreHookResult.CALL_ORIGINAL
end

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

	skipCreateNeko = false
	skipWarpNeko = false

	nekoTakuList = {
		[1] = {
			[1] = Vector3f.new(236.707, 174.37, -510.568)
		}, -- 大社跡
		[2] = {
			[1] = Vector3f.new(-117.699, -45.653, -233.201),
			[2] = Vector3f.new(116.07, -63.316, -428.018)
		}, -- 砂原
		[3] = {
			[1] = Vector3f.new(207.968, 90.447, 46.081)
		}, -- 水没林
		[4] = {
			[1] = Vector3f.new(-94.171, 2.744, -371.947),
			[2] = Vector3f.new(103.986, 26, -496.863)
		}, -- 寒冷群島
		[5] = {
			[1] = Vector3f.new(244.252, 147.122, -537.940),
			[2] = Vector3f.new(-40.000, 81.136, -429.201)
		}, -- 溶岩洞
		[12] = {
			[1] = Vector3f.new(3.854, 32.094, -147.152)
		}, -- 密林
		[13] = {
			[1] = Vector3f.new(107.230, 94.988, -254.308)
		} -- 城塞高地
	}

	sdk.hook(sdk.find_type_definition("snow.wwise.WwiseMusicManager"):get_method("startToPlayPlayerDieMusic"), initData, nil)
	sdk.hook(sdk.find_type_definition("snow.stage.StageManager"):get_method("setPlWarpInfo_Nekotaku"), redirectWarpNeko, nil)
	sdk.hook(sdk.find_type_definition("snow.NekotakuManager"):get_method("CreateNekotaku"), redirectNekotaku, nil)
end

function module.draw()
	if imgui.tree_node(config.lang.revive.name) then
		settings.imgui(imgui.checkbox, "enable", config.lang.enable)
		imgui.tree_pop()
	end
end

return module