local module = {
	folder = "Auto NPC Talk",
	default = {
		enable = true,
	},
}

local config
local settings

local npcList
local npcTalkMessageList

local function getTalkTarget(args)
    if settings.data.enable then
        local self = sdk.to_managed_object(args[2]) -- self
        if self ~= nil then
            local npcId = self:call("get_NpcId")
            if npcList[npcId] then
                if sdk.is_managed_object(self) == true then
                    table.insert(npcTalkMessageList, self)
                end
            end
        end
    end
    return sdk.PreHookResult.CALL_ORIGINAL
end

local function talkHandler(retval)
    if settings.data.enable then
        if next(npcTalkMessageList) ~= nil then
            for k, v in ipairs(npcTalkMessageList) do
                v:call("resetTalkDispName")
                v:call("executeTalkAction")
                v:call("set_DetermineSpeechBalloonMessage", nil)
                v:call("set_SpeechBalloonAttr", nil)
            end
            npcTalkMessageList = {}
        end
    end
    return retval
end

function module.init()
	config = require("RiseEnhanced.utils.config")
    settings = config.makeSettings(module)

	npcList = {
		-- カムラ
		[1] = true, -- 里長フゲン
		[3] = true, -- 雑貨屋のカゲロウ
		[4] = true, -- 茶屋のヨモギ
		[38] = true, -- ギルドマネージャー・ゴコク
		[67] = true, -- オトモ広場管理人シルベ
		-- エルガド
		[77] = true, -- 提督ガレアス
		[78] = true, -- 研究員バハリ
		[85] = true, -- 出張オトモ広場窓口のナギ
		[86] = true, -- 雑貨屋のオボロ
		[87] = true, -- 茶屋のアズキ
		[106] = true -- 船乗りのピンガル
	}

	npcTalkMessageList = {}

	sdk.hook(sdk.find_type_definition("snow.npc.NpcTalkMessageCtrl"):get_method("start"), getTalkTarget, nil)

	sdk.hook(sdk.find_type_definition("snow.VillageMapManager"):get_method("getCurrentMapNo"), nil, talkHandler)
end

function module.draw()
	if imgui.tree_node(config.lang.npc.name) then
		settings.imgui("enable", imgui.checkbox, config.lang.enable)
		imgui.tree_pop()
	end
end

return module