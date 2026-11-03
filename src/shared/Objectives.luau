--!strict
local Objectives = {}
function Objectives.get(profile: any, config: any, engine: any): any
	if profile.TotalClicks < 10 then
		return { Title = "Build your first Aura", Detail = "MOG for Aura, then use obbies for faster XP.", Panel = "Obbies", Progress = profile.TotalClicks / 10 }
	end
	if not profile.Obby.FirstClear.meadow_warmup then
		return { Title = "Beat the Warm-up Circuit", Detail = "12 ordered jumps. Your first Aura + XP payout.", Panel = "Obbies", Course = "meadow_warmup", Progress = 0 }
	end
	if profile.Upgrade < 2 then
		return { Title = "Upgrade Mog Power", Detail = "Raise Aura per click. Next upgrade: " .. engine:UpgradeCost(profile.Upgrade) .. " Aura.", Panel = "Upgrades", Progress = profile.Upgrade / 2 }
	end
	local highest = config.Worlds[1]
	for _, world in config.Worlds do if profile.Worlds[world.Id] then highest = world end end
	local hard = highest.Id .. "_sky"
	if not profile.Obby.FirstClear[hard] then
		return { Title = "Earn " .. engine.Pets[engine.Obbies[hard].PetReward].Name,
			Detail = "Clear Hop to the Top. This pet is earned, never bought.", Panel = "Obbies", Course = hard, Progress = 0 }
	end
	for _, world in config.Worlds do
		if not profile.Worlds[world.Id] then
			return { Title = "Discover " .. world.Name,
				Detail = "Reach Lv " .. world.Level .. " + " .. world.Cost .. " Aura. Courses are the main XP route.",
				Panel = "Worlds", Progress = math.min(1, profile.Level / world.Level, profile.Aura / world.Cost) }
		end
	end
	return { Title = "Start your next era", Detail = "Rebirth for a permanent bonus, then master every expert course.", Panel = "Upgrades", Progress = math.min(1, profile.Aura / engine:RebirthCost(profile.Rebirths)) }
end
return Objectives
