local module = {
	folder = "Anomaly Checker",
}

local config
local modUtils
local settings

local Checked

local LifeT
local OrderNumT
local TagetT
local TimeT
local MapT

local SLinited
local StageReady

local SL

local function SingletonsInited()
	if SLinited then
		return true
	else
		for i,v in pairs(SL) do
			SL[i].d = sdk.get_managed_singleton(SL[i].n)
			if not SL[i].d then 
				return false
			end
		end
		SLinited = true
		return true
	end
end

local function IsStageReady()
	if StageReady then
		return true
	else
		if SingletonsInited() and SL.StageManager.d:get_IsReadyInitialize() then
			StageReady = true
			return true
		else
			return false
		end
	end
end

function CheckQuest()
	local QuestData = SL.QuestManager.d:getActiveRandomMysteryQuestData()
	if QuestData then
		local QuestLevel = QuestData:get_field("_QuestLv") -- 任务等级
		local TargetNum = QuestData:get_field("_HuntTargetNum") -- 目标个数
		local TimeLimit = QuestData:get_field("_TimeLimit") -- 时间限制
		local QuestLife = QuestData:get_field("_QuestLife") -- 可猫车次数
		local TargetEmRank = QuestData:getMainTargetEmRank() -- 怪异化目标的怪异等级
		local QuesOrderNum = QuestData:get_field("_QuestOrderNum") -- 参加人数
		local MapNo = QuestData:get_field("_MapNo") -- 地图编号

		if 	not LifeT[QuestLife] or
			not OrderNumT[QuesOrderNum] or
			not TagetT[TargetNum] or
			not TimeT[TimeLimit] or
			not MapT[MapNo] or
			QuestLevel > 100 or
			(QuestLife == 9 and TargetEmRank > 1) or
			( (TargetNum == 2) and ( (QuestLevel <= 20) or (TimeLimit == 25) ) ) or
			( (TargetNum == 3) and ( (QuestLevel <= 40) or (TimeLimit ~= 50) ) )			
		then
			return false
		end
		return true
	end
	return nil
end

function module.init()
	config = require "RiseEnhanced.utils.config"
	modUtils = require "RiseEnhanced.utils.mod_utils"
	settings = modUtils.getConfigHandler({
		enable = true,
		onlineOnly = false,
	}, config.folder .. "/" .. module.folder)

	Checked = false

	LifeT = {[1] = true,[2] = true,[3] = true,[4] = true,[5] = true,[9] = true,}
	OrderNumT = {[2] = true,[4] = true}
	TagetT = {[1]= true,[2]= true,[3]= true}
	TimeT = {[25] = true,[30] = true,[35] = true,[50] = true}
	MapT = {[1]= true,[2]= true,[3]= true,[4]= true,[5]= true,[12]= true,[13]= true}

	SLinited = false
	StageReady = false

	SL = {
		ChatManager =	{n = "snow.gui.ChatManager"},
		QuestManager =	{n = "snow.QuestManager"},
		StageManager =	{n = "snow.stage.StageManager"}
	}

	re.on_pre_application_entry("UpdateBehavior", function()
        if IsStageReady() and config.getQuestStatusName() == "quest" and settings.data.enable and not Checked and (not settings.data.onlineOnly or SL.StageManager.d:get_IsQuestOnline()) then
            Checked = true
			if CheckQuest() == false then
				SL.ChatManager.d:call("reqAddChatInfomation", settings.lang.anomalyChecker.warning, 2289944406)
			end
        elseif config.getQuestStatusName() ~= "quest" and Checked then
            Checked = false
        end
    end)
end

function module.draw()
	if imgui.tree_node(config.lang.anomalyChecker.name) then
		settings.imgui("enable", imgui.checkbox, config.lang.enable)
		settings.imgui("onlineOnly", imgui.checkbox, config.lang.anomalyChecker.onlineOnly)
		imgui.tree_pop()
	end
end

return module