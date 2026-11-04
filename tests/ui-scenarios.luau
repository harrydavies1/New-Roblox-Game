-- Real UI and PetFactory modules are inserted by tools/test_contracts.py.
local Config=require("../src/shared/Config")
local Engine=require("../src/shared/Economy").new(Config)
local Format=require("../src/shared/Format")
local Objectives=require("../src/shared/Objectives")
local count,previews,requests=0,0,0
local function encode(value)
 if type(value)=="string" then return string.format("%q",value) end
 if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
 local fields={}
 if #value>0 then for _,item in value do table.insert(fields,encode(item)) end; return "["..table.concat(fields,",").."]" end
 for key,item in value do table.insert(fields,encode(key)..":"..encode(item)) end
 return "{"..table.concat(fields,",").."}"
end
local function exportLayout(ui,kind)
 local rows={}
 local function color(value)
  if not value then return "#000000" end
  return string.format("#%02x%02x%02x",math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5))
 end
 local function visit(item,px,py,pw,ph,clips)
  if not item:IsA("GuiObject") or not item.Visible then return end
  local w,h=item.Size.X.Scale*pw+item.Size.X.Offset,item.Size.Y.Scale*ph+item.Size.Y.Offset
  local anchor=item.AnchorPoint or Vector2.zero
  local x,y=px+item.Position.X.Scale*pw+item.Position.X.Offset-anchor.X*w,py+item.Position.Y.Scale*ph+item.Position.Y.Offset-anchor.Y*h
  local radius=0; local border=""; local thickness=1
  for _,child in item:GetChildren() do
   if child.ClassName=="UICorner" then radius=child.CornerRadius.Offset+child.CornerRadius.Scale*math.min(w,h) end
   if child.ClassName=="UIStroke" then border=color(child.Color); thickness=child.Thickness end
  end
  local row={X=x,Y=y,W=w,H=h,Fill=color(item.BackgroundColor3),Alpha=1-(item.BackgroundTransparency or 0),Radius=radius,Border=border,BorderWidth=thickness,Rotation=item.Rotation or 0,Clips=clips,
   Text=item.Text or "",TextColor=color(item.TextColor3),FontSize=item.TextSize or 12,Bold=tostring(item.Font or ""):find("Bold")~=nil,Font=tostring(item.Font or ""),Align=tostring(item.TextXAlignment or "Left")}
  table.insert(rows,row)
  local childClips=table.clone(clips)
  if item.ClipsDescendants or item:IsA("ScrollingFrame") then table.insert(childClips,{x,y,w,h,radius}) end
  local scroll=item.CanvasPosition or Vector2.zero
  for _,child in item:GetChildren() do visit(child,x-scroll.X,y-scroll.Y,w,h,childClips) end
  if border~="" then
   local edge=table.clone(row); edge.Text=""; edge.Alpha=0; table.insert(rows,edge)
  end
 end
 for _,item in ui.Screen:GetChildren() do visit(item,0,0,ui.Viewport.X,ui.Viewport.Y,{}) end
 print("UI_LAYOUT "..encode({Width=ui.Viewport.X,Height=ui.Viewport.Y,Name=kind or tostring(ui.Viewport.X),Rows=rows}))
end
local function view(p,live)
 local s=Engine.Clone(p); s.Receipts=nil; s.Sandbox=not live; s.Passes=if live then {VIP=true,ExtraPets=true,DoubleAura=true} else {}
 local ctx={Now=8640010,Passes=s.Passes}
 s.EquipSlots=Engine:EquipSlots(ctx); s.PetMultiplier=Engine:PetMultiplier(p,ctx); s.ClickValue=Engine:ClickValue(p,ctx)
 s.XPRequired=Engine:XPRequired(p.Level); s.UpgradeCost=Engine:UpgradeCost(p.Upgrade); s.RebirthCost=Engine:RebirthCost(p.Rebirths); s.Catalog={}
 s.ServerTime=8640010; s.Save={Persistent=live,State=if live then "saved" else "preview",LastSavedAt=s.ServerTime}
 s.LoginStatus=Engine:LoginStatus(p,s.ServerTime); s.Objective=Objectives.get(p,Config,Engine)
 for _,group in {Config.Products,Config.Passes} do for _,item in group do s.Catalog[item.Key]={Enabled=live,Price=49,Id=123} end end
 return s
end
for _,size in {{320,568},{390,844},{844,390},{1280,720},{1920,1080}} do
 for phase=1,3 do
  camera.ViewportSize=Vector2.new(size[1],size[2])
  local p=Engine:NewProfile(); Engine:Initialize(p,8640010); local live=phase==3
  if live then p.Login.FirstSeenAt=8640010-86400 end
  if phase>1 then p.Aura=1e6; p.FlexGems=100; p.Level=40; p.Upgrade=6
   for _,w in Config.Worlds do p.Worlds[w.Id]=true end
   for _,pet in Config.Pets do p.Pets[pet.Id]=if phase==3 then 10 else 1 end
   p.Equipped={"bunny","pup","fox"}
  end
  local ui=UI.new(Config,Engine,Format,{
   Click=function() end,Feedback=function() end,
   Action=function(name,payload) requests+=1; local ok,message=Engine:Apply(p,name,payload,{Now=8640010,Passes={}}); return {Ok=ok,Message=message,State=view(p,live)} end,
   PetPreview=function(viewport,d,level) local pet=PetFactory.Create(d,level); pet.Model.Parent=viewport; assert(#pet.Model:GetChildren()>=14); previews+=1 end,
  })
  ui.Menu.Items.Obbies.Button.Activated:Fire(); assert(ui.Panel==nil,"an unloaded menu cannot invoke gameplay panels")
  ui:Update(view(p,live)); ui:Pulse(); assert(ui.PanelFrame.Size.X.Offset<=size[1])
  if phase==1 and (size[1]==320 or size[1]==1280) then
   local preview=view(p,true); preview.Aura=412; preview.TotalClicks=74; preview.Level=2; preview.XP=14; preview.XPRequired=Engine:XPRequired(2); preview.Objective=Objectives.get(preview,Config,Engine)
   ui:Update(preview); exportLayout(ui); ui:Update(view(p,live))
  end
  local width,height=ui.Viewport.X,ui.Viewport.Y
  local covered=0
  for _,item in ui.HudElements do
   if item.Visible then
    local w,h=item.Size.X.Scale*width+item.Size.X.Offset,item.Size.Y.Scale*height+item.Size.Y.Offset
    local anchor=item.AnchorPoint or Vector2.zero
    local x,y=item.Position.X.Scale*width+item.Position.X.Offset-anchor.X*w,item.Position.Y.Scale*height+item.Position.Y.Offset-anchor.Y*h
    assert(x>=0 and y>=0 and x+w<=width+.01 and y+h<=height+.01,"HUD outside safe area")
    covered+=w*h
   end
  end
  assert(covered/(width*height)<.25,"HUD covers too much play space")
  if width>=1000 then assert(covered/(width*height)<.08) end
  for _,name in {"Obbies","Pets","Worlds","Goals","Upgrades","Shop","Settings"} do
   ui:Open(name); assert(ui.Panel==name and ui.PanelFrame.Visible); ui:Update(view(p,live))
   if name=="Pets" then for _,w in Config.Worlds do ui.PetWorld=w.Id; ui:Render(); ui:Update(view(p,live)); count+=1 end
   elseif name=="Obbies" then for _,w in Config.Worlds do ui.CourseWorld=w.Id; ui.SelectedCourse=nil; ui:Render(); ui:Update(view(p,live)); count+=1 end
   elseif name=="Shop" then for _,tab in {"Boosts","Aura","FlexGems","Cosmetics","Passes"} do ui.Tab=tab; ui:Render(); ui:Update(view(p,live)); count+=1 end
   elseif name=="Goals" then for _,tab in {"Daily","Journal","Login"} do ui.GoalsTab=tab; ui:Render(); ui:Update(view(p,live)); count+=1 end end
   count+=1; ui:Close(); assert(not ui.PanelFrame.Visible)
  end
  for _,name in {"Obbies","Upgrades","Pets","Worlds","Goals","Shop","Settings"} do
   ui:ToggleMenu(); assert(ui.MenuFrame.Visible and ui.Menu.Dismiss.Visible and ui.Menu.Shadow.Visible)
   local list=ui.Menu.List; local listW=ui.MenuFrame.Size.X.Offset+list.Size.X.Offset
   local rectangles={}
   for id,item in ui.Menu.Items do
    local b=item.Button
    local x,y=b.Position.X.Scale*listW+b.Position.X.Offset,b.Position.Y.Offset
    local w,h=b.Size.X.Scale*listW+b.Size.X.Offset,b.Size.Y.Offset
    assert(x>=0 and y>=0 and x+w<=listW and y+h+4<=list.CanvasSize.Y.Offset,"menu targets must fit their scroll canvas")
    assert(h>=44,"menu touch targets must remain accessible")
    for _,r in rectangles do assert(x>=r.X+r.W or r.X>=x+w or y>=r.Y+r.H or r.Y>=y+h,"menu targets overlap") end
    table.insert(rectangles,{X=x,Y=y,W=w,H=h})
   end
   ui.Menu.Items[name].Button.Activated:Fire()
   assert(ui.Panel==name and not ui.MenuFrame.Visible and not ui.Menu.Dismiss.Visible and not ui.Menu.Shadow.Visible,"each tile must open its corresponding panel")
   ui:Close(); count+=1
  end
  if phase==2 then
   ui.Tab="Cosmetics"; ui:Open("Shop"); local choice
   for _,o in ui.Body:GetDescendants() do if o.ClassName=="TextButton" and o.Text=="60 Flex Gems · guaranteed style" then choice=o; break end end
   assert(choice); choice.Activated:Fire(); assert(ui.ConfirmFrame.Visible); assert(p.FlexGems==100)
   ui.ConfirmAccept.Activated:Fire(); assert(p.FlexGems==40 and p.Cosmetics.mint==true); count+=1
  elseif phase==1 then
   ui.Tab="FlexGems"; ui:Open("Shop"); local before=requests; local unavailable=0
   for _,o in ui.Body:GetDescendants() do if o.ClassName=="TextButton" and o.Text=="Currently unavailable" then assert(o.Active==false); o.Activated:Fire(); unavailable+=1 end end
   assert(unavailable==3 and requests==before); count+=1
  end
  ui:Close()
  if phase==1 then
   services.UserInputService.GamepadEnabled=true
   ui:ToggleMenu(); assert(services.GuiService.SelectedObject==ui.Menu.Items.Obbies.Button)
   ui.Menu.Items.Upgrades.Button.SelectionGained:Fire()
   ui.Menu.Items.Upgrades.Button.InputBegan:Fire({UserInputType=Enum.UserInputType.Touch})
   ui:ToggleMenu(); assert(services.GuiService.SelectedObject~=ui.Menu.Items.Obbies.Button)
   assert(ui.Menu.Items.Upgrades.Face.Position.Y.Offset==0,"dismissal must release a pressed tile")
   services.UserInputService.GamepadEnabled=false
   ui.Menu:Resize(320,532); assert(ui.MenuFrame.Size.X.Offset==296 and ui.MenuFrame.Position.Y.Offset+ui.MenuFrame.Size.Y.Offset<=532)
   ui.Menu:Resize(844,354); ui.Menu.Items.Settings.Button.SelectionGained:Fire()
   assert(ui.Menu.List.CanvasPosition.Y>0,"gamepad focus must scroll small viewports to the utility controls")
   ui.Menu.Items.Obbies.Button.SelectionGained:Fire(); assert(ui.Menu.List.CanvasPosition.Y==0)
   ui.Menu:Resize(width,height)
   local ready=view(p,live); ready.Daily.Clicks=Config.Quests[1].Target
   ui:Update(ready); assert(ui.Menu.Items.Goals.Badge.Visible and ui.Menu.Items.Goals.Detail.Text:find("ready",1,true))
   if size[1]==390 then ui:ToggleMenu(); exportLayout(ui,"menu-rewards-phone"); ui:ToggleMenu() end
   ui:Update(view(p,live)); assert(not ui.Menu.Items.Goals.Badge.Visible,"claimed or unavailable rewards must not leave a stale badge")
   services.UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.M},false); assert(ui.MenuFrame.Visible)
   services.UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.M},true); assert(ui.MenuFrame.Visible,"chat-processed input must not toggle the menu")
   services.UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.M},false); assert(not ui.MenuFrame.Visible)
   count+=3
   ui:Open("Settings")
   local function choose(caption)
    for _,o in ui.Body:GetDescendants() do if o:IsA("TextButton") and o.Text==caption then o.Activated:Fire(); return end end
    error("Missing settings control: "..caption)
   end
   choose("+"); assert(p.Settings.MusicVolume==75)
   choose("−"); assert(p.Settings.MusicVolume==50)
   choose("Music on · mute"); assert(not p.Settings.Music and p.Settings.SFX)
   choose("Music off · enable"); assert(p.Settings.Music)
   ui:Close(); count+=3
   ui:ShowReward({Course="Hop to the Top",RouteId="meadow_sky",Pet="meadow_sky",Amount=3500,XP=350,First=true})
   assert(ui.RewardFrame.Visible and ui.LastReward.Pet=="meadow_sky")
   local box=ui.RewardFrame; local w,h=box.Size.X.Offset,box.Size.Y.Offset
   local x,y=box.Position.X.Scale*width+box.Position.X.Offset,box.Position.Y.Scale*height+box.Position.Y.Offset
   assert(x>=0 and y>=0 and x+w<=width and y+h<=height,"prize reveal must fit the safe view")
   if size[1]==320 then exportLayout(ui,"prize-phone") end
   ui:ToggleMenu(); assert(not ui.RewardFrame.Visible,"menu must stay usable after winning")
   assert(ui.MenuFrame.Position.Y.Offset+ui.MenuFrame.Size.Y.Offset<=height,"menu must fit landscape as well as portrait")
   if size[1]==1280 then exportLayout(ui,"menu-desktop") end
   if size[1]==320 then exportLayout(ui,"menu-phone") end
   if size[1]==844 then exportLayout(ui,"menu-landscape") end
   ui:Close(); assert(ui.RewardFrame.Visible)
   local squad
   for _,o in ui.RewardFrame:GetDescendants() do if o:IsA("TextButton") and o.Text=="VIEW HYPE SQUAD" then squad=o end end
   assert(squad); squad.Activated:Fire(); assert(ui.Panel=="Pets" and ui.PetWorld=="meadow" and not ui.RewardFrame.Visible)
   ui:Close(); ui.RewardVisible=false; ui.RewardFrame.Visible=false
   ui:ShowReward({Course="Warm-up Circuit",Amount=800,XP=90,First=true}); assert(ui.LastReward.Pet==nil)
   count+=2
  end
  ui:Close(); ui.Screen:Destroy()
 end
end
assert(previews==555,previews)
print(string.format("PASS: %d headless UI scenarios, %d pet model previews across five viewports",count,previews))
