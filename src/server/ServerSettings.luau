--!strict
-- Configure these IDs in Studio before enabling live purchases. Zero means off.
-- Developer Products must belong to this experience. Game Passes are separate IDs.
return {
	DataStoreName = "MogMode_Profiles_v1",
	StudioUseLiveDataStores = false, -- safe sandbox: no saving and no real purchases
	AutosaveSeconds = 40,
	LeaseSeconds = 180,
	ProductIds = {
		aura_small = 0,
		aura_medium = 0,
		aura_large = 0,
		flex_gems_small = 0,
		flex_gems_medium = 0,
		flex_gems_large = 0,
	},
	PassIds = { DoubleAura = 0, ExtraPets = 0, VIP = 0 },
}
