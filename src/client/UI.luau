--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Menu = require(script.Parent.Menu)
local MenuIcons = require(script.Parent.MenuIcons)

local UI = {}
local Theme = {
	Background = Color3.fromRGB(255, 248, 230),
	Surface = Color3.fromRGB(255, 253, 246),
	Raised = Color3.fromRGB(235, 232, 218),
	Line = Color3.fromRGB(43, 38, 61),
	Text = Color3.fromRGB(43, 38, 61),
	Secondary = Color3.fromRGB(93, 85, 102),
	Accent = Color3.fromRGB(174, 223, 104),
	AccentInk = Color3.fromRGB(43, 38, 61),
	Gold = Color3.fromRGB(255, 196, 64),
	Purple = Color3.fromRGB(198, 159, 245),
	Blue = Color3.fromRGB(125, 199, 241),
	Danger = Color3.fromRGB(241, 145, 137),
	Ink = Color3.fromRGB(43, 38, 61),
}
local function create(class, properties, parent)
	local item = Instance.new(class)
	for key, value in properties do item[key] = value end
	item.Parent = parent
	return item
end
local function round(item, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 11) }, item)
end
local function outline(item, thickness)
	create("UIStroke", { Color = Theme.Ink, Thickness = thickness or 2, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, item)
end
local function label(parent, value, size, position, dimensions, color, bold)
	return create("TextLabel", {
		BackgroundTransparency = 1, Text = value, TextSize = size, TextColor3 = color or Theme.Text,
		Font = if bold and size >= 11 then Enum.Font.FredokaOne elseif bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Position = position, Size = dimensions,
	}, parent)
end
local function styledButton(parent, value, position, dimensions, primary, callback)
	local item = create("TextButton", {
		Text = value, TextSize = 13, Font = Enum.Font.FredokaOne,
		TextColor3 = if primary then Theme.AccentInk else Theme.Text,
		BackgroundColor3 = if primary then Theme.Accent else Theme.Raised,
		Position = position, Size = dimensions, BorderSizePixel = 0, AutoButtonColor = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, parent)
	round(item, 10); outline(item)
	local scale = create("UIScale", { Scale = 1 }, item)
	item.Activated:Connect(function()
		if not item.Active or not item.Interactable then return end
		scale.Scale = 0.97
		TweenService:Create(scale, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		callback()
	end)
	return item
end
local function progress(parent, position, dimensions, color)
	local track = create("Frame", { Position = position, Size = dimensions, BackgroundColor3 = Theme.Line, BorderSizePixel = 0, ClipsDescendants = true }, parent)
	round(track, 2)
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or Theme.Accent, BorderSizePixel = 0 }, track)
	round(fill, 2)
	return fill
end
local function timeLeft(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then return string.format("%dh %dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
	return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
end

function UI.new(config, engine, format, callbacks)
	local function button(parent, value, position, dimensions, primary, callback, quiet)
		return styledButton(parent, value, position, dimensions, primary, function()
			if not quiet then callbacks.Feedback("Panel") end
			callback()
		end)
	end
	local self = {
		State = nil, Panel = nil, Bindings = {}, Tab = "Boosts", PetWorld = "meadow", GoalsTab = "Daily",
		CourseWorld = "meadow", SelectedCourse = nil, Pending = false, ToastId = 0, ReceivedAt = 0,
	}
	local screen = create("ScreenGui", { Name = "MogHUD", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10 }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.Screen = screen
	local root = create("Frame", { Name = "SafeArea", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen)
	local counters = create("Frame", { Name = "Counters", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(326, 47), BackgroundColor3 = Theme.Background, BorderSizePixel = 0, ClipsDescendants = true }, root)
	round(counters, 11); outline(counters, 2.5)
	for _, section in { { 0, .45, Color3.fromRGB(255, 232, 163) }, { .45, .31, Color3.fromRGB(232, 214, 253) }, { .76, .24, Color3.fromRGB(204, 232, 252) } } do
		create("Frame", { Position = UDim2.fromScale(section[1], 0), Size = UDim2.fromScale(section[2], 1), BackgroundColor3 = section[3], BorderSizePixel = 0 }, counters)
	end
	local aura = label(counters, "—", 17, UDim2.new(0, 10, 0, 18), UDim2.new(0.45, -15, 0, 23), Theme.Text, true)
	label(counters, "AURA", 9, UDim2.fromOffset(10, 5), UDim2.new(0.45, -15, 0, 12), Color3.fromRGB(132, 78, 17), true)
	local gems = label(counters, "—", 16, UDim2.new(0.45, 8, 0, 18), UDim2.new(0.31, -12, 0, 23), Theme.Text, true)
	label(counters, "FLEX GEMS", 8, UDim2.new(0.45, 8, 0, 5), UDim2.new(0.31, -12, 0, 12), Color3.fromRGB(109, 60, 149), true)
	local level = label(counters, "LV 1", 12, UDim2.new(0.76, 4, 0, 5), UDim2.new(0.24, -9, 0, 19), Theme.Text, true)
	local rank = label(counters, "", 8, UDim2.new(0.76, 4, 0, 24), UDim2.new(0.24, -9, 0, 15), Theme.Secondary, false)
	rank.TextWrapped = false; rank.TextTruncate = Enum.TextTruncate.AtEnd
	local xp = progress(counters, UDim2.new(0, 1, 1, -4), UDim2.new(1, -2, 0, 4), Theme.Blue)
	local saveBadge = label(root, "Loading…", 9, UDim2.fromOffset(12, 57), UDim2.fromOffset(128, 18), Theme.Secondary, false)
	-- Manual saving lives in the full-size Settings controls.
	local worldBadge = label(root, "", 9, UDim2.fromOffset(145, 59), UDim2.fromOffset(180, 14), Theme.Secondary, false)
	for _, badge in { saveBadge, worldBadge } do badge.TextColor3 = Color3.fromRGB(255, 251, 237); badge.TextStrokeColor3 = Theme.Ink; badge.TextStrokeTransparency = .25 end
	local menuButton = button(root, "MENU", UDim2.new(1, -58, 0, 8), UDim2.fromOffset(46, 47), false, function() self:ToggleMenu() end)
	menuButton.Text = ""; menuButton.BackgroundColor3 = Theme.Gold
	for i = 0,2 do local bar = create("Frame", { Position = UDim2.fromOffset(12,10+i*6), Size = UDim2.fromOffset(22,3), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0 },menuButton); round(bar,2) end
	local menuCaption = label(menuButton,"MENU",8,UDim2.fromOffset(3,30),UDim2.fromOffset(40,14),Theme.Ink,true); menuCaption.TextXAlignment = Enum.TextXAlignment.Center
	local objective = button(root, "", UDim2.fromOffset(12, 81), UDim2.fromOffset(220, 68), false, function()
		if self.State and self.State.ObbyRun then self.SelectedCourse = self.State.ObbyRun.Id; self.CourseWorld = engine.Obbies[self.SelectedCourse].World; self:Open("Obbies")
		elseif self.State and self.State.Objective then
			local goal = self.State.Objective
			if goal.Course then self.SelectedCourse = goal.Course; self.CourseWorld = engine.Obbies[goal.Course].World end
			self:Open(goal.Panel)
		end
	end)
	objective.BackgroundColor3 = Theme.Background
	create("Frame", { Name = "GoalTab", BackgroundColor3 = Theme.Gold, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(4, 47) }, objective)
	local objectiveTitle = label(objective, "YOUR NEXT MOVE", 11, UDim2.fromOffset(10, 7), UDim2.new(1, -28, 0, 18), Theme.Text, true)
	objectiveTitle.TextTruncate = Enum.TextTruncate.AtEnd
	local objectiveDetail = label(objective, "Click for Aura. Beat courses for XP.", 10, UDim2.fromOffset(10, 27), UDim2.new(1, -25, 0, 28), Theme.Secondary, false)
	label(objective, "›", 20, UDim2.new(1, -20, 0, 16), UDim2.fromOffset(12, 26), Theme.Accent, true)
	local objectiveFill = progress(objective, UDim2.new(0, 1, 1, -3), UDim2.new(1, -2, 0, 3), Theme.Accent)
	local clickButton = button(root, "", UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(156, 56), false, callbacks.Click, true)
	clickButton.Name = "MogButton"; clickButton.AnchorPoint = Vector2.new(0.5, 1); clickButton.BackgroundColor3 = Theme.Gold
	label(clickButton, "MOG!", 23, UDim2.fromOffset(10, 2), UDim2.new(1, -20, 0, 30), Theme.Ink, true).TextXAlignment = Enum.TextXAlignment.Center
	local clickAmount = label(clickButton, "0 AURA / TAP", 10, UDim2.fromOffset(8, 32), UDim2.new(1, -16, 0, 15), Theme.Ink, true)
	clickAmount.TextXAlignment = Enum.TextXAlignment.Center
	local cooldownFill = progress(clickButton, UDim2.new(0, 1, 1, -3), UDim2.new(1, -2, 0, 3), Theme.Accent); cooldownFill.Size = UDim2.fromScale(1, 1)
	self.ClickScale = clickButton:FindFirstChildOfClass("UIScale")
	local upgradeQuick = button(root, "POWER", UDim2.new(0.5, -133, 1, -26), UDim2.fromOffset(46, 44), false, function() self:Open("Upgrades") end)
	upgradeQuick.AnchorPoint = Vector2.new(0, 1); upgradeQuick.TextSize = 8
	upgradeQuick.BackgroundColor3 = Theme.Accent
	local shopQuick = button(root, "SHOP", UDim2.new(0.5, 87, 1, -26), UDim2.fromOffset(46, 44), false, function() self:Open("Shop") end)
	shopQuick.AnchorPoint = Vector2.new(0, 1); shopQuick.TextSize = 8
	shopQuick.BackgroundColor3 = Theme.Purple
	local meter = label(root, "F / X", 8, UDim2.new(0.5, -78, 1, -17), UDim2.fromOffset(156, 13), Color3.fromRGB(255, 250, 233), false); meter.TextXAlignment = Enum.TextXAlignment.Center; meter.TextStrokeColor3 = Theme.Ink; meter.TextStrokeTransparency = .2
	self.HudElements = { counters, menuButton, objective, clickButton, saveBadge, worldBadge, upgradeQuick, shopQuick, meter }

	local hub = Menu.new(root,Theme,{
		Open=function(name) self:Open(name) end, Close=function() self:ToggleMenu() end,
		Feedback=function() callbacks.Feedback("Panel") end, GetState=function() return self.State end,
		Visibility=function(visible) saveBadge.Visible=not visible; worldBadge.Visible=not visible and self.Viewport~=nil and self.Viewport.X>=620 end,
	})
	local menu = hub.Frame
	self.Menu = hub; self.MenuFrame = menu
	function self:ToggleMenu()
		hub:SetVisible(not menu.Visible)
		if menu.Visible and self.ToastFrame then self.ToastId += 1; self.ToastFrame.Visible = false end
		if self.RewardFrame then self.RewardFrame.Visible = not menu.Visible and not self.Panel and self.RewardVisible == true end
		if menu.Visible then callbacks.Feedback("Panel") end
		if not menu.Visible and UserInputService.GamepadEnabled then GuiService.SelectedObject = menuButton end
	end
	local toast = label(root, "", 11, UDim2.new(1, -300, 0, 80), UDim2.fromOffset(288, 48), Theme.Text, false)
	self.ToastFrame = toast
	toast.BackgroundColor3 = Theme.Background; toast.TextXAlignment = Enum.TextXAlignment.Center; toast.Visible = false; toast.ZIndex = 20
	round(toast, 8); outline(toast)

	local backdrop = create("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", BackgroundColor3 = Theme.Ink, BackgroundTransparency = 0.48, AutoButtonColor = false, Visible = false, ZIndex = 5 }, root)
	local panel = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 520), BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 6 }, root)
	round(panel, 10); outline(panel)
	local panelTitle = label(panel, "", 24, UDim2.fromOffset(18, 12), UDim2.new(1, -82, 0, 32), Theme.Text, true)
	panelTitle.Position = UDim2.fromOffset(64,12); panelTitle.Size = UDim2.new(1,-126,0,32)
	local panelIcon = create("Frame", { Name = "PanelIcon", Position = UDim2.fromOffset(16,10), Size = UDim2.fromOffset(36,36), BackgroundTransparency = 1 },panel)
	local close = button(panel, "×", UDim2.new(1, -54, 0, 8), UDim2.fromOffset(44, 44), false, function() self:Close() end); close.TextSize = 22
	close.BackgroundColor3 = Theme.Danger
	backdrop.Activated:Connect(function() self:Close() end)
	local body = create("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 57), Size = UDim2.new(1, -28, 1, -71), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Line, ScrollingDirection = Enum.ScrollingDirection.Y }, panel)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	create("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 7) }, body)
	self.PanelFrame = panel; self.Body = body; self.Backdrop = backdrop
	local confirm = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Ink, BackgroundTransparency = 0.2, Visible = false, Active = true, ZIndex = 30 }, root)
	self.ConfirmFrame = confirm
	local confirmCard = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -36, 0, 256), BackgroundColor3 = Theme.Surface, BorderSizePixel = 0 }, confirm)
	create("UISizeConstraint", { MaxSize = Vector2.new(420, 280) }, confirmCard); round(confirmCard, 10); outline(confirmCard)
	local confirmTitle = label(confirmCard, "", 18, UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 40), Theme.Text, true)
	local confirmBody = label(confirmCard, "", 12, UDim2.fromOffset(18, 61), UDim2.new(1, -36, 0, 115), Theme.Secondary, false)
	button(confirmCard, "Cancel", UDim2.new(0, 18, 1, -62), UDim2.new(0.5, -27, 0, 44), false, function() confirm.Visible = false; self.ConfirmAction = nil end)
	self.ConfirmAccept = button(confirmCard, "Confirm", UDim2.new(0.5, 9, 1, -62), UDim2.new(0.5, -27, 0, 44), true, function()
		confirm.Visible = false; local callback = self.ConfirmAction; self.ConfirmAction = nil; if callback then callback() end
	end)
	local prizeCard = create("Frame", { Name = "PrizeReveal", Position = UDim2.new(1, -304, 0, 80), Size = UDim2.fromOffset(292, 238), BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Visible = false, ZIndex = 18 }, root)
	self.RewardFrame = prizeCard; round(prizeCard, 12); outline(prizeCard, 3)
	local prizeTitle = label(prizeCard, "BIG W!", 20, UDim2.fromOffset(12, 8), UDim2.new(1, -62, 0, 30), Theme.Ink, true)
	button(prizeCard, "×", UDim2.new(1, -48, 0, 4), UDim2.fromOffset(44, 44), false, function() self.RewardVisible = false; prizeCard.Visible = false end)
	local prizeCourse = label(prizeCard, "", 10, UDim2.fromOffset(12, 43), UDim2.new(1, -24, 0, 16), Theme.Secondary, false)
	prizeCourse.TextWrapped = false; prizeCourse.TextTruncate = Enum.TextTruncate.AtEnd
	local prizeAmount = label(prizeCard, "", 16, UDim2.fromOffset(12, 64), UDim2.new(1, -24, 0, 25), Theme.Ink, true)
	local prizeSave = label(prizeCard, "", 9, UDim2.fromOffset(12, 91), UDim2.new(1, -24, 0, 13), Theme.Secondary, false)
	local prizePreview = create("ViewportFrame", { Position = UDim2.fromOffset(10, 106), Size = UDim2.fromOffset(70, 64), BackgroundTransparency = 1, Ambient = Color3.fromRGB(180, 183, 197), LightColor = Color3.fromRGB(255, 241, 208), LightDirection = Vector3.new(-1, -1, -1) }, prizeCard)
	local prizeW = label(prizeCard, "W", 42, UDim2.fromOffset(17, 108), UDim2.fromOffset(55, 56), Theme.Ink, true)
	prizeW.TextXAlignment = Enum.TextXAlignment.Center; prizeW.BackgroundColor3 = Theme.Gold; prizeW.BackgroundTransparency = 0; prizeW.Rotation = -6; round(prizeW, 12); outline(prizeW)
	local prizeName = label(prizeCard, "", 14, UDim2.fromOffset(88, 108), UDim2.new(1, -100, 0, 24), Theme.Ink, true)
	local prizeDetail = label(prizeCard, "", 10, UDim2.fromOffset(88, 134), UDim2.new(1, -100, 0, 33), Theme.Secondary, false)
	local prizeButton = button(prizeCard, "NICE!", UDim2.new(0, 12, 1, -56), UDim2.new(1, -24, 0, 44), true, function()
		prizeCard.Visible = false; self.RewardVisible = false
		if self.LastReward and self.LastReward.Pet then self.PetWorld = engine.Pets[self.LastReward.Pet].World; self:Open("Pets") end
	end)
	function self:ShowReward(event)
		toast.Visible = false; self.ToastId += 1
		self.LastReward = event; self.RewardVisible = true; self.RewardSerial = (self.RewardSerial or 0) + 1
		local serial = self.RewardSerial
		local pet = event.Pet and engine.Pets[event.Pet]
		prizeTitle.Text = if pet then "PET UNLOCKED!" elseif event.First then "FIRST CLEAR!" else "BIG W!"
		prizeCourse.Text = string.upper(event.Course or "COURSE CLEARED")
		prizeAmount.Text = "+" .. format.number(event.Amount or 0) .. " AURA   +" .. format.number(event.XP or 0) .. " XP"
		prizeSave.Text = if self.State and self.State.Save.Persistent then "Reward saved" else "Preview reward · saving is off"
		for _, child in prizePreview:GetChildren() do child:Destroy() end
		prizePreview.Visible = pet ~= nil; prizeW.Visible = pet == nil
		prizeName.Text = if pet then pet.Name else "Certified route cooker"
		prizeDetail.Text = if pet then "Added to your squad collection. Equip or train it there." else "Replay for more Aura + XP after the reward cooldown."
		prizeButton.Text = if pet then "VIEW HYPE SQUAD" else "NICE! KEEP COOKING"
		if pet then callbacks.PetPreview(prizePreview, pet, 1) end
		prizeCard.Visible = not self.Panel and not menu.Visible
		task.delay(10, function() if self.RewardSerial == serial then self.RewardVisible = false; prizeCard.Visible = false end end)
	end
	function self:DismissReward()
		self.RewardVisible = false; prizeCard.Visible = false; self.RewardSerial = (self.RewardSerial or 0) + 1
	end
	local function resize()
		local camera = workspace.CurrentCamera; if not camera then return end
		local top, bottom = GuiService:GetGuiInset()
		local width, height = camera.ViewportSize.X, camera.ViewportSize.Y - top.Y - bottom.Y
		if root.AbsoluteSize and root.AbsoluteSize.X > 0 and root.AbsoluteSize.Y > 0 then width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y end
		self.Viewport = Vector2.new(width, height)
		local mobile = width < 620
		counters.Size = UDim2.fromOffset(math.min(326, width - 82), 47)
		aura.TextSize = if mobile then 15 else 17; gems.TextSize = if mobile then 14 else 16
		panel.Size = UDim2.fromOffset(math.min(620, width - 24), math.max(210, math.min(550, height - 36)))
		hub:Resize(width,height)
		objective.Size = UDim2.fromOffset(if mobile then 194 else 220, 68)
		upgradeQuick.Visible = not mobile; shopQuick.Visible = not mobile
		worldBadge.Visible = width >= 620 and not menu.Visible; saveBadge.Visible = not menu.Visible
		toast.Size = UDim2.fromOffset(math.min(288, width - 32), 48)
		toast.Position = if mobile then UDim2.new(0.5, -math.min(288, width - 32) / 2, 0, 157) else UDim2.new(1, -300, 0, 80)
		prizeCard.Size = UDim2.fromOffset(math.min(292, width - 24), 238)
		prizeCard.Position = if mobile then UDim2.fromOffset(12, 157) else UDim2.new(1, -304, 0, 80)
		if height < 450 then prizeCard.Position = UDim2.new(1, -304, 0.5, -119) end
		if height < 450 then objective.Visible = false else objective.Visible = true end
	end
	local cameraConnection
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		if workspace.CurrentCamera then cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
		resize()
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera); bindCamera()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if (input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.ButtonY) and not self.Panel and not confirm.Visible then self:ToggleMenu() end
		if (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX) and not self.Panel and not confirm.Visible then callbacks.Click() end
		if input.KeyCode == Enum.KeyCode.ButtonB then self:Close() end
	end)

	function self:Now()
		return if self.State then self.State.ServerTime + (os.clock() - self.ReceivedAt) else 0
	end
	function self:SetSaveStatus(state)
		local captions = { saved = "Saved", pending = "Auto-save pending", saving = "Saving…", retry = "Save retrying", preview = "Preview · saving off" }
		saveBadge.Text = captions[state] or "Loading…"
		saveBadge.TextColor3 = if state == "preview" or state == "retry" then Theme.Gold else Color3.fromRGB(255, 251, 237)
	end
	function self:Toast(message, success)
		if self.RewardVisible and prizeCard.Visible and success ~= false then return end
		self.ToastId += 1; local id = self.ToastId
		toast.Text = message; toast.TextColor3 = if success == false then Color3.fromRGB(148, 48, 64) else Theme.Text; toast.Visible = true
		task.delay(3, function() if self.ToastId == id then toast.Visible = false end end)
	end
	function self:Confirm(heading, message, caption, callback)
		confirmTitle.Text = heading; confirmBody.Text = message; self.ConfirmAccept.Text = caption; self.ConfirmAction = callback; confirm.Visible = true
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = self.ConfirmAccept end
	end
	function self:Close()
		self.Panel = nil; panel.Visible = false; backdrop.Visible = false; confirm.Visible = false; self.ConfirmAction = nil
		hub:SetVisible(false)
		prizeCard.Visible = self.RewardVisible == true
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = menuButton end
	end
	function self:Open(name)
		if not self.State then self:Toast("Your save is still loading."); return end
		if self.Panel == name then self:Close(); return end
		self.Panel = name; panel.Visible = true; backdrop.Visible = true; hub:SetVisible(false)
		prizeCard.Visible = false
		callbacks.Feedback("Panel"); self:Render()
	end
	function self:Request(name, payload)
		if self.Pending or not self.State then return end
		self.Pending = true
		local training = name == "BuyPet" and self.State.Pets[payload.Id] ~= nil
		task.spawn(function()
			local ok, result = pcall(callbacks.Action, name, payload); self.Pending = false
			if not ok or type(result) ~= "table" then self:Toast("Connection interrupted. Please try again.", false); return end
			if result.State then if callbacks.State then callbacks.State(result.State) else self:Update(result.State) end end
			if result.Message then self:Toast(result.Message, result.Ok) end
			local cue = ({ BuyUpgrade = "Upgrade", BuyPet = "PetUnlock", ClaimQuest = "Quest", ClaimMilestone = "Quest", ClaimLogin = "Quest", Rebirth = "Rebirth", UnlockWorld = "Travel", Travel = "Travel", StartObby = "CourseStart", RetryObby = "ObbyReset" })[name]
			if training then cue = "Upgrade" end
			if not result.Ok then callbacks.Feedback("Error") elseif cue then callbacks.Feedback(cue) end
			if result.Ok and (name == "StartObby" or name == "Travel" or name == "UnlockWorld" or name == "LeaveObby") then self:Close()
			elseif self.Panel then self:Render() end
		end)
	end
	function self:Bind(callback)
		table.insert(self.Bindings, callback); callback(self.State)
	end
	function self:Note(message, height)
		local note = label(body, message, 11, UDim2.new(), UDim2.new(1, -4, 0, height or 46), Theme.Secondary, false)
		note.LayoutOrder = #body:GetChildren()
		return note
	end
	function self:Card(heading, description, height)
		local card = create("Frame", { Size = UDim2.new(1, -4, 0, height or 135), BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, LayoutOrder = #body:GetChildren() }, body)
		round(card, 10); outline(card, 1.5)
		local strip = create("Frame", { Name = "AccentStrip", Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(64, 4), BackgroundColor3 = Theme.Blue, BorderSizePixel = 0 }, card); round(strip, 2)
		local headingLabel = label(card, heading, 15, UDim2.fromOffset(12, 9), UDim2.new(1, -24, 0, 23), Theme.Text, true); headingLabel.Name = "Title"
		local detail = label(card, description, 11, UDim2.fromOffset(12, 35), UDim2.new(1, -24, 0, if (height or 135) >= 175 then 61 else 36), Theme.Secondary, false)
		detail.Name = "Description"
		return card
	end
	function self:AccentCard(card, color)
		card.AccentStrip.BackgroundColor3 = color
	end
	function self:CardButton(card, caption, primary, callback)
		return button(card, caption, UDim2.new(0, 12, 1, -56), UDim2.new(1, -24, 0, 44), primary, callback)
	end
	function self:Tabs(entries, selected, onSelect)
		local frame = create("Frame", { Size = UDim2.new(1, -4, 0, 44), BackgroundTransparency = 1, LayoutOrder = #body:GetChildren() }, body)
		for index, entry in entries do
			local b = button(frame, entry.Label, UDim2.new((index - 1) / #entries, 2, 0, 0), UDim2.new(1 / #entries, -4, 0, 44), entry.Id == selected, function() onSelect(entry.Id); self:Render() end)
			b.TextSize = if #entries >= 5 then 10 else 12; b.TextWrapped = true
		end
	end
	function self:WorldTabs(selected, onSelect)
		local tabs = {}
		for _, world in config.Worlds do table.insert(tabs, { Id = world.Id, Label = world.Icon .. "\n" .. ({ meadow = "Meadow", candy = "Gym", coral = "Reef", cosmos = "Summit", citadel = "Citadel" })[world.Id] }) end
		self:Tabs(tabs, selected, onSelect)
	end
	function self:OfferPurchase(key, name, description)
		local offer = self.State.Catalog[key]
		if not offer or not offer.Enabled then self:Toast("This offer is unavailable.", false); return end
		self:Confirm(name, description .. "\nListed price: R$ " .. offer.Price .. ". Roblox's next window shows the final charge. This is optional.", "Continue to Roblox", function() self:Request("Purchase", { Id = key }) end)
	end

	function self:Render()
		self.Bindings = {}
		for _, child in body:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		body.CanvasPosition = Vector2.zero
		panelTitle.Text = ({ Obbies = "Rizz Routes", Upgrades = "Mog Lab", Pets = "Hype Squad", Worlds = "World Hop", Goals = "Daily Ws", Shop = "Flex Shop", Settings = "Settings" })[self.Panel] or self.Panel or ""
		for _,child in panelIcon:GetChildren() do child:Destroy() end
		MenuIcons.draw(panelIcon,self.Panel,({Obbies=Theme.Gold,Upgrades=Theme.Accent,Pets=Theme.Purple,Worlds=Theme.Blue,Goals=Theme.Danger,Shop=Theme.Gold,Settings=Theme.Blue})[self.Panel] or Theme.Gold,Theme.Ink)
		local p = self.State; if not p then return end
		if self.Panel == "Obbies" then
			self:Note("Click. Climb. Collect. Walk onto START or choose a route below. Follow the numbered jumps; hard first clears unlock a guaranteed pet.", 52)
			if self.SelectedCourse and engine.Obbies[self.SelectedCourse] then self.CourseWorld = engine.Obbies[self.SelectedCourse].World end
			self:WorldTabs(self.CourseWorld, function(id) self.CourseWorld = id; self.SelectedCourse = nil end)
			if p.ObbyRun then
				local active = self:Card(p.ObbyRun.Name .. " · " .. p.ObbyRun.Stage .. "/" .. p.ObbyRun.Count, "For this run, falling returns you to checkpoint " .. p.ObbyRun.Checkpoint .. ". Cleared-course rewards are saved.", 145)
				self:Bind(function(s) if s.ObbyRun then active.Title.Text = s.ObbyRun.Name .. " · " .. s.ObbyRun.Stage .. "/" .. s.ObbyRun.Count; active.Description.Text = if s.ObbyRun.RewardPending then "Your verified finish is waiting for a save. The prize retries automatically." else "Falling returns to checkpoint " .. s.ObbyRun.Checkpoint .. ". Finish rewards are saved before delivery." end end)
				local retry = button(active, "Retry checkpoint", UDim2.new(0, 12, 1, -56), UDim2.new(0.55, -18, 0, 44), false, function() self:Request("RetryObby", {}) end)
				local leave = button(active, "Leave course", UDim2.new(0.55, 0, 1, -56), UDim2.new(0.45, -12, 0, 44), false, function() self:Request("LeaveObby", {}) end)
				self:Bind(function(s) retry.Active = s.ObbyRun ~= nil and not s.ObbyRun.RewardPending; leave.Active = retry.Active; if s.ObbyRun and s.ObbyRun.RewardPending then leave.Text = "Saving prize…" end end)
			end
			for _, route in config.Obbies do
				if route.World ~= self.CourseWorld then continue end
				local first = not p.Obby.FirstClear[route.Id]
				local pet = route.PetReward and engine.Pets[route.PetReward]
				local badge = if route.Difficulty == "warmup" then "WARM-UP" elseif route.Difficulty == "sky" then "HARD" else "EXPERT"
				local rewardText = format.number(if first then route.FirstAura else route.RepeatAura) .. " Aura + " .. (if first then route.FirstXP else route.RepeatXP) .. " XP"
				local description = route.Count .. " jumps · checkpoints every " .. route.CheckpointEvery .. "\n" .. rewardText
				if pet then description ..= if first then "\nFirst clear: " .. pet.Name .. " (guaranteed)" else "\nExclusive pet earned. Repeats award Aura + XP." end
				local card = self:Card(badge .. " / " .. route.Name, description, 180)
				self:AccentCard(card, if route.Difficulty == "warmup" then Theme.Accent elseif route.Difficulty == "sky" then Theme.Blue else Theme.Purple)
				local b = self:CardButton(card, "", true, function()
					if not self.State.Worlds[route.World] then self:Open("Worlds")
					elseif self.State.CurrentWorld ~= route.World then self:Request("Travel", { Id = route.World })
					elseif self.State.ObbyRun and self.State.ObbyRun.Id ~= route.Id then
						self:Confirm("Start a different course?", "This replaces the active run. Collected Aura and earned pets stay. Your current run checkpoint will be lost.", "Start course", function() self:Request("StartObby", { Id = route.Id }) end)
					else self:Request("StartObby", { Id = route.Id }) end
				end)
				self:Bind(function(s)
					local seconds = (s.Obby.NextRewardAt[route.Id] or 0) - self:Now()
					b.Text = if not s.Worlds[route.World] then "Discover this zone first" elseif s.CurrentWorld ~= route.World then "Travel to " .. engine.Worlds[route.World].Name elseif s.ObbyRun and s.ObbyRun.Id == route.Id then "Restart from the beginning" elseif seconds > 0 and s.Obby.FirstClear[route.Id] then "Practice · rewards in " .. timeLeft(seconds) else "Start course"
				end)
			end
		elseif self.Panel == "Pets" then
			self:Note("Aura pets take saving up. HARD / EXPERT pets are earned only by clearing their course. Train owned pets up to Lv 10.", 48)
			self:WorldTabs(self.PetWorld, function(id) self.PetWorld = id end)
			local summary = self:Note("", 26)
			self:Bind(function(s) local owned = 0; for _ in s.Pets do owned += 1 end; summary.Text = owned .. "/" .. #config.Pets .. " collected · " .. #s.Equipped .. "/" .. s.EquipSlots .. " following · " .. string.format("%.1f", s.PetMultiplier) .. "×" end)
			local best = button(body, "EQUIP BEST SQUAD", UDim2.new(), UDim2.new(1, -4, 0, 44), true, function() self:Request("EquipBest", {}) end); best.LayoutOrder = #body:GetChildren()
			self:Bind(function(s) best.Active = next(s.Pets) ~= nil end)
			for _, pet in config.Pets do
				if pet.World ~= self.PetWorld then continue end
				local card = self:Card(pet.Name, if pet.ObbyOnly then "EARNED PET · " .. engine.Obbies[pet.ObbyOnly].Name else pet.Description, 171)
				self:AccentCard(card, if pet.ObbyOnly then Theme.Purple else Theme.Gold)
				for _, item in card:GetChildren() do if item:IsA("TextLabel") then item.Position = UDim2.fromOffset(96, item.Position.Y.Offset); item.Size = UDim2.new(1, -108, 0, item.Size.Y.Offset) end end
				local viewport = create("ViewportFrame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = Theme.Raised, BackgroundTransparency = .35, Ambient = Color3.fromRGB(170, 178, 190), LightColor = Color3.fromRGB(255, 237, 209), LightDirection = Vector3.new(-1, -1, -1) }, card)
				round(viewport, 9)
				callbacks.PetPreview(viewport, pet, p.Pets[pet.Id] or 1)
				local info = label(card, "", 10, UDim2.fromOffset(12, 89), UDim2.new(1, -24, 0, 18), Theme.Secondary, false)
				local buy = button(card, "", UDim2.new(0, 12, 1, -56), UDim2.new(0.67, -18, 0, 44), true, function()
					if pet.ObbyOnly and not self.State.Pets[pet.Id] then self.SelectedCourse = pet.ObbyOnly; self:Open("Obbies")
					else self:Request("BuyPet", { Id = pet.Id }) end
				end)
				local equip = button(card, "", UDim2.new(0.67, 0, 1, -56), UDim2.new(0.33, -12, 0, 44), false, function() self:Request("EquipPet", { Id = pet.Id }) end)
				self:Bind(function(s)
					local petLevel = s.Pets[pet.Id] or 0
					info.Text = "Lv " .. petLevel .. " · " .. format.percent(engine:PetBonus(pet.Id, math.max(1, petLevel))) .. " click bonus"
					buy.Text = if pet.ObbyOnly and petLevel == 0 then "View earning course" elseif not s.Worlds[pet.World] then "Zone locked" elseif petLevel >= config.MaxPetLevel then "Fully trained" else (if petLevel == 0 then "Adopt · " else "Train · ") .. format.number(engine:PetCost(pet.Id, petLevel)) .. " Aura"
					buy.Active = (pet.ObbyOnly ~= nil and petLevel == 0) or (s.Worlds[pet.World] == true and petLevel < config.MaxPetLevel)
					equip.Visible = petLevel > 0; equip.Text = if table.find(s.Equipped, pet.Id) then "Rest" else "Equip"
				end)
			end
		elseif self.Panel == "Worlds" then
			self:Note("One starter and four unlockable zones. Each has its own courses, earned pets, and Aura multiplier. Unlocking also takes you there.", 49)
			for _, world in config.Worlds do
				local card = self:Card(world.Icon .. " / " .. world.Name, world.Tagline .. "\n" .. world.Multiplier .. "× Aura · Lv " .. world.Level .. " · " .. format.number(world.Cost) .. " Aura", 149)
				local b = self:CardButton(card, "", true, function()
					if self.State.Worlds[world.Id] then self:Request("Travel", { Id = world.Id })
					else self:Confirm("Discover " .. world.Name .. "?", "Spend " .. format.number(world.Cost) .. " Aura to unlock and travel. Requires level " .. world.Level .. " and the previous zone.", "Unlock & travel", function() self:Request("UnlockWorld", { Id = world.Id }) end) end
				end)
				self:Bind(function(s)
					local previous = config.Worlds[world.Index - 1]
					local priorOwned = not previous or s.Worlds[previous.Id]
					b.Text = if s.CurrentWorld == world.Id then "You are here" elseif s.Worlds[world.Id] then "Travel" elseif not priorOwned then "Unlock the previous island first" elseif s.Level < world.Level then "Reach level " .. world.Level .. " first" elseif s.Aura < world.Cost then "Save " .. format.number(world.Cost - s.Aura) .. " more Aura" else "Unlock & travel · " .. format.number(world.Cost) .. " Aura"
					b.Active = s.CurrentWorld ~= world.Id and (s.Worlds[world.Id] == true or (priorOwned == true and s.Level >= world.Level and s.Aura >= world.Cost))
				end)
				self:AccentCard(card, Color3.fromHex(world.Color))
			end
		elseif self.Panel == "Goals" then
			self:Tabs({ { Id = "Daily", Label = "Daily tasks" }, { Id = "Journal", Label = "Journal" }, { Id = "Login", Label = "Login reward" } }, self.GoalsTab, function(tab) self.GoalsTab = tab end)
			if self.GoalsTab == "Login" then
				self:Note("No reward on your first day. Your first claim unlocks 24 hours after your first saved visit. Later claims are 24 hours apart; no streak is lost.", 66)
				local card = self:Card("Return reward", "Earn Aura and 40 XP. Flex Gems are never part of login rewards.", 154)
				local due = label(card, "", 11, UDim2.fromOffset(12, 79), UDim2.new(1, -24, 0, 18), Theme.Ink, true)
				local b = self:CardButton(card, "", true, function() self:Request("ClaimLogin", {}) end)
				self:Bind(function(s)
					local status = engine:LoginStatus(s, self:Now())
					due.Text = if not s.Save.Persistent then "Persistent saving is required for login rewards." elseif status.Ready then "Ready to collect" else "Available in " .. timeLeft(status.NextAt - self:Now())
					b.Text = "Collect return " .. (status.Claims + 1) .. " · " .. format.number(status.Aura) .. " Aura"
					b.Active = s.Save.Persistent and status.Ready
				end)
			else
				local journal = self.GoalsTab == "Journal"
				self:Note(if journal then "Permanent milestones survive rebirth. Earn two free titles through your journal." else "Tasks refresh at 00:00 UTC. Courses are the main XP route.", 42)
				for _, goal in (if journal then config.Milestones else config.Quests) do
					local card = self:Card(goal.Name, goal.Description .. "\n" .. format.number(goal.Aura) .. " Aura + " .. goal.XP .. " XP" .. (if goal.Cosmetic then " + earned title" else ""), 159)
					local fill = progress(card, UDim2.fromOffset(12, 82), UDim2.new(1, -24, 0, 4), Theme.Accent)
					local b = self:CardButton(card, "", true, function() self:Request(if journal then "ClaimMilestone" else "ClaimQuest", { Id = goal.Id }) end)
					self:Bind(function(s)
						local amount = math.min(goal.Target, if journal then engine:MilestoneProgress(s, goal.Id) else s.Daily[goal.Counter])
						local claimed = if journal then s.Milestones[goal.Id] else s.Daily.Claimed[goal.Id]
						fill.Size = UDim2.fromScale(amount / goal.Target, 1)
						b.Text = if claimed then "Collected" elseif amount >= goal.Target then "Collect reward" else format.number(amount) .. " / " .. format.number(goal.Target)
						b.Active = not claimed and amount >= goal.Target
					end)
				end
			end
		elseif self.Panel == "Upgrades" then
			local card = self:Card("Mog Power", "Earn more Aura per click and crystal. XP comes mostly from courses.", 135)
			local b = self:CardButton(card, "", true, function() self:Request("BuyUpgrade", {}) end)
			self:Bind(function(s) b.Text = if s.Upgrade >= config.MaxUpgrade then "Maximum power" else "Power " .. (s.Upgrade + 1) .. " → " .. (s.Upgrade + 2) .. " · " .. format.number(s.UpgradeCost) .. " Aura"; b.Active = s.Upgrade < config.MaxUpgrade end)
			local rebirth = self:Card("Next era", "Resets ALL Aura and Mog Power. Keep pets, zones, level, journal stamps, login progress, styles, and Flex Gems. Gain another permanent +25% click bonus.", 190)
			local info = label(rebirth, "", 10, UDim2.fromOffset(12, 100), UDim2.new(1, -24, 0, 18), Theme.Secondary, false)
			local rb = self:CardButton(rebirth, "", false, function()
				self:Confirm("Rebirth?", "Reset ALL " .. format.number(self.State.Aura) .. " Aura and click upgrades. Other progression stays. Gain another permanent +25% click bonus.", "Rebirth", function() self:Request("Rebirth", {}) end)
			end)
			self:Bind(function(s) info.Text = s.Rebirths .. "/" .. config.MaxRebirths .. " rebirths · +" .. s.Rebirths * 25 .. "% permanent bonus"; rb.Text = "Requires " .. format.number(s.RebirthCost) .. " Aura"; rb.Active = s.Rebirths < config.MaxRebirths end)
			local optional = self:Card("Optional boosts", "Temporary 2× Aura / XP and permanent passes are in the shop. All courses and earned pets remain available through play.", 145)
			self:CardButton(optional, "View optional shop", false, function() self.Tab = "Boosts"; self:Open("Shop") end)
		elseif self.Panel == "Shop" then
			self:Tabs({ { Id = "Boosts", Label = "Boosts" }, { Id = "Aura", Label = "Aura" }, { Id = "FlexGems", Label = "Gems" }, { Id = "Cosmetics", Label = "Styles" }, { Id = "Passes", Label = "Passes" } }, self.Tab, function(tab) self.Tab = tab end)
			self:Note(if p.Sandbox or not next(p.Catalog) then "Purchases are unavailable in this preview. No Robux are charged." else "Optional Robux purchases. Review the exact reward and Roblox's final price. Only buy with the account owner's permission.", 54)
			if self.Tab == "Boosts" or self.Tab == "Aura" or self.Tab == "FlexGems" then
				self:Note(if self.Tab == "Boosts" then "Timers persist and run while offline. Extra purchases add time. Hard-course pets must still be earned." elseif self.Tab == "Aura" then "Aura is also earned through play. Optional packs do not count as earned Aura for goals." else "Flex Gems are paid cosmetic currency. They are available only through Robux purchases.", 48)
				for _, product in config.Products do
					if (self.Tab == "Boosts" and product.Kind ~= "Boost") or (self.Tab ~= "Boosts" and product.Currency ~= self.Tab) then continue end
					local card = self:Card(product.Name, product.Description, 139)
					local b = self:CardButton(card, "", false, function() self:OfferPurchase(product.Key, product.Name, product.Description) end)
					self:Bind(function(s) local offer = s.Catalog[product.Key]; b.Text = if offer and offer.Enabled then "View purchase · R$ " .. offer.Price else "Currently unavailable"; b.Active = offer ~= nil and offer.Enabled == true end)
				end
			elseif self.Tab == "Passes" then
				for _, pass in config.Passes do
					local card = self:Card(pass.Name, pass.Description, 139)
					local b = self:CardButton(card, "", false, function() self:OfferPurchase(pass.Key, pass.Name, pass.Description) end)
					self:Bind(function(s) local offer = s.Catalog[pass.Key]; b.Text = if s.Passes[pass.Key] then "Owned" elseif offer and offer.Enabled then "Permanent pass · R$ " .. offer.Price else "Currently unavailable"; b.Active = not s.Passes[pass.Key] and offer ~= nil and offer.Enabled == true end)
				end
			else
				self:Note("Permanent, guaranteed styles. Equip one trail, orbit, and title at a time.", 35)
				for _, item in config.Cosmetics do
					local card = self:Card(item.Name .. " / " .. item.Kind, item.Description, 139)
					local b = self:CardButton(card, "", false, function()
						local owned = self.State.Cosmetics[item.Id] or (item.Pass and self.State.Passes[item.Pass])
						if owned then self:Request("EquipCosmetic", { Id = item.Id })
						elseif item.Pass then self.Tab = "Passes"; self:Render()
						elseif item.Earned then self.GoalsTab = "Journal"; self:Open("Goals")
						else self:Confirm("Get " .. item.Name .. "?", "Spend " .. item.Cost .. " Flex Gems on this permanent style. Flex Gems are paid cosmetic currency.", "Spend " .. item.Cost .. " Flex Gems", function() self:Request("BuyCosmetic", { Id = item.Id }) end) end
					end)
					self:Bind(function(s)
						local owned = s.Cosmetics[item.Id] or (item.Pass and s.Passes[item.Pass])
						b.Text = if owned then (if s.ActiveCosmetics[item.Kind] == item.Id then "Equipped · remove" else "Equip") elseif item.Pass then "View Mog Patron pass" elseif item.Earned then "Earn free in the journal" else item.Cost .. " Flex Gems · guaranteed style"
					end)
				end
			end
		elseif self.Panel == "Settings" then
			local saving = self:Card("Progress saving", if p.Save.Persistent then "Saved automatically every 30 seconds, on course clears, login claims, purchases, and leaving." else "Studio preview: progress cannot persist. Publish a test place and enable Studio API access to test cloud saving.", 171)
			local status = label(saving, "", 10, UDim2.fromOffset(12, 93), UDim2.new(1, -24, 0, 18), Theme.Secondary, false)
			self:Bind(function(s) status.Text = if s.Save.Persistent then "Storage: cloud · " .. s.Save.State else "Storage: temporary preview" end)
			self:CardButton(saving, "Save now", false, function() self:Request("SaveNow", {}) end)
			local musicCard = self:Card("Music", "Tender Static → Elevator Jazz → Gymnopedie No. 1. The playlist repeats in order.", 235)
			musicCard.Description.Size = UDim2.new(1, -24, 0, 36)
			self:AccentCard(musicCard, Theme.Blue)
			local playing = label(musicCard, "", 10, UDim2.fromOffset(12, 77), UDim2.new(1, -24, 0, 32), Theme.Secondary, false)
			local toggle = button(musicCard, "", UDim2.fromOffset(12, 119), UDim2.new(1, -24, 0, 44), true, function() self:Request("Setting", { Id = "Music", Value = not self.State.Settings.Music }) end)
			local down = button(musicCard, "−", UDim2.new(0, 12, 1, -56), UDim2.fromOffset(44, 44), false, function() self:Request("Setting", { Id = "MusicVolume", Value = math.max(0, self.State.Settings.MusicVolume - 25) }) end)
			local level = label(musicCard, "", 12, UDim2.new(0, 64, 1, -56), UDim2.new(1, -128, 0, 44), Theme.Ink, true); level.TextXAlignment = Enum.TextXAlignment.Center
			local up = button(musicCard, "+", UDim2.new(1, -56, 1, -56), UDim2.fromOffset(44, 44), false, function() self:Request("Setting", { Id = "MusicVolume", Value = math.min(100, self.State.Settings.MusicVolume + 25) }) end)
			self:Bind(function(s)
				toggle.Text = if s.Settings.Music then "Music on · mute" else "Music off · enable"
				level.Text = "Volume " .. s.Settings.MusicVolume .. "%"
				down.Active = s.Settings.MusicVolume > 0; up.Active = s.Settings.MusicVolume < 100
				local status = callbacks.MusicStatus and callbacks.MusicStatus()
				playing.Text = if not s.Settings.Music then "Paused · sound effects have their own toggle" elseif status and status.State == "playing" then status.Title elseif status and status.State == "retrying" then "Music unavailable · trying again shortly" else "Loading the playlist…"
			end)
			for _, option in { { Id = "SFX", Name = "Sound effects", Description = "Aura pickup pops, bubble menu taps, victory audio, and gameplay cues." }, { Id = "Effects", Name = "Extra animation", Description = "Pet bobbing, small reward pop-ups, particles, and mog poses." } } do
				local card = self:Card(option.Name, option.Description, 135)
				local b = self:CardButton(card, "", false, function() self:Request("Setting", { Id = option.Id, Value = not self.State.Settings[option.Id] }) end)
				self:Bind(function(s) b.Text = if s.Settings[option.Id] then "On · turn off" else "Off · turn on" end)
			end
			self:Note("Tap MOG / press F / controller X. Move with Roblox controls. The 0.2-second server cooldown caps click speed at 5 per second. Course rewards require every platform in order.", 72)
		end
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = close end
	end

	function self:Update(state)
		self.State = state; self.ReceivedAt = os.clock()
		aura.Text = format.number(state.Aura); gems.Text = format.number(state.FlexGems); level.Text = "LV " .. state.Level
		rank.Text = engine:Rank(state.Level)
		TweenService:Create(xp, TweenInfo.new(0.15), { Size = UDim2.fromScale(state.XP / state.XPRequired, 1) }):Play()
		worldBadge.Text = string.upper(engine.Worlds[state.CurrentWorld].Name)
		clickAmount.Text = "+" .. format.number(state.ClickValue) .. " AURA / TAP"
		local boosts = {}
		if state.Boosts.AuraUntil > self:Now() then table.insert(boosts, "Aura 2× " .. timeLeft(state.Boosts.AuraUntil - self:Now())) end
		if state.Boosts.XPUntil > self:Now() then table.insert(boosts, "XP 2× " .. timeLeft(state.Boosts.XPUntil - self:Now())) end
		meter.Text = if #boosts > 0 then table.concat(boosts, " · ") else (state.TotalClicks % config.BurstEvery) .. "/" .. config.BurstEvery .. " MOG · F / X"
		self:SetSaveStatus(state.Save.State)
		if state.ObbyRun then
			objectiveTitle.Text = if state.ObbyRun.RewardPending then "PRIZE READY!" else state.ObbyRun.Name .. " · " .. state.ObbyRun.Stage .. "/" .. state.ObbyRun.Count
			objectiveDetail.Text = if state.ObbyRun.RewardPending then "Saving your prize. It will arrive automatically when saving recovers." else "Follow the numbers + arrow. Checkpoint " .. state.ObbyRun.Checkpoint .. " · tap for controls"
			objectiveFill.Size = UDim2.fromScale(state.ObbyRun.Stage / state.ObbyRun.Count, 1)
		else
			objectiveTitle.Text = state.Objective.Title; objectiveDetail.Text = state.Objective.Detail
			objectiveFill.Size = UDim2.fromScale(math.clamp(state.Objective.Progress, 0, 1), 1)
		end
		local ready = 0
		for _, goal in config.Quests do if not state.Daily.Claimed[goal.Id] and state.Daily[goal.Counter] >= goal.Target then ready += 1 end end
		for _, goal in config.Milestones do if not state.Milestones[goal.Id] and engine:MilestoneProgress(state, goal.Id) >= goal.Target then ready += 1 end end
		if state.Save.Persistent and engine:LoginStatus(state, self:Now()).Ready then ready += 1 end
		hub:Update(state,ready)
		for _, binding in self.Bindings do binding(state) end
	end
	function self:Pulse()
		cooldownFill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(cooldownFill, TweenInfo.new(config.ClickCooldown, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
		if self.State and self.State.Settings.Effects then
			self.ClickScale.Scale = 0.98
			TweenService:Create(self.ClickScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
		end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then elapsed = 0; if self.State and self.Panel then for _, binding in self.Bindings do binding(self.State) end end end
	end)
	return self
end
return UI
