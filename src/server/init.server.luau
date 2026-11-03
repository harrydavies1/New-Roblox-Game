--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local shared = ReplicatedStorage:WaitForChild("MogShared")
local Config = require(shared.Config)
local Engine = require(shared.Economy).new(Config)
local Objectives = require(shared.Objectives)
local Settings = require(script.ServerSettings)
local RateLimiter = require(script.RateLimiter)
local WorldService = require(script.WorldService)
local ObbyService = require(script.ObbyService)
local Commerce = require(script.Commerce)
local store, storage = require(script.Storage).create(Settings, Engine)

local remotes = Instance.new("Folder")
remotes.Name = "MogRemotes"
remotes.Parent = ReplicatedStorage
local function remote(class, name)
	local item = Instance.new(class)
	item.Name = name
	item.Parent = remotes
	return item
end
local action = remote("RemoteFunction", "Action")
local click = remote("RemoteEvent", "Click")
local stateRemote = remote("RemoteEvent", "State")
local effects = remote("RemoteEvent", "Effect")
local clickLimit = RateLimiter.new(Config.ClickRate, Config.ClickBurst)
local actionLimit = RateLimiter.new(3, 6)
local stateLimit = RateLimiter.new(0.5, 3)
local promptLimit = RateLimiter.new(3, 5)
local saveLimit = RateLimiter.new(0.1, 1)
local runtime, loading = {}, {}
local worldService, obbies, commerce
local closing = false

local function context(player)
	return { Now = os.time(), Passes = if commerce then commerce:GetPasses(player) else {} }
end
local function sendEffect(player, data)
	if player.Parent then effects:FireClient(player, data) end
end
local function appearance(player, profile)
	local ctx = context(player)
	local party = {}
	for index, id in profile.Equipped do
		if index <= Engine:EquipSlots(ctx) then table.insert(party, { Id = id, Level = profile.Pets[id] }) end
	end
	player:SetAttribute("MogPets", HttpService:JSONEncode(party))
	for _, kind in { "Trail", "Aura", "Title" } do
		local id = profile.ActiveCosmetics[kind]
		local item = id and Engine.Cosmetics[id]
		player:SetAttribute("Mog" .. kind, if item and (profile.Cosmetics[id] or (item.Pass and ctx.Passes[item.Pass])) then id else "")
	end
	player:SetAttribute("MogPatron", ctx.Passes.VIP == true)
	player:SetAttribute("MogRank", Engine:Rank(profile.Level))
end
local function snapshot(player)
	local profile = store:Get(player.UserId)
	if not profile then return nil end
	Engine:RefreshDay(profile, os.time())
	local view = Engine.Clone(profile)
	local ctx = context(player)
	local rt = runtime[player.UserId]
	view.Receipts = nil
	view.ClickValue = Engine:ClickValue(profile, ctx)
	view.XPRequired = Engine:XPRequired(profile.Level)
	view.UpgradeCost = Engine:UpgradeCost(profile.Upgrade)
	view.RebirthCost = Engine:RebirthCost(profile.Rebirths)
	view.EquipSlots = Engine:EquipSlots(ctx)
	view.PetMultiplier = Engine:PetMultiplier(profile, ctx)
	view.Passes = Engine.Clone(ctx.Passes)
	view.Catalog = Engine.Clone(if commerce then commerce.Catalog else {})
	view.Sandbox = not storage.Persistent
	view.ServerTime = os.time()
	view.LoginStatus = Engine:LoginStatus(profile, view.ServerTime)
	view.Objective = Objectives.get(profile, Config, Engine)
	view.ObbyRun = if obbies then obbies:View(player) else nil
	local status = store:Status(player.UserId)
	view.Save = { Persistent = storage.Persistent, LastSavedAt = status.LastSavedAt,
		State = if not storage.Persistent then "preview" elseif rt and rt.Saving then "saving" elseif rt and rt.SaveError then "retry" elseif rt and rt.Unsaved then "pending" else "saved" }
	return view
end
local function push(player)
	if not player.Parent then return end
	local view = snapshot(player)
	if not view then return end
	stateRemote:FireClient(player, view)
	local stats = player:FindFirstChild("leaderstats")
	if stats then stats.Level.Value = view.Level; stats.Rebirths.Value = view.Rebirths end
end
local function changed(player, unsaved)
	local rt = runtime[player.UserId]
	if rt then rt.Dirty = true; if unsaved then rt.Unsaved = true end end
	local profile = store:Get(player.UserId)
	if profile then appearance(player, profile); push(player) end
end
local function savePlayer(player, release)
	local rt = runtime[player.UserId]
	if rt then rt.Saving = true end
	sendEffect(player, { Kind = "SaveStatus", State = if storage.Persistent then "saving" else "preview" })
	local ok, reason = store:Save(player.UserId, release)
	if rt then
		rt.Saving = false
		if ok then rt.Unsaved = false; rt.SaveError = false
		elseif reason ~= "busy" and reason ~= "not_loaded" then rt.SaveError = true end
	end
	if not release then changed(player, false) end
	return ok, reason
end
local function warp(player, id, force)
	local profile = store:Get(player.UserId)
	local rt = runtime[player.UserId]
	if not profile or not rt or not Engine.Worlds[id] or not profile.Worlds[id] then return false, "Discover this island first." end
	if rt.Travelling or (not force and os.clock() - rt.LastTeleport < 2) then return false, "Your portal is recharging." end
	rt.Travelling = true
	rt.LastTeleport = os.clock()
	-- Change world before the streaming yield; never keep a mutable profile across it.
	profile.CurrentWorld = id
	rt.Unsaved = true
	if obbies then obbies:Cancel(player) end
	sendEffect(player, { Kind = "TravelStart", Message = "Travelling to " .. Engine.Worlds[id].Name })
	local ok = worldService:Teleport(player, id)
	rt.Travelling = false
	changed(player, true)
	return ok, if ok then "Welcome to " .. Engine.Worlds[id].Name .. "!" else "Wait for your character to respawn."
end

worldService = WorldService.new(Config, {
	Collect = function(player, id, crystal)
		if not promptLimit:Allow(player.UserId, os.clock()) then return end
		local profile = store:Get(player.UserId)
		local rt = runtime[player.UserId]
		if not profile or not rt or rt.Travelling or profile.CurrentWorld ~= id or not profile.Worlds[id] then return end
		local key = crystal:GetAttribute("CrystalId")
		local now = os.clock()
		if (rt.Crystals[key] or 0) > now then return end
		rt.Crystals[key] = now + Config.ShardCooldown
		local result = Engine:Collect(profile, id, false, context(player))
		sendEffect(player, { Kind = "Crystal", Id = key, Amount = result.Amount, Cooldown = Config.ShardCooldown })
		changed(player, true)
	end,
	Portal = function(player, id)
		if not promptLimit:Allow(player.UserId, os.clock()) then return end
		local profile = store:Get(player.UserId)
		if profile and profile.Worlds[id] then
			local ok, message = warp(player, id)
			sendEffect(player, { Kind = if ok then "Travel" else "Notice", Message = message })
		else sendEffect(player, { Kind = "OpenPanel", Panel = "Worlds" }) end
	end,
	OpenPanel = function(player, panel)
		if promptLimit:Allow(player.UserId, os.clock()) then sendEffect(player, { Kind = "OpenPanel", Panel = panel }) end
	end,
})
obbies = ObbyService.new(Config, store, Engine, {
	Context = context,
	Changed = function(player) changed(player, false) end,
	Open = function(player, id) sendEffect(player, { Kind = "OpenCourse", Id = id }) end,
	Notice = function(player, message) sendEffect(player, { Kind = "ObbyReset", Message = message }) end,
	Reward = function(player, kind, reward, route)
		local rt = runtime[player.UserId]
		if rt then
			if kind == "ObbyComplete" then rt.Unsaved = false; rt.SaveError = false
			elseif reward.Amount > 0 then rt.Unsaved = true end
		end
		sendEffect(player, { Kind = kind, Amount = reward.Amount, Pet = reward.Pet, First = reward.First, Practice = reward.Practice, Course = route.Name })
		changed(player, false)
	end,
})
commerce = Commerce.new(Config, Settings, store, Engine, not storage.PurchasesAllowed, {
	Changed = function(player) changed(player, false) end,
	Purchased = function(player, key)
		local rt = runtime[player.UserId]
		if rt then rt.Unsaved = false end
		changed(player, false)
		sendEffect(player, { Kind = "Purchase", Message = Engine.Products[key].Name .. " delivered." })
	end,
	CatalogReady = function() for _, player in Players:GetPlayers() do push(player) end end,
})

action.OnServerInvoke = function(player, name, payload)
	if closing then return { Ok = false, Message = "Server is saving. Please rejoin shortly." } end
	if type(name) ~= "string" or #name > 32 then return { Ok = false, Message = "Invalid request." } end
	if name == "GetState" then
		if not stateLimit:Allow(player.UserId, os.clock()) then return { Ok = false, Message = "Please wait." } end
		local view = snapshot(player)
		return { Ok = view ~= nil, State = view }
	end
	if not actionLimit:Allow(player.UserId, os.clock()) then return { Ok = false, Message = "A little slower, please." } end
	if type(payload) ~= "table" then return { Ok = false, Message = "Invalid request." } end
	local safe = {}
	if type(payload.Id) == "string" and #payload.Id <= 60 then safe.Id = payload.Id end
	if type(payload.Value) == "boolean" then safe.Value = payload.Value end
	local profile, reason = store:Get(player.UserId)
	if not profile then return { Ok = false, Message = if reason == "busy" then "Saving your progress. Try again in a moment." else "Your adventure is loading." } end
	local ok, message
	if name == "Purchase" then ok, message = commerce:Prompt(player, safe.Id)
	elseif name == "Travel" then ok, message = warp(player, safe.Id)
	elseif name == "StartObby" then ok, message = obbies:Start(player, safe.Id)
	elseif name == "LeaveObby" then obbies:Cancel(player); ok, message = warp(player, profile.CurrentWorld, true)
	elseif name == "RetryObby" then ok = obbies:Reset(player, true); message = if ok then "Returned to your checkpoint." else "Start a course first."
	elseif name == "SaveNow" then
		if not saveLimit:Allow(player.UserId, os.clock()) then return { Ok = false, Message = "Your progress saves automatically; wait a moment before saving again." } end
		ok, reason = savePlayer(player)
		message = if not storage.Persistent then "Preview mode: enable Studio API access or publish to save between sessions." elseif ok then "Progress saved." else "Save is retrying. Keep this session open."
	elseif name == "ClaimLogin" then
		if not storage.Persistent then
			ok, message = false, "Daily login rewards require persistent saving. Enable Studio API access or play the published experience."
		else
			ok, message = store:CommitMutation(player.UserId, function(nextData) return Engine:Apply(nextData, name, safe, context(player)) end)
			if ok then
				local rt = runtime[player.UserId]
				if rt then rt.Unsaved = false; rt.SaveError = false end
				changed(player, false)
			end
		end
	else
		ok, message = Engine:Apply(profile, name, safe, context(player))
		if ok then
			changed(player, true)
			if name == "UnlockWorld" then warp(player, safe.Id, true) end
		end
	end
	return { Ok = ok, Message = message, State = snapshot(player) }
end
click.OnServerEvent:Connect(function(player)
	if closing or not clickLimit:Allow(player.UserId, os.clock()) then return end
	local profile = store:Get(player.UserId)
	local rt = runtime[player.UserId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not profile or not rt or rt.Travelling or not root or root.Anchored or not humanoid or humanoid.Health <= 0 then return end
	local result = Engine:Click(profile, context(player))
	rt.Dirty = true; rt.Unsaved = true; rt.PendingAura += result.Amount; rt.PendingClicks += 1
	if result.Levels > 0 then appearance(player, profile) end
	if result.Burst then effects:FireAllClients({ Kind = "Mog", UserId = player.UserId }) end
end)

local function release(player)
	local deadline = os.clock() + 20
	repeat
		local ok, reason = savePlayer(player, true)
		if ok or reason == "not_loaded" then return end
		task.wait(if reason == "busy" then 0.2 else 1)
	until os.clock() >= deadline
	warn("MOG profile release deferred until lease expiry", player.UserId)
end
local function joined(player)
	if closing then player:Kick("This server is closing. Please join another."); return end
	if loading[player.UserId] or runtime[player.UserId] then return end
	loading[player.UserId] = true
	local profile, reason
	for attempt = 1, 4 do
		profile, reason = store:Load(player.UserId)
		if profile then break end
		if not player.Parent then return end
		task.wait(attempt * 1.5)
	end
	if not profile then player:Kick("We couldn't safely load your progress (" .. tostring(reason) .. "). Please rejoin in a minute. Saved data was not replaced."); return end
	if not player.Parent or closing then release(player); return end
	runtime[player.UserId] = { Dirty = true, Unsaved = false, Saving = false, SaveError = false, PendingAura = 0, PendingClicks = 0, Crystals = {}, LastTeleport = -100 }
	local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
	for _, name in { "Level", "Rebirths" } do local stat = Instance.new("IntValue"); stat.Name = name; stat.Parent = stats end
	local function characterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not root or not player.Parent then return end
		humanoid.WalkSpeed = 18; humanoid.UseJumpPower = true; humanoid.JumpPower = 50
		local current = store:Get(player.UserId)
		worldService:Teleport(player, if current then current.CurrentWorld else "meadow")
		if obbies:View(player) then obbies:Reset(player, true) end
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then task.spawn(characterAdded, player.Character) end
	changed(player, false)
	task.spawn(function() commerce:RefreshPasses(player); changed(player, false) end)
end
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do task.spawn(joined, player) end
Players.PlayerRemoving:Connect(function(player)
	release(player)
	runtime[player.UserId] = nil; loading[player.UserId] = nil; obbies:Forget(player)
	for _, limiter in { clickLimit, actionLimit, stateLimit, promptLimit, saveLimit } do limiter:Forget(player.UserId) end
	commerce:Forget(player)
end)
task.spawn(function()
	while not closing do
		task.wait(0.2)
		for _, player in Players:GetPlayers() do
			local rt = runtime[player.UserId]
			if rt and rt.Dirty and store:Get(player.UserId) then
				rt.Dirty = false; push(player)
				if rt.PendingClicks > 0 then
					sendEffect(player, { Kind = "Clicks", Amount = rt.PendingAura, Count = rt.PendingClicks })
					rt.PendingAura = 0; rt.PendingClicks = 0
				end
			end
		end
	end
end)
task.spawn(function()
	while not closing do
		task.wait(Settings.AutosaveSeconds)
		for _, player in Players:GetPlayers() do task.spawn(function()
			local ok, reason = savePlayer(player)
			if not ok and reason ~= "busy" and reason ~= "not_loaded" then warn("MOG autosave failed", reason) end
		end) end
	end
end)
task.spawn(function()
	while not closing do
		task.wait(2)
		for _, player in Players:GetPlayers() do
			local profile, reason = store:Get(player.UserId)
			if reason == "session_expired" then player:Kick("Your save session disconnected. Please rejoin to protect your progress.") end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if profile and root and root.Position.Y < -30 and not obbies:View(player) then worldService:Teleport(player, profile.CurrentWorld) end
		end
	end
end)
game:BindToClose(function()
	closing = true
	local remaining = 0
	for _, player in Players:GetPlayers() do remaining += 1; task.spawn(function() release(player); remaining -= 1 end) end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
end)
