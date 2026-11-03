--!nonstrict
-- Original toy pets: primitives only, no uploaded art assets.
local PetFactory={}
local function part(model,name,position,size,color,shape,rotation)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Shape=shape or Enum.PartType.Ball
 p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Material=Enum.Material.SmoothPlastic
 p.CFrame=CFrame.new(position)*(rotation or CFrame.identity); p.Parent=model; return p
end
function PetFactory.Create(d,level)
 local model=Instance.new("Model"); model.Name=d.Name
 local color,accent=Color3.fromHex(d.Color),Color3.fromHex(d.Accent)
 local ink,cream=Color3.fromRGB(43,35,68),Color3.fromRGB(255,248,233)
 local body=part(model,"Body",Vector3.zero,Vector3.new(1.9,1.65,1.8),color); model.PrimaryPart=body
 local shape=d.Shape; local face=if shape=="goose" then Vector3.new(0,1.15,-.2) else Vector3.zero
 if shape=="goose" then
  part(model,"GooseNeck",Vector3.new(0,.6,-.2),Vector3.new(.8,1.8,.9),color)
  part(model,"GooseHead",Vector3.new(0,1.4,-.2),Vector3.new(1.6,1.4,1.5),color)
 end
 part(model,"Muzzle",Vector3.new(0,-.35,-.8)+face,Vector3.new(1.1,.65,.45),cream)
 for _,x in {-.43,.43} do
  part(model,"Eye",Vector3.new(x,.13,-.83)+face,Vector3.new(.24,.34,.18),ink)
  part(model,"EyeShine",Vector3.new(x-.04,.21,-.925)+face,Vector3.new(.08,.1,.06),cream)
  part(model,"Blush",Vector3.new(x*1.6,-.17,-.73)+face,Vector3.new(.32,.16,.12),accent)
  part(model,"Foot",Vector3.new(x,-.82,-.28),Vector3.new(.56,.37,.66),accent)
 end
 part(model,"Nose",Vector3.new(0,-.21,-1.03)+face,if shape=="goose" then Vector3.new(.6,.3,.55) else Vector3.new(.18,.12,.1),accent)
 local wings={}
 local function wing(x,size,tilt)
  local p=part(model,"Wing",Vector3.new(x,.1,.2),size,accent,nil,CFrame.Angles(0,0,math.rad(tilt)))
  table.insert(wings,{Part=p,Offset=p.CFrame,Side=if x<0 then -1 else 1})
 end
 if shape=="bunny" then
  for _,x in {-.5,.5} do
   part(model,"LongEar",Vector3.new(x,1.25,0),Vector3.new(.52,1.9,.55),color,nil,CFrame.Angles(0,0,-x*.2))
   part(model,"EarCenter",Vector3.new(x,1.35,-.26),Vector3.new(.24,1.2,.1),accent)
  end
 elseif shape=="pup" then
  for _,x in {-.98,.98} do part(model,"FloppyEar",Vector3.new(x,.25,0),Vector3.new(.6,1.15,.8),accent) end
 elseif shape=="cat" or shape=="fox" then
  for _,x in {-.61,.61} do
   part(model,"PointyEar",Vector3.new(x,.94,-.05),Vector3.new(.75,1.05,.65),color,Enum.PartType.Block,CFrame.Angles(0,0,math.rad(if x<0 then -28 else 28)))
   part(model,"InnerEar",Vector3.new(x,1.08,-.37),Vector3.new(.31,.5,.1),accent)
  end
  if shape=="cat" then
   for _,x in {-.43,.43} do part(model,"MogGlasses",Vector3.new(x,.2,-1),Vector3.new(.65,.32,.12),ink,Enum.PartType.Block) end
   part(model,"GlassesBridge",Vector3.new(0,.2,-1),Vector3.new(.3,.1,.12),ink,Enum.PartType.Block)
  end
 elseif shape=="axolotl" then
  for _,side in {-1,1} do for i=-1,1 do part(model,"Gill",Vector3.new(side*1.12,.25+i*.43,0),Vector3.new(.8,.3,.4),accent,nil,CFrame.Angles(0,0,math.rad(side*i*20))) end end
 elseif shape=="turtle" then
  part(model,"Shell",Vector3.new(0,.35,.45),Vector3.new(2.1,1.7,1.9),accent)
  for _,x in {-.5,.5} do part(model,"ShellSpot",Vector3.new(x,1.06,.45),Vector3.new(.58,.18,.8),color) end
 elseif shape=="narwhal" then
  part(model,"Horn",Vector3.new(0,.45,-1.25),Vector3.new(.32,.32,1.4),accent)
  wing(-1.2,Vector3.new(1,.25,.8),-15); wing(1.2,Vector3.new(1,.25,.8),15)
 elseif shape=="bee" then
  part(model,"Stripe",Vector3.new(0,.04,.4),Vector3.new(1.95,1.66,.55),accent)
  wing(-1.1,Vector3.new(1.3,.26,1.6),-30); wing(1.1,Vector3.new(1.3,.26,1.6),30)
  for _,x in {-.4,.4} do part(model,"Antenna",Vector3.new(x,1.05,-.25),Vector3.new(.2,.7,.2),accent) end
 else
  local large=shape=="manta" or shape=="moth"
  wing(-1.2,Vector3.new(if large then 2.1 else 1.6,.3,1.9),-25); wing(1.2,Vector3.new(if large then 2.1 else 1.6,.3,1.9),25)
  if shape=="dragon" then for _,x in {-.45,.45} do part(model,"Horn",Vector3.new(x,1,0),Vector3.new(.3,.7,.3),accent) end end
 end
 part(model,"Tail",Vector3.new(0,-.2,1.08),Vector3.new(.7,.65,1.1),accent)
 if level>=5 then local gem=part(model,"TrainingStar",Vector3.new(0,.45,-.91),Vector3.new(.25,.25,.12),Color3.fromRGB(255,225,122),Enum.PartType.Block,CFrame.Angles(0,0,math.pi/4)); gem.Material=Enum.Material.Neon end
 if level==10 then for i=-1,1 do part(model,"Crown",Vector3.new(i*.35,1.4,-.15),Vector3.new(.25,.55-math.abs(i)*.15,.3),Color3.fromRGB(255,224,120),Enum.PartType.Block) end end
 return {Model=model,Wings=wings}
end
return PetFactory
