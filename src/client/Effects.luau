--!nonstrict
local Players=game:GetService("Players")
local CollectionService=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local HttpService=game:GetService("HttpService")
local Effects={}
function Effects.new(config,engine,format,factory,ui,audio)
 local self={HiddenUntil={},Crystals={},Parties={},Styles={},Connections={},LastClick=-1,FloatCount=0}
 local folder=Instance.new("Folder"); folder.Name="MogLocalVisuals"; folder.Parent=workspace
 local function enabled(key) return not ui.State or ui.State.Settings[key] end
 function self:Sound(kind)
  audio:Play(kind)
 end
 function self:Float(amount)
  if not enabled("Effects") or self.FloatCount>=5 then return end; self.FloatCount+=1
  local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Text="+"..format.number(amount).." Aura"
  label.Font=Enum.Font.GothamMedium; label.TextSize=14; label.TextColor3=Color3.fromRGB(194,219,201); label.TextStrokeColor3=Color3.fromRGB(22,25,31); label.TextStrokeTransparency=.3
  label.Size=UDim2.fromOffset(220,40); label.AnchorPoint=Vector2.new(.5,.5); label.ZIndex=15
  local dx=math.random(-35,35); label.Position=UDim2.new(.5,dx,1,-125); label.Parent=ui.Screen
  local tween=TweenService:Create(label,TweenInfo.new(.7,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(.5,dx,1,-166),TextTransparency=1,TextStrokeTransparency=1})
  tween.Completed:Once(function() label:Destroy(); self.FloatCount-=1 end); tween:Play()
 end
 function self:Celebrate()
  self:Sound("Level"); if not enabled("Effects") then return end
  for i=1,8 do
   local p=Instance.new("Frame"); p.BorderSizePixel=0; p.Size=UDim2.fromOffset(7,11); p.Rotation=i*31; p.ZIndex=16
   p.BackgroundColor3=Color3.fromHex(({"C1AC80","88B39A","BC91AB","9E92B8","7EADB7"})[i%5+1]); p.Position=UDim2.new(.5,0,1,-120); p.Parent=ui.Screen
   TweenService:Create(p,TweenInfo.new(.9,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(.5,math.random(-95,95),1,math.random(-190,-100)),Rotation=i*80,BackgroundTransparency=1}):Play(); Debris:AddItem(p,1)
  end
 end
 function self:Handle(event)
  if event.Kind=="Clicks" then self:Float(event.Amount)
  elseif event.Kind=="Crystal" then self.HiddenUntil[event.Id]=os.clock()+event.Cooldown; self:Float(event.Amount); self:Sound("Crystal")
  elseif event.Kind=="Mog" then
   local actor=Players:GetPlayerByUserId(event.UserId); local root=actor and actor.Character and actor.Character:FindFirstChild("HumanoidRootPart"); local camera=workspace.CurrentCamera
   if not root or not camera or not enabled("Effects") or (root.Position-camera.CFrame.Position).Magnitude>120 then return end
   if self.Pose then self.Pose:Play(actor) end
   local ring=Instance.new("Part"); ring.Name="MogBurst"; ring.Shape=Enum.PartType.Cylinder; ring.Size=Vector3.new(.12,3,3)
   ring.Anchored=true; ring.CanCollide=false; ring.CanTouch=false; ring.CanQuery=false; ring.CastShadow=false
   ring.Material=Enum.Material.SmoothPlastic; ring.Color=Color3.fromRGB(126,175,151); ring.Transparency=.72
   ring.CFrame=CFrame.new(root.Position-Vector3.new(0,2.5,0))*CFrame.Angles(0,0,math.pi/2); ring.Parent=folder
   TweenService:Create(ring,TweenInfo.new(.65,Enum.EasingStyle.Quad),{Size=Vector3.new(.12,9,9),Transparency=1}):Play(); Debris:AddItem(ring,.7)
   if actor==Players.LocalPlayer then self:Sound("Mog") end
  elseif event.Kind=="OpenPanel" then if ui.Panel~=event.Panel then ui:Open(event.Panel) end
  elseif event.Kind=="OpenCourse" then ui.SelectedCourse=event.Id; if ui.Panel~="Obbies" then ui:Open("Obbies") else ui:Render() end
  elseif event.Kind=="Checkpoint" then self:Sound("Checkpoint"); if event.Amount>0 then ui:Toast("Checkpoint reached · +"..format.number(event.Amount).." Aura") end
  elseif event.Kind=="ObbyComplete" then
   if event.Practice then ui:Toast("Practice clear · rewards are still cooling down.")
   else
    self:Celebrate(); self:Sound("ObbyComplete")
    ui:Toast(event.Course.." cleared · +"..format.number(event.Amount).." Aura"..(if event.Pet then " · "..engine.Pets[event.Pet].Name.." earned!" else ""))
   end
  elseif event.Kind=="ObbyReset" then self:Sound("ObbyReset"); ui:Toast(event.Message)
  elseif event.Kind=="SaveStatus" then ui:SetSaveStatus(event.State)
  elseif event.Kind=="Purchase" then self:Sound("Purchase"); ui:Toast(event.Message); if ui.Panel then ui:Render() end
  elseif event.Kind=="TravelStart" then ui:Toast(event.Message)
  elseif event.Kind=="Travel" then self:Sound("Travel"); ui:Toast(event.Message)
  elseif event.Message then ui:Toast(event.Message) end
 end
 local function addCrystal(p) if p:IsA("BasePart") then self.Crystals[p]=p.CFrame end end
 for _,p in CollectionService:GetTagged("MogCrystal") do addCrystal(p) end
 CollectionService:GetInstanceAddedSignal("MogCrystal"):Connect(addCrystal)
 CollectionService:GetInstanceRemovedSignal("MogCrystal"):Connect(function(p) self.Crystals[p]=nil end)
 local function clearParty(player)
  local party=self.Parties[player]; if party then for _,pet in party do pet.Model:Destroy() end end; self.Parties[player]=nil
 end
 local function refresh(player)
  clearParty(player); local ok,items=pcall(HttpService.JSONDecode,HttpService,player:GetAttribute("MogPets") or "[]")
  if not ok or type(items)~="table" then return end
  local party={}; for i,item in items do
   if i>5 then break end; local definition=engine.Pets[item.Id]
   if definition then local pet=factory.Create(definition,item.Level or 1); table.insert(party,pet) end
  end; self.Parties[player]=party
 end
 local function watch(player)
  if self.Connections[player] then return end
  self.Connections[player]=player:GetAttributeChangedSignal("MogPets"):Connect(function() refresh(player) end); refresh(player)
 end
 local function clearStyle(player)
  local style=self.Styles[player]; if style then for _,o in style.Objects do o:Destroy() end; self.Styles[player]=nil end
 end
 Players.PlayerAdded:Connect(watch); for _,p in Players:GetPlayers() do watch(p) end
 Players.PlayerRemoving:Connect(function(player)
  clearParty(player); clearStyle(player); if self.Connections[player] then self.Connections[player]:Disconnect(); self.Connections[player]=nil end
 end)
 local function styleFor(player,root)
  local signature=(player:GetAttribute("MogTrail") or "").."/"..(player:GetAttribute("MogAura") or "").."/"..(player:GetAttribute("MogTitle") or "").."/"..(player:GetAttribute("MogRank") or "")..tostring(player:GetAttribute("MogPatron"))
  local old=self.Styles[player]; if old and old.Root==root and old.Signature==signature then return old end
  clearStyle(player); local style={Root=root,Signature=signature,Objects={},Orbit={}}; self.Styles[player]=style
  local function keep(o) table.insert(style.Objects,o); return o end
  local trailDef=engine.Cosmetics[player:GetAttribute("MogTrail")]
  if trailDef then
   local a=keep(Instance.new("Attachment")); a.Position=Vector3.new(-.7,-1,.5); a.Parent=root
   local b=keep(Instance.new("Attachment")); b.Position=Vector3.new(.7,-1,.5); b.Parent=root
   local trail=keep(Instance.new("Trail")); trail.Attachment0=a; trail.Attachment1=b
   trail.Color=ColorSequence.new(Color3.fromHex(trailDef.Color),Color3.fromRGB(255,240,192)); trail.Lifetime=.65; trail.MinLength=.08; trail.LightEmission=.8; trail.FaceCamera=true
   trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(1,1)}); trail.Parent=root; style.Trail=trail
  end
  local aura=engine.Cosmetics[player:GetAttribute("MogAura")]
  if aura then for i=1,5 do
   local star=keep(Instance.new("Part")); star.Name="MogAuraStar"; star.Size=Vector3.new(.25,.25,.25); star.Anchored=true; star.CanCollide=false; star.CanTouch=false; star.CanQuery=false; star.CastShadow=false
   star.Material=Enum.Material.Neon; star.Color=Color3.fromHex(aura.Color); star.Parent=folder; table.insert(style.Orbit,star)
  end end
  local titleDef=engine.Cosmetics[player:GetAttribute("MogTitle")]; local rank=player:GetAttribute("MogRank")
  local head=player.Character and player.Character:FindFirstChild("Head")
  if head and (titleDef or rank or player:GetAttribute("MogPatron")) then
   local gui=keep(Instance.new("BillboardGui")); gui.Name="MogTitle"; gui.Adornee=head; gui.Size=UDim2.fromOffset(200,30); gui.StudsOffset=Vector3.new(0,3.3,0); gui.MaxDistance=100; gui.Parent=head
   local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1; label.Text=if titleDef then titleDef.Name elseif player:GetAttribute("MogPatron") then "Mog Patron" else rank
   label.TextColor3=if titleDef then Color3.fromHex(titleDef.Color) else Color3.fromRGB(218,189,255); label.Font=Enum.Font.GothamBold; label.TextSize=13; label.TextStrokeColor3=Color3.fromRGB(38,28,61); label.TextStrokeTransparency=.2; label.Parent=gui
  end
  return style
 end
 local lastDetail=0
 RunService.RenderStepped:Connect(function(dt)
  local now=os.clock(); local animate=enabled("Effects"); local camera=workspace.CurrentCamera; if not camera then return end
  if now-lastDetail>1/30 then
   lastDetail=now
   for crystal,base in self.Crystals do
    if not crystal.Parent then self.Crystals[crystal]=nil; continue end
    local hidden=not ui.State or crystal:GetAttribute("WorldId")~=ui.State.CurrentWorld or (self.HiddenUntil[crystal:GetAttribute("CrystalId")] or 0)>now; crystal.LocalTransparencyModifier=if hidden then 1 else 0
    local prompt=crystal:FindFirstChild("CollectPrompt"); if prompt then prompt.Enabled=not hidden end
    for _,child in crystal:GetChildren() do if child:IsA("BillboardGui") then child.Enabled=not hidden end end
    if animate and not hidden and (base.Position-camera.CFrame.Position).Magnitude<180 then crystal.CFrame=base*CFrame.new(0,math.sin(now*2+base.X)*.35,0)*CFrame.Angles(0,now*.7,0)
    elseif not animate then crystal.CFrame=base end
   end
  end
  local count=0
  for player,party in self.Parties do
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   local visible=root and (root.Position-camera.CFrame.Position).Magnitude<140 and count<12; if visible then count+=1 end
   for i,pet in party do
    pet.Model.Parent=if visible then folder else nil
    if not visible then pet.Position=nil; continue end
    local column=(i-1)%3-math.min(#party-1,2)/2; local row=math.floor((i-1)/3)
    local target=root.CFrame*CFrame.new(column*2.7,-.8+(if animate then math.sin(now*3+i)*.28 else 0),4+row*2.7)
    if not pet.Position or (pet.Position.Position-target.Position).Magnitude>35 then pet.Position=target else pet.Position=pet.Position:Lerp(target,1-math.exp(-dt*9)) end
    pet.Model:PivotTo(pet.Position)
    if animate then for _,w in pet.Wings do w.Part.CFrame=pet.Position*w.Offset*CFrame.Angles(0,0,math.sin(now*7+i)*.16*w.Side) end end
   end
   if visible then
    local style=styleFor(player,root); if style.Trail then style.Trail.Enabled=animate end
    for i,star in style.Orbit do local a=i*math.pi*2/5+(if animate then now*1.4 else 0); star.CFrame=CFrame.new(root.Position+Vector3.new(math.cos(a)*2.7,-.7+math.sin(a*2)*.3,math.sin(a)*2.7))*CFrame.Angles(0,a,math.pi/4) end
   else clearStyle(player) end
  end
 end)
 return self
end
return Effects
