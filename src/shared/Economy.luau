--!strict
-- No Roblox services: all economic decisions are deterministic and CLI-testable.
local Economy = {}
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end
local function integer(value: any, fallback: number, maximum: number): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, maximum)
end
function Economy.new(config: any): any
	local engine: any = { Config = config, Clone = clone }
	local worlds, pets, cosmetics, products, quests, milestones, obbies = {}, {}, {}, {}, {}, {}, {}
	for i, world in config.Worlds do worlds[world.Id] = world; world.Index = i end
	for _, pet in config.Pets do pets[pet.Id] = pet end
	for _, cosmetic in config.Cosmetics do cosmetics[cosmetic.Id] = cosmetic end
	for _, product in config.Products do products[product.Key] = product end
	for _, quest in config.Quests do quests[quest.Id] = quest end
	for _, goal in config.Milestones do milestones[goal.Id] = goal end
	for _, route in config.Obbies do obbies[route.Id] = route end
	engine.Worlds, engine.Pets, engine.Cosmetics, engine.Products, engine.Obbies = worlds, pets, cosmetics, products, obbies
	function engine.NewProfile(self: any): any
		return {
			Version = config.SchemaVersion, Aura = 0, FlexGems = 0, TotalAura = 0, TotalClicks = 0,
			XP = 0, Level = 1, Upgrade = 0, Rebirths = 0, CurrentWorld = "meadow",
			Worlds = { meadow = true }, Pets = {}, Equipped = {}, Cosmetics = {},
			ActiveCosmetics = {}, Receipts = {}, Milestones = {},
			Daily = { Day = -1, Clicks = 0, Earned = 0, Collects = 0, Obbies = 0, Claimed = {} },
			Login = { FirstSeenAt = 0, LastClaimAt = 0, Claims = 0 },
			Obby = { FirstClear = {}, NextRewardAt = {}, StagePaidAt = {}, Clears = 0 },
			Boosts = { AuraUntil = 0, XPUntil = 0 },
			Settings = { SFX = true, Effects = true },
		}
	end
	function engine.XPRequired(_self: any, level: number): number return math.floor(config.XPBase * level ^ config.XPExponent) end
	function engine.UpgradeCost(_self: any, level: number): number return math.min(config.MaxCurrency, math.floor(config.UpgradeBase * config.UpgradeGrowth ^ level)) end
	function engine.RebirthCost(_self: any, count: number): number return math.min(config.MaxCurrency, math.floor(100_000 * 1.85 ^ count)) end
	function engine.Rank(_self: any, level: number): string
		local name = config.Ranks[1].Name
		for _, rank in config.Ranks do if level >= rank.Level then name = rank.Name end end
		return name
	end
	function engine.PetCost(_self: any, id: string, level: number): number return math.min(config.MaxCurrency, math.floor(pets[id].Cost * 1.8 ^ level)) end
	function engine.PetBonus(_self: any, id: string, level: number): number return pets[id].Bonus * (1 + (level - 1) * 0.25) end
	function engine.Normalize(self: any, raw: any): any
		if raw == nil then return self:NewProfile() end
		assert(type(raw) == "table", "Profile data is not a table")
		assert(raw.Version == 1 or raw.Version == config.SchemaVersion, "Unsupported profile version")
		assert(type(raw.FlexGems) == "number" and raw.FlexGems == raw.FlexGems and raw.FlexGems >= 0 and raw.FlexGems <= config.MaxCurrency and raw.FlexGems % 1 == 0, "Invalid paid balance")
		assert(type(raw.Receipts) == "table" and type(raw.Cosmetics) == "table", "Invalid paid entitlements")
		local p = self:NewProfile()
		for _, key in { "Aura", "FlexGems", "TotalAura", "TotalClicks" } do p[key] = integer(raw[key], 0, config.MaxCurrency) end
		p.Level = math.max(1, integer(raw.Level, 1, config.MaxLevel))
		p.XP = integer(raw.XP, 0, self:XPRequired(p.Level) - 1)
		p.Upgrade = integer(raw.Upgrade, 0, config.MaxUpgrade)
		p.Rebirths = integer(raw.Rebirths, 0, config.MaxRebirths)
		if type(raw.Worlds) == "table" then
			for _, world in config.Worlds do if raw.Worlds[world.Id] == true then p.Worlds[world.Id] = true end end
		end
		if type(raw.CurrentWorld) == "string" and p.Worlds[raw.CurrentWorld] then p.CurrentWorld = raw.CurrentWorld end
		if type(raw.Pets) == "table" then
			for id in pets do
				local level = integer(raw.Pets[id], 0, config.MaxPetLevel)
				if level > 0 then p.Pets[id] = level end
			end
		end
		if type(raw.Equipped) == "table" then
			local seen = {}
			for _, id in raw.Equipped do
				if type(id) == "string" and p.Pets[id] and not seen[id] and #p.Equipped < config.BaseEquipSlots + config.ExtraEquipSlots then
					table.insert(p.Equipped, id); seen[id] = true
				end
			end
		end
		if type(raw.Cosmetics) == "table" then
			for id, owned in raw.Cosmetics do
				assert(type(id) == "string" and #id <= 64 and owned == true, "Invalid cosmetic ownership")
				p.Cosmetics[id] = true
			end
		end
		if type(raw.ActiveCosmetics) == "table" then
			for _, kind in { "Trail", "Aura", "Title" } do
				local id = raw.ActiveCosmetics[kind]
				if type(id) == "string" and cosmetics[id] and cosmetics[id].Kind == kind and (p.Cosmetics[id] or cosmetics[id].Pass) then p.ActiveCosmetics[kind] = id end
			end
		end
		-- Never prune receipt IDs: a retry must never grant paid currency twice.
		if type(raw.Receipts) == "table" then
			for id, granted in raw.Receipts do
				assert(type(id) == "string" and #id > 0 and #id <= 160 and granted == true, "Invalid receipt ledger")
				p.Receipts[id] = true
			end
		end
		if type(raw.Daily) == "table" then
			p.Daily.Day = integer(raw.Daily.Day, 0, config.MaxCurrency)
			for _, key in { "Clicks", "Earned", "Collects", "Obbies" } do p.Daily[key] = integer(raw.Daily[key], 0, config.MaxCurrency) end
			if type(raw.Daily.Claimed) == "table" then
				for id in quests do if raw.Daily.Claimed[id] == true then p.Daily.Claimed[id] = true end end
			end
		end
		if type(raw.Settings) == "table" then
			for _, key in { "SFX", "Effects" } do if type(raw.Settings[key]) == "boolean" then p.Settings[key] = raw.Settings[key] end end
		end
		if type(raw.Milestones) == "table" then
			for id in milestones do if raw.Milestones[id] == true then p.Milestones[id] = true end end
		end
		if type(raw.Login) == "table" then
			for _, key in { "FirstSeenAt", "LastClaimAt", "Claims" } do p.Login[key] = integer(raw.Login[key], 0, config.MaxCurrency) end
		end
		if type(raw.Boosts) == "table" then
			for _, key in { "AuraUntil", "XPUntil" } do p.Boosts[key] = integer(raw.Boosts[key], 0, config.MaxCurrency) end
		end
		if type(raw.Obby) == "table" then
			p.Obby.Clears = integer(raw.Obby.Clears, 0, config.MaxCurrency)
			for id, route in obbies do
				if type(raw.Obby.FirstClear) == "table" and raw.Obby.FirstClear[id] == true then p.Obby.FirstClear[id] = true end
				if type(raw.Obby.NextRewardAt) == "table" then p.Obby.NextRewardAt[id] = integer(raw.Obby.NextRewardAt[id], 0, config.MaxCurrency) end
				if type(raw.Obby.StagePaidAt) == "table" then
					for stage = route.CheckpointEvery, route.Count - 1, route.CheckpointEvery do
						local key = id .. ":" .. stage
						p.Obby.StagePaidAt[key] = integer(raw.Obby.StagePaidAt[key], 0, config.MaxCurrency)
					end
				end
			end
		end
		return p
	end
	function engine.Initialize(self: any, p: any, now: number)
		if p.Login.FirstSeenAt <= 0 then p.Login.FirstSeenAt = now end
		self:RefreshDay(p, now)
	end
	function engine.RefreshDay(_self: any, p: any, now: number)
		local day = math.floor(now / 86400)
		if p.Daily.Day ~= day then p.Daily = { Day = day, Clicks = 0, Earned = 0, Collects = 0, Obbies = 0, Claimed = {} } end
	end
	function engine.EquipSlots(_self: any, context: any): number return config.BaseEquipSlots + (if context.Passes.ExtraPets then config.ExtraEquipSlots else 0) end
	function engine.PetMultiplier(self: any, p: any, context: any): number
		local bonus = 1
		for index, id in p.Equipped do
			if index <= self:EquipSlots(context) and p.Pets[id] then bonus += self:PetBonus(id, p.Pets[id]) end
		end
		return bonus
	end
	function engine.ClickValue(self: any, p: any, context: any): number
		local world = worlds[p.CurrentWorld] or worlds.meadow
		return math.min(config.MaxCurrency, math.max(1, math.floor((1 + p.Upgrade) * self:PetMultiplier(p, context) * world.Multiplier * (1 + 0.25 * p.Rebirths) * (if context.Passes.DoubleAura then 2 else 1) * (if p.Boosts.AuraUntil > context.Now then 2 else 1))))
	end
	local function addAura(p: any, amount: number)
		p.Aura = math.min(config.MaxCurrency, p.Aura + amount)
		p.TotalAura = math.min(config.MaxCurrency, p.TotalAura + amount)
		p.Daily.Earned = math.min(config.MaxCurrency, p.Daily.Earned + amount)
	end
	local function addXP(p: any, amount: number, now: number?): number
		local previous = p.Level
		p.XP += amount * (if now and p.Boosts.XPUntil > now then 2 else 1)
		while p.Level < config.MaxLevel and p.XP >= engine:XPRequired(p.Level) do
			p.XP -= engine:XPRequired(p.Level)
			p.Level += 1
			addAura(p, p.Level * 40)
		end
		if p.Level == config.MaxLevel then p.XP = math.min(p.XP, engine:XPRequired(p.Level) - 1) end
		return p.Level - previous
	end
	function engine.Click(self: any, p: any, context: any): any
		self:RefreshDay(p, context.Now)
		local amount = self:ClickValue(p, context)
		p.TotalClicks = math.min(config.MaxCurrency, p.TotalClicks + 1)
		p.Daily.Clicks = math.min(config.MaxCurrency, p.Daily.Clicks + 1)
		addAura(p, amount)
		return { Amount = amount, Levels = addXP(p, 1, context.Now), Burst = p.TotalClicks % config.BurstEvery == 0 and p.TotalClicks < config.MaxCurrency }
	end
	function engine.Collect(self: any, p: any, worldId: string, bonus: boolean, context: any): any
		assert(worlds[worldId] and p.Worlds[worldId] and p.CurrentWorld == worldId, "Locked crystal")
		self:RefreshDay(p, context.Now)
		local amount = math.min(config.MaxCurrency, self:ClickValue(p, context) * (if bonus then 12 else 8))
		addAura(p, amount)
		p.Daily.Collects = math.min(config.MaxCurrency, p.Daily.Collects + 1)
		return { Amount = amount, Levels = addXP(p, 2, context.Now) }
	end
	function engine.GrantProduct(_self: any, p: any, key: string, now: number?): boolean
		local product = products[key]
		if not product then return false end
		if product.Kind == "Boost" then
			if not now or now <= 0 then return false end
			local field = product.Boost .. "Until"
			p.Boosts[field] = math.max(now, p.Boosts[field]) + product.Seconds
			return true
		end
		if p[product.Currency] + product.Amount > config.MaxCurrency then return false end
		-- Purchased Aura do not count as earned Aura or quest progress.
		p[product.Currency] = math.min(config.MaxCurrency, p[product.Currency] + product.Amount)
		return true
	end
	function engine.LoginStatus(_self: any, p: any, now: number): any
		local nextAt = math.max(p.Login.FirstSeenAt + config.LoginInterval, p.Login.LastClaimAt + config.LoginInterval)
		local index = p.Login.Claims % #config.LoginRewards + 1
		return { Ready = p.Login.FirstSeenAt > 0 and now >= nextAt, NextAt = nextAt, Index = index, Aura = config.LoginRewards[index], Claims = p.Login.Claims }
	end
	function engine.CheckpointReward(self: any, p: any, id: string, stage: number, context: any): any
		local route = obbies[id]
		if not route or not p.Worlds[route.World] or p.CurrentWorld ~= route.World or stage <= 0 or stage >= route.Count or stage % route.CheckpointEvery ~= 0 then return { Amount = 0, Levels = 0 } end
		local key = id .. ":" .. stage
		if (p.Obby.StagePaidAt[key] or 0) > context.Now then return { Amount = 0, Levels = 0 } end
		p.Obby.StagePaidAt[key] = context.Now + config.ObbyRewardCooldown
		self:RefreshDay(p, context.Now); addAura(p, route.CheckpointAura)
		return { Amount = route.CheckpointAura, XP = 5 * (if p.Boosts.XPUntil > context.Now then 2 else 1), Levels = addXP(p, 5, context.Now) }
	end
	function engine.CompleteRoute(self: any, p: any, id: string, context: any): any
		local route = obbies[id]
		assert(route and p.Worlds[route.World] and p.CurrentWorld == route.World, "Invalid course completion")
		self:RefreshDay(p, context.Now)
		local first = not p.Obby.FirstClear[id]
		if not first and (p.Obby.NextRewardAt[id] or 0) > context.Now then return { Practice = true, Amount = 0, Levels = 0 } end
		p.Obby.FirstClear[id] = true; p.Obby.NextRewardAt[id] = context.Now + config.ObbyRewardCooldown
		p.Obby.Clears = math.min(config.MaxCurrency, p.Obby.Clears + 1); p.Daily.Obbies += 1
		local amount = if first then route.FirstAura else route.RepeatAura
		addAura(p, amount)
		local pet = nil
		if first and route.PetReward and not p.Pets[route.PetReward] then
			pet = route.PetReward; p.Pets[pet] = 1
			if #p.Equipped < self:EquipSlots(context) then table.insert(p.Equipped, pet) end
		end
		local xp = if first then route.FirstXP else route.RepeatXP
		return { Amount = amount, XP = xp * (if p.Boosts.XPUntil > context.Now then 2 else 1), Levels = addXP(p, xp, context.Now), First = first, Pet = pet, Practice = false }
	end
	function engine.MilestoneProgress(_self: any, p: any, id: string): number
		local goal = milestones[id]
		if not goal then return 0 end
		if goal.Metric == "ObbyClears" then return p.Obby.Clears end
		if goal.Metric == "Pets" or goal.Metric == "PetLevels" then
			local count = 0; for _, level in p.Pets do count += if goal.Metric == "Pets" then 1 else level end; return count
		elseif goal.Metric == "Worlds" then
			local count = 0; for _, owned in p.Worlds do if owned then count += 1 end end; return count
		end
		return p[goal.Metric] or 0
	end
	function engine.Apply(self: any, p: any, action: any, payload: any, context: any): (boolean, string)
		self:RefreshDay(p, context.Now)
		if type(action) ~= "string" or type(payload) ~= "table" then return false, "Invalid request." end
		local id = payload.Id
		if action == "BuyUpgrade" then
			if p.Upgrade >= config.MaxUpgrade then return false, "Click power is fully upgraded!" end
			local cost = self:UpgradeCost(p.Upgrade)
			if p.Aura < cost then return false, "Earn more Aura for this upgrade." end
			p.Aura -= cost; p.Upgrade += 1
			return true, "Click power upgraded!"
		elseif action == "EquipBest" then
			local owned: {string} = {}
			for petId, level in p.Pets do if pets[petId] and level > 0 then table.insert(owned, petId) end end
			if #owned == 0 then return false, "Earn or adopt a pet first." end
			table.sort(owned, function(a: string, b: string): boolean
				local av, bv = self:PetBonus(a, p.Pets[a]), self:PetBonus(b, p.Pets[b])
				return if av == bv then a < b else av > bv
			end)
			p.Equipped = {}
			for i = 1, math.min(#owned, self:EquipSlots(context)) do table.insert(p.Equipped, owned[i]) end
			return true, "Strongest squad equipped. Certified Aura upgrade."
		elseif action == "BuyPet" then
			local pet = if type(id) == "string" then pets[id] else nil
			if not pet then return false, "That pet does not exist." end
			if not p.Worlds[pet.World] then return false, "Discover this pet's island first." end
			local level = p.Pets[id] or 0
			if level == 0 and pet.ObbyOnly then return false, "Earn this pet by completing " .. obbies[pet.ObbyOnly].Name .. "." end
			if level >= config.MaxPetLevel then return false, "This pet is at its highest level!" end
			local cost = self:PetCost(id, level)
			if p.Aura < cost then return false, "Earn more Aura to adopt or train this pet." end
			p.Aura -= cost; p.Pets[id] = level + 1
			if level == 0 and #p.Equipped < self:EquipSlots(context) then table.insert(p.Equipped, id) end
			return true, if level == 0 then pet.Name .. " joined your party!" else pet.Name .. " reached level " .. tostring(level + 1) .. "!"
		elseif action == "EquipPet" then
			if type(id) ~= "string" or not p.Pets[id] then return false, "Adopt that pet first." end
			local index = table.find(p.Equipped, id)
			if index then table.remove(p.Equipped, index); return true, "Pet is resting." end
			if #p.Equipped >= self:EquipSlots(context) then return false, "Rest a pet to make room in your party." end
			table.insert(p.Equipped, id); return true, "Pet equipped!"
		elseif action == "UnlockWorld" then
			local world = if type(id) == "string" then worlds[id] else nil
			if not world then return false, "That island does not exist." end
			if p.Worlds[id] then return false, "You've already discovered this island." end
			local previous = config.Worlds[world.Index - 1]
			if not previous or not p.Worlds[previous.Id] then return false, "Discover the previous island first." end
			if p.Level < world.Level then return false, "Reach level " .. world.Level .. " first." end
			if p.Aura < world.Cost then return false, "Earn more Aura to discover this island." end
			p.Aura -= world.Cost; p.Worlds[id] = true
			return true, world.Name .. " discovered!"
		elseif action == "Rebirth" then
			if p.Rebirths >= config.MaxRebirths then return false, "You've reached the rebirth summit!" end
			if p.Aura < self:RebirthCost(p.Rebirths) then return false, "Earn more Aura before rebirthing." end
			p.Aura = 0; p.Upgrade = 0; p.Rebirths += 1
			return true, "Reborn! Your permanent click bonus is now +" .. tostring(p.Rebirths * 25) .. "%."
		elseif action == "ClaimQuest" then
			local quest = if type(id) == "string" then quests[id] else nil
			if not quest then return false, "That goal does not exist." end
			if p.Daily.Claimed[id] then return false, "You've already collected this reward today." end
			if p.Daily[quest.Counter] < quest.Target then return false, "Keep exploring to finish this goal." end
			p.Daily.Claimed[id] = true
			addAura(p, quest.Aura); addXP(p, quest.XP, context.Now)
			return true, "Goal complete! Aura and XP collected."
		elseif action == "ClaimMilestone" then
			local goal = if type(id) == "string" then milestones[id] else nil
			if not goal then return false, "Unknown journal stamp." end
			if p.Milestones[id] then return false, "Already collected." end
			if self:MilestoneProgress(p, id) < goal.Target then return false, "Keep exploring to finish this stamp." end
			p.Milestones[id] = true; addAura(p, goal.Aura); addXP(p, goal.XP, context.Now)
			if goal.Cosmetic then p.Cosmetics[goal.Cosmetic] = true; p.ActiveCosmetics.Title = goal.Cosmetic end
			return true, "Journal reward collected!"
		elseif action == "ClaimLogin" then
			local status = self:LoginStatus(p, context.Now)
			if not status.Ready then return false, "The first login reward unlocks after 24 hours. Return when the timer is ready." end
			p.Login.LastClaimAt = context.Now; p.Login.Claims += 1
			addAura(p, status.Aura); addXP(p, 40, context.Now)
			return true, "Welcome back! " .. tostring(status.Aura) .. " Aura collected."
		elseif action == "BuyCosmetic" or action == "EquipCosmetic" then
			local item = if type(id) == "string" then cosmetics[id] else nil
			if not item then return false, "That cosmetic does not exist." end
			local owned = p.Cosmetics[id] or (item.Pass and context.Passes[item.Pass])
			if action == "BuyCosmetic" then
				if owned then return false, "You already own this cosmetic." end
				if item.Pass then return false, "This cosmetic is included with Mog Patron." end
				if item.Earned then return false, "Earn this free title in the discovery journal." end
				if p.FlexGems < item.Cost then return false, "This cosmetic costs FlexGems, the paid cosmetic currency." end
				p.FlexGems -= item.Cost; p.Cosmetics[id] = true; p.ActiveCosmetics[item.Kind] = id
				return true, item.Name .. " equipped!"
			end
			if not owned then return false, "You don't own this cosmetic." end
			p.ActiveCosmetics[item.Kind] = if p.ActiveCosmetics[item.Kind] == id then nil else id
			return true, "Style updated!"
		elseif action == "Setting" then
			if (id ~= "SFX" and id ~= "Effects") or type(payload.Value) ~= "boolean" then return false, "Invalid setting." end
			p.Settings[id] = payload.Value; return true, "Settings saved."
		end
		return false, "Unknown action."
	end
	return engine
end
return Economy
