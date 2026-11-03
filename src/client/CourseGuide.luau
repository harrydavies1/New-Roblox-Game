--!nonstrict
-- Personal course guidance. The server alone accepts landings and grants prizes.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CourseGuide = {}
function CourseGuide.new(config, engine, getState)
	local map = workspace:WaitForChild("MogWorld")
	local folder = Instance.new("Folder"); folder.Name = "MogCourseGuide"; folder.Parent = workspace
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "NextLanding"; arrow.Size = UDim2.fromOffset(92, 48); arrow.MaxDistance = 85
	arrow.StudsOffset = Vector3.new(0, 3, 0); arrow.AlwaysOnTop = false; arrow.Enabled = false; arrow.Parent = folder
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1); text.BackgroundTransparency = 1; text.Font = Enum.Font.FredokaOne
	text.TextSize = 14; text.TextColor3 = Color3.fromRGB(255, 219, 112); text.TextStrokeColor3 = Color3.fromRGB(43, 38, 61); text.TextStrokeTransparency = .05; text.Parent = arrow
	local outline = Instance.new("Highlight")
	outline.Name = "NextStepOutline"; outline.FillTransparency = 1; outline.OutlineTransparency = .1
	outline.OutlineColor = Color3.fromRGB(255, 218, 102); outline.DepthMode = Enum.HighlightDepthMode.Occluded; outline.Enabled = false; outline.Parent = folder
	local self = { Arrow = arrow, Outline = outline, Text = text, ClearedUntil = 0 }
	function self:Course(id)
		local route = engine.Obbies[id]
		local island = route and map:FindFirstChild(route.World)
		local courses = island and island:FindFirstChild("Obbies")
		return courses and courses:FindFirstChild(id)
	end
	function self:Update()
		local state = getState()
		local id = state and ((state.ObbyRun and state.ObbyRun.Id) or (state.Objective and state.Objective.Course))
		local route = id and engine.Obbies[id]
		local course = route and state.CurrentWorld == route.World and self:Course(id)
		local target
		if course then
			local run = state.ObbyRun
			if not run then target = course:FindFirstChild("Start"); text.Text = "▼ START"
			elseif run.RewardPending then target = course:FindFirstChild("Finish"); text.Text = "▼ PRIZE READY"
			else
				local steps = course:FindFirstChild("Steps")
				target = steps and steps:FindFirstChild(string.format("%02d", run.Stage + 1))
				text.Text = "▼ NEXT " .. (run.Stage + 1) .. "/" .. run.Count
			end
		end
		local visible = target ~= nil and os.clock() >= self.ClearedUntil
		arrow.Enabled = visible; outline.Enabled = visible
		arrow.Adornee = if visible then target else nil; outline.Adornee = if visible then target else nil
		arrow.StudsOffset = Vector3.new(0, 3 + (if state and state.Settings.Effects then math.sin(os.clock() * 3) * .15 else 0), 0)
		if not state then return end
		for _, spec in config.Obbies do
			if spec.World ~= state.CurrentWorld then continue end
			local current = self:Course(spec.Id)
			local finish = current and current:FindFirstChild("Finish")
			local prompt = finish and finish:FindFirstChild("ClaimPrize")
			local active = state.ObbyRun and state.ObbyRun.Id == spec.Id
			local cleared = state.Obby.FirstClear[spec.Id]
			if prompt then
				prompt.Enabled = active == true or not cleared
				prompt.ActionText = if active and state.ObbyRun.RewardPending then "Retry prize save" elseif active then "Collect prize" else "Finish this route first"
			end
			local sign = finish and finish:FindFirstChild("CourseSign")
			local caption = sign and sign:FindFirstChild("Label")
			if caption then
				caption.Text = if active and state.ObbyRun.RewardPending then "PRIZE READY\nSaving automatically…" elseif cleared then "PRIZE COLLECTED\nReplay from START" elseif spec.PetReward then "FIRST-CLEAR PET\n" .. engine.Pets[spec.PetReward].Name else "BIG W!\nAura + XP prize"
			end
		end
	end
	function self:Celebrate(id)
		self.ClearedUntil = os.clock() + 2
		local course = self:Course(id)
		local lid = course and course:FindFirstChild("ChestLid")
		if not lid then return end
		local base = lid.CFrame
		TweenService:Create(lid, TweenInfo.new(.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = base * CFrame.new(0, .8, 0) * CFrame.Angles(math.rad(-22), 0, 0) }):Play()
		task.delay(1.5, function() if lid.Parent then TweenService:Create(lid, TweenInfo.new(.2), { CFrame = base }):Play() end end)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt) elapsed += dt; if elapsed >= .1 then elapsed = 0; self:Update() end end)
	return self
end
return CourseGuide
