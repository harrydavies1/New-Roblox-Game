-- Real UI and PetFactory modules are inserted by tools/test_contracts.py.
local Config=require("../src/shared/Config")
local Engine=require("../src/shared/Economy").new(Config)
local Format=require("../src/shared/Format")
local count,previews,requests=0,0,0
local function view(p,live)
 local s=Engine.Clone(p); s.Receipts=nil; s.Sandbox=not live; s.Passes=if live then {VIP=true,ExtraPets=true,DoubleAura=true} else {}
 local ctx={Now=8640010,Passes=s.Passes}
 s.EquipSlots=Engine:EquipSlots(ctx); s.PetMultiplier=Engine:PetMultiplier(p,ctx); s.ClickValue=Engine:ClickValue(p,ctx)
 s.XPRequired=Engine:XPRequired(p.Level); s.UpgradeCost=Engine:UpgradeCost(p.Upgrade); s.RebirthCost=Engine:RebirthCost(p.Rebirths); s.Catalog={}
 for _,group in {Config.Products,Config.Passes} do for _,item in group do s.Catalog[item.Key]={Enabled=live,Price=49,Id=123} end end
 return s
end
for _,size in {{320,568},{390,844},{844,390},{1280,720},{1920,1080}} do
 for phase=1,3 do
  camera.ViewportSize=Vector2.new(size[1],size[2])
  local p=Engine:NewProfile(); Engine:RefreshDay(p,8640010); local live=phase==3
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
  for _,name in {"Pets","Worlds","Goals","Upgrades","Shop","Settings"} do
   ui:Open(name); assert(ui.Panel==name and ui.PanelFrame.Visible); ui:Update(view(p,live))
   if name=="Pets" then for _,w in Config.Worlds do ui.PetWorld=w.Id; ui:Render(); ui:Update(view(p,live)); count+=1 end
   elseif name=="Shop" then for _,tab in {"Aura","FlexGems","Cosmetics","Passes"} do ui.Tab=tab; ui:Render(); ui:Update(view(p,live)); count+=1 end
   elseif name=="Goals" then for _,tab in {"Daily","Journal"} do ui.GoalsTab=tab; ui:Render(); ui:Update(view(p,live)); count+=1 end end
   count+=1; ui:Close(); assert(not ui.PanelFrame.Visible)
  end
  if phase==2 then
   ui.Tab="Cosmetics"; ui:Open("Shop"); local choice
   for _,o in ui.Body:GetDescendants() do if o.ClassName=="TextButton" and o.Text=="60 Flex Gems • guaranteed style" then choice=o; break end end
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
assert(previews==225,previews)
print(string.format("PASS: %d headless UI scenarios, %d pet model previews across five viewports",count,previews))
