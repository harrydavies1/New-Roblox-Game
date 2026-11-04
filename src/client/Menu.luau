--!nonstrict
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Icons = require(script.Parent.MenuIcons)

local Menu = {}
function Menu.new(root, theme, callbacks)
	local function make(class, props, parent)
		local o = Instance.new(class); for k,v in props do o[k] = v end; o.Parent = parent; return o
	end
	local function corner(o, radius) make("UICorner", { CornerRadius = UDim.new(0, radius) }, o) end
	local function stroke(o, thickness, color) return make("UIStroke", { Color = color or theme.Ink, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
	local function text(parent, value, size, position, dimensions, bold, color)
		return make("TextLabel", { Text = value, TextSize = size, Font = if bold then Enum.Font.FredokaOne else Enum.Font.GothamMedium,
			TextColor3 = color or theme.Ink, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Position = position, Size = dimensions }, parent)
	end
	local self = { Items = {}, State = nil }
	local dismiss = make("TextButton", { Name = "MenuDismiss", Size = UDim2.fromScale(1,1), Text = "", BackgroundTransparency = 1, Visible = false, Selectable = false, ZIndex = 3 }, root)
	local shadow = make("Frame", { Name = "MenuShadow", Size = UDim2.fromOffset(364,468), BackgroundColor3 = theme.Ink, BackgroundTransparency = .28, BorderSizePixel = 0, Visible = false, ZIndex = 4 }, root); corner(shadow,18)
	local frame = make("Frame", { Name = "MogMenu", Size = UDim2.fromOffset(364,468), BackgroundColor3 = theme.Background, BorderSizePixel = 0, Visible = false, ZIndex = 4 }, root)
	corner(frame,18); stroke(frame,3)
	self.Frame = frame; self.Shadow = shadow; self.Dismiss = dismiss
	local portrait = make("Frame", { Name = "MogMascot", Position = UDim2.fromOffset(14,14), Size = UDim2.fromOffset(43,43), BackgroundTransparency = 1 }, frame)
	Icons.draw(portrait,"Mascot",theme.Gold,theme.Ink)
	text(frame,"MOG MENU",25,UDim2.fromOffset(67,11),UDim2.new(1,-128,0,31),true)
	text(frame,"YOUR NEXT W STARTS HERE",9,UDim2.fromOffset(68,44),UDim2.new(1,-133,0,17),false,theme.Secondary)
	local close = make("TextButton", { Name = "CloseMenu", Text = "×", TextSize = 26, Font = Enum.Font.FredokaOne, TextColor3 = theme.Ink,
		Position = UDim2.new(1,-56,0,14), Size = UDim2.fromOffset(44,44), BackgroundColor3 = theme.Gold, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Center },frame)
	corner(close,12); stroke(close,2)
	close.Activated:Connect(function() callbacks.Feedback(); callbacks.Close() end)
	dismiss.Activated:Connect(callbacks.Close)
	local list = make("ScrollingFrame", { Name = "Destinations", Position = UDim2.fromOffset(8,74), Size = UDim2.new(1,-16,1,-108),
		CanvasSize = UDim2.fromOffset(0,358), CanvasPosition = Vector2.zero, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
		ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Ink, ScrollingDirection = Enum.ScrollingDirection.Y },frame)
	self.List = list
	local footer = text(frame,"CLICK. CLIMB. COLLECT.",10,UDim2.new(0,12,1,-27),UDim2.new(1,-24,0,19),true,theme.Secondary); footer.TextXAlignment = Enum.TextXAlignment.Center
	local function tile(id, title, subtitle, pos, size, accent, featured, utility)
		local b = make("TextButton", { Name = id, Text = "", AutoButtonColor = false, Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0 },list)
		local base = make("Frame", { Name = "Depth", Position = UDim2.fromOffset(0,4), Size = UDim2.fromScale(1,1), BackgroundColor3 = theme.Ink, BorderSizePixel = 0 },b); corner(base,12)
		local face = make("Frame", { Name = "Face", Size = UDim2.fromScale(1,1), BackgroundColor3 = if featured then theme.Gold else theme.Surface, BorderSizePixel = 0 },b); corner(face,12)
		local rim = stroke(face,2)
		local iconSize = if featured then 54 elseif utility then 28 else 34
		local icon = make("Frame", { Name = "Illustration", BackgroundTransparency = 1, Size = UDim2.fromOffset(iconSize,iconSize),
			Position = if featured then UDim2.new(1,-69,0,17) elseif utility then UDim2.fromOffset(10,9) else UDim2.new(1,-46,0,9) },face)
		Icons.draw(icon,id,accent,theme.Ink)
		local heading = text(face,title,if featured then 21 elseif utility then 13 else 17,
			if utility then UDim2.fromOffset(47,0) else UDim2.fromOffset(12,if featured then 10 else 41),
			if utility then UDim2.new(1,-52,1,0) elseif featured then UDim2.new(1,-86,0,29) else UDim2.new(1,-24,0,25),true)
		local detail = text(face,subtitle,10,UDim2.fromOffset(12,if featured then 43 else 66),UDim2.new(1,if featured then -91 else -24,0,17),false,theme.Secondary)
		detail.Visible = not utility
		if featured then
			local play = text(face,"PLAY  ›",9,UDim2.fromOffset(12,65),UDim2.fromOffset(57,16),true,theme.Surface)
			play.BackgroundColor3 = theme.Ink; play.BackgroundTransparency = 0; play.TextXAlignment = Enum.TextXAlignment.Center; corner(play,5)
		end
		local mark = make("Frame", { Name = "CategoryMark", Position = UDim2.fromOffset(12,12), Size = UDim2.fromOffset(23,5), BackgroundColor3 = accent, BorderSizePixel = 0, Visible = not featured and not utility },face); corner(mark,2)
		local badge = text(face,"",9,UDim2.fromOffset(12,19),UDim2.fromOffset(46,17),true)
		badge.BackgroundColor3 = accent; badge.BackgroundTransparency = 0; badge.TextXAlignment = Enum.TextXAlignment.Center; badge.Visible = false; corner(badge,5)
		local tween
		local function feedback(focused, pressed)
			rim.Color = if focused then theme.Purple else theme.Ink
			if tween then tween:Cancel() end
			local state = callbacks.GetState()
			local target = UDim2.fromOffset(0,if pressed then 3 elseif focused then -1 else 0)
			if state and not state.Settings.Effects then face.Position = UDim2.new(); return end
			tween = TweenService:Create(face,TweenInfo.new(.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=target}); tween:Play()
		end
		b.MouseEnter:Connect(function() feedback(true,false) end)
		b.MouseLeave:Connect(function() feedback(false,false) end)
		b.SelectionGained:Connect(function()
			feedback(true,false)
			local h = frame.Size.Y.Offset - 108
			local top,bottom = b.Position.Y.Offset-4,b.Position.Y.Offset+b.Size.Y.Offset+6
			local y = list.CanvasPosition.Y
			if top < y then y = top elseif bottom > y+h then y = bottom-h end
			list.CanvasPosition = Vector2.new(0,math.clamp(y,0,math.max(0,358-h)))
		end)
		b.SelectionLost:Connect(function() feedback(false,false) end)
		b.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then feedback(true,true) end end)
		b.InputEnded:Connect(function() feedback(false,false) end)
		b.Activated:Connect(function()
			if not b.Active or not self.State then return end
			callbacks.Feedback(); callbacks.Open(id)
		end)
		self.Items[id] = { Button=b, Face=face, Heading=heading, Detail=detail, Badge=badge, Rim=rim,
			Reset=function() if tween then tween:Cancel(); tween=nil end; face.Position=UDim2.new(); rim.Color=theme.Ink end }
	end
	tile("Obbies","RIZZ ROUTES","Climb for Aura + pets",UDim2.fromOffset(4,4),UDim2.new(1,-8,0,88),theme.Surface,true,false)
	tile("Upgrades","POWER","Make every tap count",UDim2.fromOffset(4,104),UDim2.new(.5,-9,0,90),theme.Accent,false,false)
	tile("Pets","SQUAD","Build your hype squad",UDim2.new(.5,5,0,104),UDim2.new(.5,-9,0,90),theme.Purple,false,false)
	tile("Worlds","WORLDS","Find the next island",UDim2.fromOffset(4,204),UDim2.new(.5,-9,0,90),theme.Blue,false,false)
	tile("Goals","DAILY Ws","Tasks + login rewards",UDim2.new(.5,5,0,204),UDim2.new(.5,-9,0,90),theme.Danger,false,false)
	tile("Shop","SHOP","",UDim2.fromOffset(4,306),UDim2.new(.5,-9,0,44),theme.Gold,false,true)
	tile("Settings","SETTINGS","",UDim2.new(.5,5,0,306),UDim2.new(.5,-9,0,44),theme.Blue,false,true)
	-- Explicit links keep gamepad traversal predictable even in the scroll viewport.
	local items = self.Items
	items.Obbies.Button.NextSelectionDown = items.Upgrades.Button
	items.Obbies.Button.NextSelectionUp = close
	items.Obbies.Button.NextSelectionLeft = items.Obbies.Button; items.Obbies.Button.NextSelectionRight = items.Obbies.Button
	for _, pair in { {"Upgrades","Pets"}, {"Worlds","Goals"}, {"Shop","Settings"} } do
		items[pair[1]].Button.NextSelectionRight = items[pair[2]].Button
		items[pair[1]].Button.NextSelectionLeft = items[pair[1]].Button
		items[pair[2]].Button.NextSelectionLeft = items[pair[1]].Button
		items[pair[2]].Button.NextSelectionRight = items[pair[2]].Button
	end
	for _, column in { {"Upgrades","Worlds","Shop"}, {"Pets","Goals","Settings"} } do
		for i,id in column do
			items[id].Button.NextSelectionUp = if i==1 then items.Obbies.Button else items[column[i-1]].Button
			items[id].Button.NextSelectionDown = if i==#column then close else items[column[i+1]].Button
		end
	end
	close.NextSelectionDown = items.Obbies.Button
	close.NextSelectionUp = items.Settings.Button
	close.NextSelectionLeft = close; close.NextSelectionRight = close
	function self:Resize(width,height)
		if self.OpenTween then self.OpenTween:Cancel(); self.OpenTween = nil end
		local w,h = math.min(364,width-24),math.min(468,math.max(160,height-80))
		frame.Size = UDim2.fromOffset(w,h); shadow.Size = frame.Size
		footer.Text = if h-108 < 358 then "SCROLL FOR MORE  ↓" else "CLICK. CLIMB. COLLECT."
		list.CanvasPosition = Vector2.new(0,math.min(list.CanvasPosition.Y,math.max(0,358-(h-108))))
		self.Position = UDim2.new(1,-w-12,0,64); frame.Position = self.Position
		shadow.Position = UDim2.new(1,-w-9,0,69)
	end
	function self:SetVisible(visible)
		local wasVisible = frame.Visible
		if self.OpenTween then self.OpenTween:Cancel(); self.OpenTween = nil end
		frame.Visible = visible; shadow.Visible = visible; dismiss.Visible = visible
		if callbacks.Visibility then callbacks.Visibility(visible) end
		if not visible or not wasVisible then for _,item in self.Items do item.Reset() end end
		if visible and not wasVisible then
			list.CanvasPosition = Vector2.zero
			local state = callbacks.GetState()
			if state and state.Settings.Effects then
				frame.Position = UDim2.new(self.Position.X.Scale,self.Position.X.Offset+6,0,68)
				self.OpenTween = TweenService:Create(frame,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=self.Position}); self.OpenTween:Play()
			end
			if UserInputService.GamepadEnabled then GuiService.SelectedObject = items.Obbies.Button end
		elseif not visible and wasVisible then
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(frame) then GuiService.SelectedObject = nil end
		end
	end
	function self:Update(state, ready)
		self.State = state
		for _,item in items do item.Button.Active = state ~= nil end
		if not state then return end
		local pets,worlds,clears = 0,0,0
		for _ in state.Pets do pets += 1 end
		for _,owned in state.Worlds do if owned then worlds += 1 end end
		for _,done in state.Obby.FirstClear do if done then clears += 1 end end
		items.Obbies.Detail.Text = if state.ObbyRun then state.ObbyRun.Stage.." / "..state.ObbyRun.Count.." jumps · continue" else clears.." / 15 first clears · Aura + pets"
		items.Upgrades.Detail.Text = "Power "..(state.Upgrade+1).." · level "..state.Level
		items.Pets.Detail.Text = pets.." / 25 collected"
		items.Worlds.Detail.Text = worlds.." / 5 islands open"
		items.Goals.Detail.Text = if ready>0 then ready.." rewards ready" else "Tasks + login rewards"
		items.Goals.Badge.Text = tostring(ready).." READY"; items.Goals.Badge.Visible = ready>0
	end
	return self
end
return Menu
