--!nonstrict
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local UI={}
local C={Ink=Color3.fromRGB(35,31,59),Muted=Color3.fromRGB(110,103,137),Paper=Color3.fromRGB(255,251,243),Card=Color3.fromRGB(244,239,255),Mint=Color3.fromRGB(111,233,186),Pink=Color3.fromRGB(255,153,206),Gold=Color3.fromRGB(255,220,124),Purple=Color3.fromRGB(188,164,255),Sky=Color3.fromRGB(130,222,255)}
local function make(class,properties,parent)
 local o=Instance.new(class); for k,v in properties do o[k]=v end; o.Parent=parent; return o
end
local function rounded(o,r) make("UICorner",{CornerRadius=UDim.new(0,r or 16)},o) end
local function text(parent,value,size,pos,dimensions,color,bold)
 return make("TextLabel",{BackgroundTransparency=1,Text=value,TextSize=size,TextColor3=color or C.Ink,Font=if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Position=pos,Size=dimensions},parent)
end
local function button(parent,value,pos,size,color,callback)
 local b=make("TextButton",{Text=value,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=C.Ink,Position=pos,Size=size,BackgroundColor3=color or C.Mint,BorderSizePixel=0,AutoButtonColor=true},parent)
 rounded(b,12); b.Activated:Connect(function() if b.Active and b.Interactable then callback() end end); return b
end
local function bar(parent,y,color)
 local track=make("Frame",{Position=UDim2.fromOffset(16,y),Size=UDim2.new(1,-32,0,7),BackgroundColor3=Color3.fromRGB(223,218,235),BorderSizePixel=0},parent); rounded(track,5)
 local fill=make("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=color,BorderSizePixel=0},track); rounded(fill,5); return fill
end
function UI.new(config,engine,format,callbacks)
 local self={State=nil,Panel=nil,Bindings={},Tab="Aura",GoalsTab="Daily",PetWorld="meadow",Pending=false,ToastId=0}
 local screen=make("ScreenGui",{Name="MogHUD",ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=10},Players.LocalPlayer:WaitForChild("PlayerGui")); self.Screen=screen
 local root=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},screen)
 local title=text(root,"MOG / MODE",19,UDim2.fromOffset(20,6),UDim2.new(.6,-20,0,28),C.Paper,true)
 make("UIStroke",{Color=C.Ink,Thickness=1.2},title)
 local badge=text(root,"LOADING…",10,UDim2.new(1,-310,0,9),UDim2.fromOffset(290,22),C.Paper,true); badge.TextXAlignment=Enum.TextXAlignment.Right
 local resources=make("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(16,40),Size=UDim2.new(1,-32,0,64)},root)
 local hud={}
 for i,d in {{"AURA",C.Gold},{"FLEX GEMS",C.Purple},{"LEVEL",C.Mint}} do
  local card=make("Frame",{Position=UDim2.new((i-1)/3,3,0,0),Size=UDim2.new(1/3,-6,1,0),BackgroundColor3=C.Paper,BorderSizePixel=0},resources); rounded(card)
  make("UIStroke",{Color=d[2],Thickness=2},card)
  text(card,d[1],10,UDim2.fromOffset(12,7),UDim2.new(1,-24,0,16),C.Muted,true)
  hud[i]=text(card,"—",23,UDim2.fromOffset(12,24),UDim2.new(1,if i<3 then -56 else -24,0,31),C.Ink,true)
  if i<3 then button(card,"+",UDim2.new(1,-40,0,15),UDim2.fromOffset(32,36),d[2],function() self.Tab=if i==1 then "Aura" else "FlexGems"; self:Open("Shop") end) end
 end
 local xpTrack=make("Frame",{Position=UDim2.fromOffset(20,110),Size=UDim2.new(1,-40,0,6),BackgroundColor3=C.Ink,BackgroundTransparency=.3,BorderSizePixel=0},root); rounded(xpTrack,4)
 local xp=make("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.Mint,BorderSizePixel=0},xpTrack); rounded(xp,4)
 local xpCaption=text(root,"",9,UDim2.fromOffset(20,116),UDim2.new(1,-40,0,12),C.Paper,true); xpCaption.TextXAlignment=Enum.TextXAlignment.Center
 make("UIStroke",{Color=C.Ink,Thickness=1},xpCaption)
 local nav=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollBarThickness=0},root)
 local navLayout=make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},nav)
 local navButtons={}
 for i,d in {{"Pets","PAW",C.Pink},{"Worlds","MAP",C.Sky},{"Goals","GO!",C.Gold},{"Upgrades","UP",C.Mint},{"Shop","STYLE",C.Purple},{"Settings","…",C.Card}} do
  local b=button(nav,d[2].."\n"..d[1],UDim2.new(),UDim2.fromOffset(84,64),d[3],function() self:Open(d[1]) end); b.LayoutOrder=i; b.TextSize=12; navButtons[i]=b
 end
 local clickButton=button(root,"MOG!",UDim2.new(.5,0,1,-20),UDim2.fromOffset(246,80),C.Gold,callbacks.Click)
 clickButton.AnchorPoint=Vector2.new(.5,1); clickButton.TextSize=21
 make("UIGradient",{Color=ColorSequence.new(C.Gold,Color3.fromRGB(255,177,126)),Rotation=22},clickButton)
 make("UIStroke",{Color=Color3.fromRGB(255,250,217),Thickness=3},clickButton)
 self.ClickScale=make("UIScale",{Scale=1},clickButton)
 local clickInfo=text(root,"Click / tap • F / X",12,UDim2.new(.5,-175,1,-14),UDim2.fromOffset(350,18),C.Paper,true); clickInfo.TextXAlignment=Enum.TextXAlignment.Center
 local hint=text(root,"Loading your adventure…",13,UDim2.new(0,20,1,-139),UDim2.new(1,-40,0,30),C.Paper,true); hint.TextXAlignment=Enum.TextXAlignment.Center
 make("UIStroke",{Color=C.Ink,Thickness=1.5},hint)
 local toast=text(root,"",16,UDim2.fromOffset(24,189),UDim2.new(1,-48,0,62),C.Paper,true)
 toast.BackgroundColor3=C.Ink; toast.BackgroundTransparency=.12; toast.TextXAlignment=Enum.TextXAlignment.Center; toast.Visible=false; toast.ZIndex=20; rounded(toast,18)
 local backdrop=make("TextButton",{Size=UDim2.fromScale(1,1),Text="",BackgroundColor3=C.Ink,BackgroundTransparency=.42,AutoButtonColor=false,Visible=false,ZIndex=5},root)
 local panel=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,26),Size=UDim2.fromOffset(760,520),BackgroundColor3=C.Paper,BorderSizePixel=0,Visible=false,ZIndex=6,Active=true},root); rounded(panel,24)
 make("UIStroke",{Color=C.Purple,Thickness=2},panel)
 local panelTitle=text(panel,"",24,UDim2.fromOffset(22,14),UDim2.new(1,-90,0,36),C.Ink,true)
 local close=button(panel,"×",UDim2.new(1,-58,0,14),UDim2.fromOffset(42,42),C.Card,function() self:Close() end); close.TextSize=27
 backdrop.Activated:Connect(function() self:Close() end)
 local body=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(14,65),Size=UDim2.new(1,-28,1,-79),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=5,ScrollBarImageColor3=C.Purple,ScrollingDirection=Enum.ScrollingDirection.Y},panel)
 make("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},body)
 make("UIPadding",{PaddingBottom=UDim.new(0,8),PaddingRight=UDim.new(0,8)},body)
 self.PanelFrame=panel; self.Backdrop=backdrop; self.Body=body
 local confirm=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Ink,BackgroundTransparency=.2,Visible=false,ZIndex=30,Active=true},root); self.ConfirmFrame=confirm
 local confirmCard=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-48,0,260),BackgroundColor3=C.Paper,BorderSizePixel=0},confirm); rounded(confirmCard,22)
 make("UISizeConstraint",{MaxSize=Vector2.new(500,300)},confirmCard)
 local confirmTitle=text(confirmCard,"",23,UDim2.fromOffset(22,18),UDim2.new(1,-44,0,42),C.Ink,true)
 local confirmBody=text(confirmCard,"",15,UDim2.fromOffset(22,65),UDim2.new(1,-44,0,116),C.Muted,false)
 button(confirmCard,"Cancel",UDim2.new(0,20,1,-62),UDim2.new(.5,-30,0,44),C.Card,function() confirm.Visible=false; self.ConfirmAction=nil end)
 self.ConfirmAccept=button(confirmCard,"Confirm",UDim2.new(.5,10,1,-62),UDim2.new(.5,-30,0,44),C.Mint,function()
  confirm.Visible=false; local callback=self.ConfirmAction; self.ConfirmAction=nil; if callback then callback() end
 end)
 local function resize()
  local camera=workspace.CurrentCamera; if not camera then return end
  local top,bottom=GuiService:GetGuiInset(); local width,height=camera.ViewportSize.X,camera.ViewportSize.Y-top.Y-bottom.Y
  if root.AbsoluteSize and root.AbsoluteSize.X>0 and root.AbsoluteSize.Y>0 then width,height=root.AbsoluteSize.X,root.AbsoluteSize.Y end
  local mobile=width<780
  panel.Size=UDim2.fromOffset(math.min(760,width-28),math.max(205,math.min(550,height-154)))
  nav.Position=if mobile then UDim2.fromOffset(16,130) else UDim2.fromOffset(20,147)
  nav.Size=if mobile then UDim2.new(1,-32,0,57) else UDim2.new(0,90,1,-320)
  nav.AutomaticCanvasSize=if mobile then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
  nav.ScrollingDirection=if mobile then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
  navLayout.FillDirection=if mobile then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
  for _,b in navButtons do b.Size=if mobile then UDim2.fromOffset(74,49) else UDim2.fromOffset(84,64) end
  title.TextSize=if mobile then 15 else 19; title.Text=if width<570 then "MOG MODE" else "MOG / MODE"
  badge.Size=UDim2.fromOffset(if mobile then 165 else 290,22); badge.Position=UDim2.new(1,if mobile then -183 else -310,0,9); badge.TextSize=if mobile then 9 else 10
  for _,label in hud do label.TextSize=if mobile then 19 else 23 end
  hint.Visible=height>=470; clickButton.Size=if height<470 then UDim2.fromOffset(206,59) else UDim2.fromOffset(246,80)
  clickButton.TextSize=if height<470 then 17 else 21; toast.Position=UDim2.fromOffset(24,if mobile then 189 else 135)
 end
 local cameraConnection
 local function bindCamera()
  if cameraConnection then cameraConnection:Disconnect() end
  if workspace.CurrentCamera then cameraConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end; resize()
 end
 workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera); root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); bindCamera()
 UserInputService.InputBegan:Connect(function(input,processed)
  if processed then return end
  if (input.KeyCode==Enum.KeyCode.F or input.KeyCode==Enum.KeyCode.ButtonX) and not self.Panel and not confirm.Visible then callbacks.Click() end
  if input.KeyCode==Enum.KeyCode.ButtonB then self:Close() end
 end)
 function self:Toast(message,success)
  self.ToastId+=1; local id=self.ToastId; toast.Text=message; toast.TextColor3=if success==false then C.Gold else C.Paper; toast.Visible=true
  task.delay(3.5,function() if self.ToastId==id then toast.Visible=false end end)
 end
 function self:Confirm(heading,message,label,callback)
  confirmTitle.Text=heading; confirmBody.Text=message; self.ConfirmAccept.Text=label; self.ConfirmAction=callback; confirm.Visible=true
  if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.ConfirmAccept end
 end
 function self:Close() self.Panel=nil; panel.Visible=false; backdrop.Visible=false; confirm.Visible=false; self.ConfirmAction=nil end
 function self:Open(name)
  if not self.State then self:Toast("Your adventure is still loading."); return end
  if self.Panel==name then self:Close(); return end
  self.Panel=name; panel.Visible=true; backdrop.Visible=true; callbacks.Feedback("Panel"); self:Render()
 end
 function self:Request(name,payload)
  if self.Pending or not self.State then return end; self.Pending=true
  task.spawn(function()
   local ok,result=pcall(callbacks.Action,name,payload); self.Pending=false
   if not ok or type(result)~="table" then self:Toast("Connection interrupted. Please try again.",false); return end
   if result.State then self:Update(result.State) end
   if result.Message then self:Toast(result.Message,result.Ok) end
   callbacks.Feedback(if result.Ok then "Success" else "Error"); if self.Panel then self:Render() end
  end)
 end
 function self:Bind(callback) table.insert(self.Bindings,callback); callback(self.State) end
 function self:Note(message,height)
  local label=text(body,message,13,UDim2.new(),UDim2.new(1,-4,0,height or 52),C.Muted,false); label.LayoutOrder=#body:GetChildren(); return label
 end
 function self:Card(heading,description,color,height)
  local card=make("Frame",{Size=UDim2.new(1,-4,0,height or 137),BackgroundColor3=C.Card,BorderSizePixel=0,LayoutOrder=#body:GetChildren()},body); rounded(card)
  local stripe=make("Frame",{Position=UDim2.fromOffset(0,12),Size=UDim2.new(0,5,1,-24),BackgroundColor3=color,BorderSizePixel=0},card); rounded(stripe,3)
  text(card,heading,17,UDim2.fromOffset(16,9),UDim2.new(1,-30,0,27),C.Ink,true)
  local label=text(card,description,12,UDim2.fromOffset(16,37),UDim2.new(1,-30,0,if (height or 137)>=170 then 48 else 32),C.Muted,false); label.Name="Description"
  return card
 end
 function self:CardButton(card,label,color,callback) return button(card,label,UDim2.new(0,16,1,-54),UDim2.new(1,-32,0,42),color,callback) end
 function self:Tabs(entries,selected,onSelect)
  local frame=make("Frame",{Size=UDim2.new(1,-4,0,44),BackgroundTransparency=1,LayoutOrder=#body:GetChildren()},body)
  for i,entry in entries do
   local b=button(frame,entry.Label,UDim2.new((i-1)/#entries,2,0,0),UDim2.new(1/#entries,-4,0,42),if selected==entry.Id then C.Purple else C.Card,function() onSelect(entry.Id); self:Render() end); b.TextSize=if #entries>3 then 11 else 13
  end
 end
 function self:OfferPurchase(key,name,description)
  local offer=self.State.Catalog[key]; if not offer or not offer.Enabled then return end
  self:Confirm(name,description.."\nListed price: R$ "..offer.Price..". Roblox's next window shows the final price. This purchase is optional.","Continue to Roblox",function() self:Request("Purchase",{Id=key}) end)
 end
 function self:Render()
  self.Bindings={}; for _,child in body:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
  panelTitle.Text=self.Panel or ""; body.CanvasPosition=Vector2.zero; local p=self.State; if not p then return end
  if self.Panel=="Pets" then
   self:Note("Adopt exactly the pet you choose with Aura. Train to level 10. Equipped bonuses add together; no random eggs.",48)
   local tabs={}; for _,world in config.Worlds do table.insert(tabs,{Id=world.Id,Label=world.Icon.." "..({meadow="Meadow",candy="Gym",coral="Reef",cosmos="Stars"})[world.Id]}) end
   self:Tabs(tabs,self.PetWorld,function(id) self.PetWorld=id end)
   local summary=self:Note("",28); self:Bind(function(s) summary.Text=#s.Equipped.."/"..s.EquipSlots.." equipped • "..string.format("%.2f",s.PetMultiplier).."× pet multiplier" end)
   for _,pet in config.Pets do
    if pet.World~=self.PetWorld then continue end
    local card=self:Card(pet.Name,pet.Description,Color3.fromHex(pet.Color),154)
    for _,label in card:GetChildren() do if label:IsA("TextLabel") then label.Position=UDim2.fromOffset(86,label.Position.Y.Offset); label.Size=UDim2.new(1,-102,0,label.Size.Y.Offset) end end
    local viewport=make("ViewportFrame",{Position=UDim2.fromOffset(12,7),Size=UDim2.fromOffset(64,64),BackgroundTransparency=1,Ambient=Color3.fromRGB(220,215,245),LightColor=Color3.fromRGB(255,242,214),LightDirection=Vector3.new(-1,-1,-1)},card)
    callbacks.PetPreview(viewport,pet,p.Pets[pet.Id] or 1)
    local detail=text(card,"",12,UDim2.fromOffset(16,70),UDim2.new(1,-32,0,20),C.Muted,true)
    local buy=button(card,"",UDim2.new(0,16,1,-54),UDim2.new(.66,-23,0,42),C.Gold,function() self:Request("BuyPet",{Id=pet.Id}) end)
    local equip=button(card,"",UDim2.new(.66,0,1,-54),UDim2.new(.34,-16,0,42),C.Mint,function() self:Request("EquipPet",{Id=pet.Id}) end)
    self:Bind(function(s)
     local level=s.Pets[pet.Id] or 0; detail.Text="Lv "..level.." • "..format.percent(engine:PetBonus(pet.Id,math.max(1,level))).." click bonus"
     buy.Text=if not s.Worlds[pet.World] then "Island locked" elseif level>=config.MaxPetLevel then "Fully trained" else (if level==0 then "Adopt • " else "Train • ")..format.number(engine:PetCost(pet.Id,level)).." Aura"
     buy.Active=s.Worlds[pet.World]==true and level<config.MaxPetLevel
     equip.Visible=level>0; equip.Text=if table.find(s.Equipped,pet.Id) then "Rest" else "Equip"
    end)
   end
  elseif self.Panel=="Worlds" then
   self:Note("Four islands. Four sky routes. Twelve extremely unserious pets. Every new island multiplies your Aura.",46)
   for _,world in config.Worlds do
    local card=self:Card(world.Icon.." / "..world.Name,world.Tagline.." • "..world.Multiplier.."× Aura",Color3.fromHex(world.Color),137)
    local b=self:CardButton(card,"",Color3.fromHex(world.Color),function()
     if self.State.Worlds[world.Id] then self:Request("Travel",{Id=world.Id})
     else self:Confirm("Discover "..world.Name.."?","Spend "..format.number(world.Cost).." Aura to permanently unlock this island. Requires level "..world.Level.." and the previous island.","Discover",function() self:Request("UnlockWorld",{Id=world.Id}) end) end
    end)
    self:Bind(function(s) b.Text=if s.CurrentWorld==world.Id then "You are here" elseif s.Worlds[world.Id] then "Travel to island" else "Discover • "..format.number(world.Cost).." Aura • Lv "..world.Level; b.Active=s.CurrentWorld~=world.Id end)
   end
  elseif self.Panel=="Goals" then
   self:Tabs({{Id="Daily",Label="Daily discoveries"},{Id="Journal",Label="Discovery journal"}},self.GoalsTab,function(tab) self.GoalsTab=tab end)
   self:Note(if self.GoalsTab=="Daily" then "New goals at 00:00 UTC. No login streaks to lose. World crystals regrow after 45 seconds." else "Nine permanent journal stamps and two free titles. These milestones never reset when you rebirth.",48)
   local journal=self.GoalsTab=="Journal"
   for _,goal in (if journal then config.Milestones else config.Quests) do
    local card=self:Card(goal.Name,goal.Description.." • "..format.number(goal.Aura).." Aura + "..goal.XP.." XP"..(if goal.Cosmetic then " + free title" else ""),if journal then C.Sky else C.Gold,152)
    local fill=bar(card,76,C.Mint)
    local b=self:CardButton(card,"",if journal then C.Sky else C.Gold,function() self:Request(if journal then "ClaimMilestone" else "ClaimQuest",{Id=goal.Id}) end)
    self:Bind(function(s)
     local amount=math.min(goal.Target,if journal then engine:MilestoneProgress(s,goal.Id) else s.Daily[goal.Counter])
     local claimed=if journal then s.Milestones[goal.Id] else s.Daily.Claimed[goal.Id]
     fill.Size=UDim2.fromScale(amount/goal.Target,1); b.Text=if claimed then "Reward collected" elseif amount>=goal.Target then "Collect reward" else format.number(amount).." / "..format.number(goal.Target)
     b.Active=not claimed and amount>=goal.Target
    end)
   end
  elseif self.Panel=="Upgrades" then
   local card=self:Card("Upgrade your Mog Power","Earn more Aura from every click and crystal. Your Aura, your pace.",C.Mint,137)
   local b=self:CardButton(card,"",C.Mint,function() self:Request("BuyUpgrade",{}) end)
   self:Bind(function(s) b.Text=if s.Upgrade>=config.MaxUpgrade then "Maximum Mog Power reached" else "Power "..(s.Upgrade+1).." → "..(s.Upgrade+2).." • "..format.number(s.UpgradeCost).." Aura"; b.Active=s.Upgrade<config.MaxUpgrade end)
   local rebirth=self:Card("Enter your next era","Rebirth resets ALL Aura and Mog Power upgrades. Keep islands, pets, level, styles, journal stamps, and Flex Gems. Gain another permanent +25% click bonus.",C.Purple,186)
   local info=text(rebirth,"",12,UDim2.fromOffset(16,91),UDim2.new(1,-32,0,24),C.Muted,true)
   local rb=self:CardButton(rebirth,"",C.Purple,function()
    self:Confirm("Start a new era?","Reset ALL "..format.number(self.State.Aura).." Aura and Mog Power upgrades. Keep pets, islands, level, cosmetics, journal stamps, and Flex Gems. Gain another permanent +25% click bonus.","Rebirth",function() self:Request("Rebirth",{}) end)
   end)
   self:Bind(function(s) info.Text=s.Rebirths.."/"..config.MaxRebirths.." rebirths • permanent +"..(s.Rebirths*25).."%"; rb.Text=if s.Rebirths>=config.MaxRebirths then "Rebirth summit reached" else "Rebirth • requires "..format.number(s.RebirthCost).." Aura"; rb.Active=s.Rebirths<config.MaxRebirths end)
   self:Note("Every XP level pays 40 × your new level in Aura. Every island and pet can be earned through play.")
  elseif self.Panel=="Shop" then
   self:Tabs({{Id="Aura",Label="Aura"},{Id="FlexGems",Label="Flex Gems"},{Id="Cosmetics",Label="Styles"},{Id="Passes",Label="Passes"}},self.Tab,function(tab) self.Tab=tab end)
   self:Note(if p.Sandbox then "STUDIO SANDBOX • progress is temporary and real purchases are disabled." else "Optional purchases use Robux. Roblox shows the final price before you confirm. Only buy with the account owner's permission.",48)
   if self.Tab=="Aura" or self.Tab=="FlexGems" then
    self:Note(if self.Tab=="Aura" then "Aura is also earned freely by clicking, levelling up, and exploring. These packs are optional." else "Flex Gems are paid currency available only through Robux purchases. They buy guaranteed cosmetics and never come from gameplay rewards.",53)
    for _,product in config.Products do
     if product.Currency~=self.Tab then continue end
     local card=self:Card(product.Name,product.Description,if self.Tab=="Aura" then C.Gold else C.Purple,137)
     local b=self:CardButton(card,"",if self.Tab=="Aura" then C.Gold else C.Purple,function() self:OfferPurchase(product.Key,product.Name,product.Description) end)
     self:Bind(function(s) local offer=s.Catalog[product.Key]; b.Text=if offer and offer.Enabled then "Buy • R$ "..offer.Price else "Currently unavailable"; b.Active=offer~=nil and offer.Enabled==true end)
    end
   elseif self.Tab=="Passes" then
    for _,pass in config.Passes do
     local card=self:Card(pass.Name,pass.Description,C.Mint,137)
     local b=self:CardButton(card,"",C.Mint,function() self:OfferPurchase(pass.Key,pass.Name,pass.Description) end)
     self:Bind(function(s) local offer=s.Catalog[pass.Key]; b.Text=if s.Passes[pass.Key] then "Owned • thank you!" elseif offer and offer.Enabled then "Permanent pass • R$ "..offer.Price else "Currently unavailable"; b.Active=not s.Passes[pass.Key] and offer~=nil and offer.Enabled==true end)
    end
   else
    self:Note("Choose exactly what you get. Styles are permanent. Equip one trail, orbit effect, and title at a time.",46)
    for _,item in config.Cosmetics do
     local card=self:Card(item.Name.." / "..item.Kind,item.Description,Color3.fromHex(item.Color),137)
     local b=self:CardButton(card,"",Color3.fromHex(item.Color),function()
      local owned=self.State.Cosmetics[item.Id] or (item.Pass and self.State.Passes[item.Pass])
      if owned then self:Request("EquipCosmetic",{Id=item.Id})
      elseif item.Pass then self.Tab="Passes"; self:Render()
      elseif item.Earned then self.GoalsTab="Journal"; self:Open("Goals")
      else self:Confirm("Get "..item.Name.."?","Spend "..item.Cost.." Flex Gems on this permanent "..item.Kind..". Flex Gems are paid cosmetic currency.","Spend "..item.Cost.." Flex Gems",function() self:Request("BuyCosmetic",{Id=item.Id}) end) end
     end)
     self:Bind(function(s)
      local owned=s.Cosmetics[item.Id] or (item.Pass and s.Passes[item.Pass])
      b.Text=if owned then (if s.ActiveCosmetics[item.Kind]==item.Id then "Equipped • click to remove" else "Equip style") elseif item.Pass then "View Mog Patron pass" elseif item.Earned then "Earn free in the journal" else item.Cost.." Flex Gems • guaranteed style"
     end)
    end
   end
  elseif self.Panel=="Settings" then
   self:Note("Adjust sound and extra animation independently. Settings save with your progress.",45)
   for _,option in {{Id="SFX",Name="Sound effects",Description="Soft clicks, crystals, menu, upgrade, and level sounds."},{Id="Effects",Name="Extra animations",Description="Reward pop-ups, confetti, crystal motion, pet bobbing, and mog poses."}} do
    local card=self:Card(option.Name,option.Description,C.Sky,137)
    local b=self:CardButton(card,"",C.Sky,function() self:Request("Setting",{Id=option.Id,Value=not self.State.Settings[option.Id]}) end)
    self:Bind(function(s) b.Text=if s.Settings[option.Id] then "On • click to turn off" else "Off • click to turn on" end)
   end
   self:Note("CONTROLS\nClick/tap MOG!, press F, or use controller X. Move and jump with Roblox's standard controls. Use proximity prompts at crystals, shops, and portals. On gamepad, use UI selection for menus.",108)
   self:Note("A break is always okay. Progress saves automatically. Purchases are optional and no login streaks expire.",58)
  end
  if UserInputService.GamepadEnabled then GuiService.SelectedObject=close end
 end
 function self:Update(s)
  self.State=s; hud[1].Text=format.number(s.Aura); hud[2].Text=format.number(s.FlexGems); hud[3].Text=tostring(s.Level)
  TweenService:Create(xp,TweenInfo.new(.18),{Size=UDim2.fromScale(s.XP/s.XPRequired,1)}):Play()
  xpCaption.Text=engine:Rank(s.Level).." • "..format.number(s.XP).." / "..format.number(s.XPRequired).." XP"
  badge.Text=if s.Sandbox then "STUDIO • NO SAVING / PURCHASES" else string.upper(engine.Worlds[s.CurrentWorld].Name)
  clickButton.Text="MOG!\n+"..format.number(s.ClickValue).." AURA"; clickInfo.Text="MOG METER "..(s.TotalClicks%config.BurstEvery).."/"..config.BurstEvery.." • click / F / X"
  hint.Text=if s.TotalClicks<25 then "Make your first Aura burst! "..s.TotalClicks.."/25 clicks" elseif not next(s.Pets) then "Adopt Bunny on Mute in Pets to start your hype squad!" elseif s.Upgrade<3 then "Time for a fit check: upgrade Mog Power." elseif not s.Worlds.candy then "Next stop: Brotein Boulevard • Lv 5 + 3.5K Aura" else "Collect crystals • train your hype squad • explore the next island"
  local ready=0
  for _,q in config.Quests do if not s.Daily.Claimed[q.Id] and s.Daily[q.Counter]>=q.Target then ready+=1 end end
  for _,q in config.Milestones do if not s.Milestones[q.Id] and engine:MilestoneProgress(s,q.Id)>=q.Target then ready+=1 end end
  navButtons[3].Text="GO!\nGoals"..(if ready>0 then " ("..ready..")" else "")
  for _,binding in self.Bindings do binding(s) end
 end
 function self:Pulse()
  if self.State and not self.State.Settings.Effects then return end
  self.ClickScale.Scale=.94; TweenService:Create(self.ClickScale,TweenInfo.new(.18,Enum.EasingStyle.Back),{Scale=1}):Play()
 end
 return self
end
return UI
