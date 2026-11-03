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
		for id, run in self.Active do
			local player = Players:GetPlayerByUserId(id)
			local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not player then self.Active[id] = nil; continue end
			self:Drain(player)
			if os.clock() - run.StartedAt > 900 then self:Cancel(player); callbacks.Notice(player, "Course session expired. Start a fresh run."); continue end
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

function ObbyService:Start(player, id)
	local route = if type(id) == "string" then self.Engine.Obbies[id] else nil
	local p = self.Store:Get(player.UserId)
	if not route or not p or not p.Worlds[route.World] or p.CurrentWorld ~= route.World then return false, "Travel to this course's island first." end
	local now = os.clock()
	if now - (self.LastStart[player.UserId] or -100) < 2 then return false, "Please wait a moment before restarting." end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not h or h.Health <= 0 or root.Anchored then return false, "Wait for your character to be ready." end
	self.LastStart[player.UserId] = now
	self.Active[player.UserId] = ObbyRun.new(route, now)
	self.Active[player.UserId].DeferredStages = {}
	local point = self.Courses[id].Start.Position + Vector3.new(0, 4, 0)
	player.Character:PivotTo(CFrame.new(point)); root.AssemblyLinearVelocity = Vector3.zero
	self.Callbacks.Changed(player)
	return true, route.Name .. " started. Touch every numbered platform in order."
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
	if not run or run.Completing then return end
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
		run.Finished = false; run.PendingFinish = false; run.Stage = run.Route.Count - 1; run.LastAt = os.clock()
		self.Callbacks.Notice(player, "Reward save is unavailable. Step off and onto the finish to retry safely.")
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
	return if run then { Id = run.Route.Id, Name = run.Route.Name, Stage = run.Stage, Count = run.Route.Count, Checkpoint = run.Checkpoint } else nil
end

function ObbyService:Cancel(player)
	self.Active[player.UserId] = nil
end

function ObbyService:Forget(player)
	self.Active[player.UserId] = nil; self.LastStart[player.UserId] = nil
end
return ObbyService
