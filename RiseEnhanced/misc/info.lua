local modUtils = require("RiseEnhanced.utils.mod_utils")

local info = {
	modName = "Rise Enhanced",
	version = "1.2.0",
	time = 0,
}

info.settings = modUtils.getConfigHandler({
	language = "en_us",
}, info.modName)

local PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager")

local WeaponNames = {
	[0] = "Great Sword",
	[1] = "Swtich Axe",
	[2] = "Long Sword",
	[3] = "Light Bowgun",
	[4] = "Heavy Bowgun",
	[5] = "Hammer",
	[6] = "Gunlance",
	[7] = "Lance",
	[8] = "Sword & Shield",
	[9] = "Dual Blades",
	[10] = "Hunting Horn",
	[11] = "Charge Blade",
	[12] = "Insect Glaive",
	[13] = "Bow",
}

function info.getCurrentWeaponType()
    if PlayerManager == nil then PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager") end
    if PlayerManager == nil then return end
    local MasterPlayer = PlayerManager:call("findMasterPlayer")
    if MasterPlayer == nil then return end

    local weaponType = MasterPlayer:get_field("_playerWeaponType")
    return weaponType
end

function info.getCurrentWeaponName(typeNumber)
	if typeNumber == nil then
		typeNumber = info.getCurrentWeaponType()
	end
	return WeaponNames[typeNumber]
end

return info
