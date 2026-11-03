--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ObbyRun = require(script.Parent.ObbyRun)

local ObbyService = {}
ObbyService.__index = ObbyService

function ObbyService.new(config, store, engine, callbacks)
	local self = setmetatable({ Config = config, Store = store, Engine = engine, Callbacks = callbacks, Active = {}, Courses = {}, LastStart = {} }, ObbyService)
	local map = workspace:WaitForChild("MogWorld")
	for _, route in config.Obbies do
		local course = map[route.World].Obbies:WaitForChild(route.Id)
		self.Courses[route.Id] = course
		-- A course must work when discovered in the world, without opening a menu.
		course.Start.CanTouch = true
		course.Start.Touched:Connect(function(hit)
			local c = hit:FindFirstAncestorOfClass("Model")
			local player = c and Players:GetPlayerFromCharacter(c)
			if player and self:StandingOn(player, course.Start) then self:Start(player, route.Id, true) end
		end)
		local prize = course:WaitForChild("Finish")
		prize.CanTouch = true
		local claim = Instance.new("ProximityPrompt")
		claim.Name = "ClaimPrize"; claim.ActionText = "Collect prize"; claim.ObjectText = if route.PetReward then "Aura + XP + first-clear pet" else "Aura + XP"
		claim.MaxActivationDistance = 10; claim.RequiresLineOfSight = false; claim.HoldDuration = 0; claim.Parent = prize
		claim.Triggered:Connect(function(player)
			local ok, message = self:Claim(player, route.Id)
			if not ok and message then callbacks.Notice(player, message) end
		end)
		for _, platform in course.Steps:GetChildren() do
			local stage = tonumber(platform.Name)
			platform.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then self:Touch(player, route.Id, stage, platform) end
			end)
		end
		for _, hazard in course.Hazards:GetChildren() do
			hazard.Touched:Connect(function(hit)
				-- Accessories/arms must not punish a safe foot landing on a narrow ledge.
				local name = hit.Name
				if name ~= "HumanoidRootPart" and name ~= "LowerTorso" and name ~= "Torso" and name ~= "LeftFoot" and name ~= "RightFoot" and name ~= "Left Leg" and name ~= "Right Leg" then return end
				local c = hit:FindFirstAncestorOfClass("Model")
				local player = c and Players:GetPlayerFromCharacter(c)
				if player and self:IsNear(player, hazard, 7) then self:Reset(player) end
			end)
		end
		local sign = map[route.World].Markers:FindFirstChild("Course_" .. route.Id)
		if sign then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "View course"; prompt.ObjectText = route.Name
			prompt.MaxActivationDistance = 10; prompt.RequiresLineOfSight = false; prompt.Parent = sign
			prompt.Triggered:Connect(function(player)
				if self:IsNear(player, sign, 13) then callbacks.Open(player, route.Id) end
			end)
		end
	end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt; if accumulator < 0.1 then return end; accumulator = 0
		for _, player in Players:GetPlayers() do
			if not self.Active[player.UserId] then
				local status = store:Status(player.UserId)
				if status.Loaded then
					for _, route in config.Obbies do
						if route.World == status.World and self:StandingOn(player, self.Courses[route.Id].Start) then self:Start(player, route.Id, true); break end
					end
				end
			end
		end
		for id, run in self.Active do
			local player = Players:GetPlayerByUserId(id)
			local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not player then self.Active[id] = nil; continue end
			-- Touched can be missed after streaming or a temporary physics interruption.
			-- Poll only the next ordered landing; proximity to the prize cannot skip stages.
			if not run.Finished then
				local nextStep = self.Courses[run.Route.Id].Steps:FindFirstChild(string.format("%02d", run.Stage + 1))
				if nextStep and self:StandingOn(player, nextStep) then self:Touch(player, run.Route.Id, run.Stage + 1, nextStep) end
			end
			self:Drain(player)
			if os.clock() - run.StartedAt > 900 and not run.PendingFinish then self:Cancel(player); callbacks.Notice(player, "Course session expired. Start a fresh run."); continue end
			if root and not root.Anchored and not run.Finished then
				local course = self.Courses[run.Route.Id]
				local last = if run.Stage > 0 then course.Steps:FindFirstChild(string.format("%02d", run.Stage)) else course.Start
				if last and root.Position.Y < last.Position.Y - 9 then self:Reset(player) end
			end
		end
	end)
	return self
end

function ObbyService:IsNear(player, part, distance)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return root and not root.Anchored and h and h.Health > 0 and (root.Position - part.Position).Magnitude <= distance
end

function ObbyService:StandingOn(player, part)
	if not part or not self:IsNear(player, part, 14) then return false end
	local root = player.Character.HumanoidRootPart
	local offset = root.Position - part.Position
	local above = offset.Y - part.Size.Y / 2
	return math.abs(offset.X) <= part.Size.X / 2 + 0.8 and math.abs(offset.Z) <= part.Size.Z / 2 + 0.8 and above >= 0.5 and above <= 5.6
end

function ObbyService:Start(player, id, walkOn)
	local route = if type(id) == "string" then self.Engine.Obbies[id] else nil
	local p = self.Store:Get(player.UserId)
	local status = self.Store:Status(player.UserId)
	-- A save holds the mutable profile, but should not eat a physical entrance touch.
	-- CurrentWorld is server-owned and is always an unlocked island.
	local admitted = route and status.Loaded and status.World == route.World and (walkOn or (p and p.Worlds[route.World]))
	if not admitted then return false, "Travel to this course's island first." end
	if self.Active[player.UserId] and self.Active[player.UserId].PendingFinish then return false, "Your prize is saving. Let it finish before starting another route." end
	if walkOn and self.Active[player.UserId] then return false end
	local now = os.clock()
	if now - (self.LastStart[player.UserId] or -100) < 2 then return false, "Please wait a moment before restarting." end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not h or h.Health <= 0 or root.Anchored then return false, "Wait for your character to be ready." end
	self.LastStart[player.UserId] = now
	self.Active[player.UserId] = ObbyRun.new(route, now)
	self.Active[player.UserId].DeferredStages = {}
	local point = self.Courses[id].Start.Position + Vector3.new(0, 4, 0)
	if not walkOn then player.Character:PivotTo(CFrame.new(point)); root.AssemblyLinearVelocity = Vector3.zero end
	if self.Callbacks.Started then self.Callbacks.Started(player, route) end
	self.Callbacks.Changed(player)
	return true, route.Name .. " started. Touch every numbered platform in order."
end

function ObbyService:Claim(player, id)
	local route = self.Engine.Obbies[id]
	local course = route and self.Courses[id]
	if not course or not self:IsNear(player, course.Finish, 12) then return false, "Stand on the finish platform to collect." end
	local run = self.Active[player.UserId]
	if not run or run.Route.Id ~= id then return false, "Step onto START, then land on every numbered platform to earn this prize." end
	if os.clock() - (run.LastClaimAt or -100) < 2 then return false, "Your prize is being checked. One moment." end
	run.LastClaimAt = os.clock()
	if not run.Finished then
		local last = course.Steps:FindFirstChild(string.format("%02d", route.Count))
		if run.Stage == route.Count - 1 and self:StandingOn(player, last) then self:Touch(player, id, route.Count, last) end
		if not run.Finished then return false, "Route progress: " .. run.Stage .. "/" .. route.Count .. ". Land on every platform in order." end
		return true -- Touch already attempted delivery; do not bypass its save backoff.
	end
	if self.Active[player.UserId] ~= run then return true end -- automatic finish already committed
	run.RetryAt = 0
	self:Drain(player)
	return true
end

function ObbyService:Touch(player, id, stage, platform)
	local run = self.Active[player.UserId]
	if not run or run.Route.Id ~= id or run.Finished then return end
	local status = self.Store:Status(player.UserId)
	if not status.Loaded or status.World ~= run.Route.World then return end
	if not self:IsNear(player, platform, math.max(platform.Size.X, platform.Size.Z) * 0.75 + 5) then return end
	local ok, reason = ObbyRun.advance(run, stage, os.clock())
	if not ok then return end
	if reason == "complete" then
		run.PendingFinish = true
	elseif reason == "checkpoint" then
		table.insert(run.DeferredStages, stage)
	end
	self:Drain(player)
	self.Callbacks.Changed(player)
end

function ObbyService:Drain(player)
	local run = self.Active[player.UserId]
	if not run or run.Completing or os.clock() < (run.RetryAt or 0) then return end
	local p = self.Store:Get(player.UserId)
	if not p or p.CurrentWorld ~= run.Route.World then return end
	local ctx = self.Callbacks.Context(player)
	for _, stage in run.DeferredStages do
		local reward = self.Engine:CheckpointReward(p, run.Route.Id, stage, ctx)
		self.Callbacks.Reward(player, "Checkpoint", reward, run.Route)
	end
	run.DeferredStages = {}
	if not run.PendingFinish then return end
	run.Completing = true
	local committed, reward = self.Store:CommitMutation(player.UserId, function(nextData)
		return true, self.Engine:CompleteRoute(nextData, run.Route.Id, ctx)
	end)
	run.Completing = false
	if committed then
		if self.Active[player.UserId] == run then self.Active[player.UserId] = nil end
		self.Callbacks.Reward(player, "ObbyComplete", reward, run.Route)
	else
		-- Keep a verified finish intact. Standing still must not strand a player after
		-- a failed save; retry automatically with backoff, or from the prize prompt.
		run.RetryAt = os.clock() + 5
		if not run.SaveNotice then
			run.SaveNotice = true
			if self.Callbacks.Status then self.Callbacks.Status(player, "Your prize is ready. Saving is retrying automatically…")
			else self.Callbacks.Notice(player, "Your prize is ready. Saving is retrying automatically…") end
		end
	end
	self.Callbacks.Changed(player)
end

function ObbyService:Reset(player, force)
	local run = self.Active[player.UserId]
	if not run or run.Finished or run.Resetting or (not force and os.clock() - (run.LastReset or -100) < 1) then return false end
	local character = player.Character
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not h or h.Health <= 0 then return false end
	local course = self.Courses[run.Route.Id]
	local target = if run.Checkpoint > 0 then course.Steps:FindFirstChild(string.format("%02d", run.Checkpoint)) else course.Start
	run.Resetting = true
	if force then pcall(function() player:RequestStreamAroundAsync(target.Position, 5) end) end
	run.Resetting = false
	if self.Active[player.UserId] ~= run or player.Character ~= character or root.Parent == nil then return false end
	ObbyRun.reset(run, os.clock()); run.LastReset = os.clock()
	player.Character:PivotTo(CFrame.new(target.Position + Vector3.new(0, 4, 0)))
	root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
	self.Callbacks.Notice(player, "Back to checkpoint " .. run.Checkpoint .. ". Keep going.")
	self.Callbacks.Changed(player)
	return true
end

function ObbyService:View(player)
	local run = self.Active[player.UserId]
	return if run then { Id = run.Route.Id, Name = run.Route.Name, Stage = run.Stage, Count = run.Route.Count, Checkpoint = run.Checkpoint, RewardPending = run.PendingFinish == true } else nil
end

function ObbyService:Cancel(player)
	local run = self.Active[player.UserId]
	if run and run.PendingFinish then return false end
	self.Active[player.UserId] = nil
	return true
end

function ObbyService:Forget(player)
	self.Active[player.UserId] = nil; self.LastStart[player.UserId] = nil
end
return ObbyService
