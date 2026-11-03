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
local function exportLayout(ui)
 local rows={}
 local function color(value)
  if not value then return "#000000" end
  return string.format("#%02x%02x%02x",math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5))
 end
 local function visit(item,px,py,pw,ph)
  if not item:IsA("GuiObject") or not item.Visible then return end
  local w,h=item.Size.X.Scale*pw+item.Size.X.Offset,item.Size.Y.Scale*ph+item.Size.Y.Offset
  local anchor=item.AnchorPoint or Vector2.zero
  local x,y=px+item.Position.X.Scale*pw+item.Position.X.Offset-anchor.X*w,py+item.Position.Y.Scale*ph+item.Position.Y.Offset-anchor.Y*h
  local radius=0; local border=""
  for _,child in item:GetChildren() do
   if child.ClassName=="UICorner" then radius=child.CornerRadius.Offset end
   if child.ClassName=="UIStroke" then border=color(child.Color) end
  end
  table.insert(rows,{X=x,Y=y,W=w,H=h,Fill=color(item.BackgroundColor3),Alpha=1-(item.BackgroundTransparency or 0),Radius=radius,Border=border,
   Text=item.Text or "",TextColor=color(item.TextColor3),FontSize=item.TextSize or 12,Bold=tostring(item.Font or ""):find("Bold")~=nil,Align=tostring(item.TextXAlignment or "Left")})
  for _,child in item:GetChildren() do visit(child,x,y,w,h) end
 end
 for _,item in ui.Screen:GetChildren() do visit(item,0,0,ui.Viewport.X,ui.Viewport.Y) end
 print("UI_LAYOUT "..encode({Width=ui.Viewport.X,Height=ui.Viewport.Y,Rows=rows}))
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
  ui:Close(); ui.Screen:Destroy()
 end
end
assert(previews==450,previews)
print(string.format("PASS: %d headless UI scenarios, %d pet model previews across five viewports",count,previews))
