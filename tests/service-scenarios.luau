local Config=require("../src/shared/Config")
local Engine=require("../src/shared/Economy").new(Config)
local Store=require("../src/server/SessionStore")
local checks=0
local function check(value,message) assert(value,message); checks+=1 end
local function object(class,name,parent) local o=Instance.new(class); o.Name=name; o.Parent=parent; return o end
local users={}; local players=object("Players","Players",nil)
function players:GetPlayerByUserId(id) return users[id] end
function players:GetPlayerFromCharacter(character)
 for _,player in users do if player.Character==character then return player end end
 return nil
end
services.Players=players
services.CollectionService={Tags={},AddTag=function(self,o,tag) self.Tags[o]=tag end}
services.RunService={PreSimulation=signal(),Heartbeat=signal()}
local marketplace={Failure=false,Ownership={},Prompts={},PromptGamePassPurchaseFinished=signal()}
function marketplace:GetProductInfo(id,infoType) if self.Failure then error("simulated unavailable API") end; check(id>0 and infoType~=nil); return {PriceInRobux=49,IsForSale=true} end
function marketplace:UserOwnsGamePassAsync(user,id) return self.Ownership[user.."/"..id]==true end
function marketplace:PromptProductPurchase(player,id) table.insert(self.Prompts,{Player=player,Id=id}) end
function marketplace:PromptGamePassPurchase(player,id) table.insert(self.Prompts,{Player=player,Id=id}) end
services.MarketplaceService=marketplace
local warn=function() end
local poseClock={Now=0}
local obbyClock={Now=0}
local audioClock={Now=0}
local audioQueue={}
local audioTask={spawn=function(f) f() end,delay=function(delay,f) table.insert(audioQueue,{At=audioClock.Now+delay,Run=f}) end}
services.SoundService=object("SoundService","SoundService",nil)
services.ContentProvider={PreloadAsync=function() end}
services.Debris={AddItem=function() end}
local storageMode={Studio=true,ReadAllowed=false,InitAllowed=true}
local storageRecords={}
local storageAdapter={}
function storageAdapter:GetAsync(key) if not storageMode.ReadAllowed then error("Studio API access disabled") end; return storageRecords[key] end
function storageAdapter:UpdateAsync(key,f) local value=f(Engine.Clone(storageRecords[key])); if value then storageRecords[key]=Engine.Clone(value) end; return Engine.Clone(value) end
services.DataStoreService={GetDataStore=function(_,name) if not storageMode.InitAllowed then error("service unavailable") end; return storageAdapter end}
local guid=0
services.HttpService={GenerateGUID=function() guid+=1; return "contract-"..guid end}
function services.RunService:IsStudio() return storageMode.Studio end
local ObbyRun=require("../src/server/ObbyRun")
-- MODULES --
local map=object("Model","MogWorld",workspace)
for wi,w in Config.Worlds do
 local island=object("Folder",w.Id,map); local markers=object("Folder","Markers",island)
 local spawn=object("Part","Spawn",markers); spawn.Position=Vector3.new(w.Origin[1],5.5,w.Origin[2]+29)
 for _,key in {"PetShop","Quests","Rebirth","Shop"} do if key=="Rebirth" and w.Id~="meadow" then continue end; local m=object("Part",key,markers); m.Position=Vector3.zero end
 local shards=object("Folder","Shards",island)
 for i=1,12 do local crystal=object("Part",string.format("Shard_%02d",i),shards); crystal.Position=Vector3.new(w.Origin[1]+54,8,w.Origin[2]) end
 local portals=object("Folder","Portals",island)
 local nextWorld=Config.Worlds[wi+1]
 if nextWorld then local gate=object("Part",nextWorld.Id,portals); gate.Position=Vector3.zero end
 if wi>1 then local gate=object("Part","meadow",portals); gate.Position=Vector3.zero end
 local courses=object("Folder","Obbies",island)
 for _,route in Config.Obbies do
  if route.World~=w.Id then continue end
  local course=object("Folder",route.Id,courses)
  local start=object("Part","Start",course); start.Position=Vector3.new(w.Origin[1]+112,6.4,0)
  local steps=object("Folder","Steps",course); local hazards=object("Folder","Hazards",course)
  for i=1,route.Count do
   local step=object("Part",string.format("%02d",i),steps); step.Position=Vector3.new(w.Origin[1]+112+i*route.Spacing,6.4+i,0); step.Size=Vector3.new(route.Width,1.1,route.Width)
  end
  local hazard=object("Part","Hazard",hazards); hazard.Position=steps["02"].Position+Vector3.new(2,.7,0)
  local marker=object("Part","Course_"..route.Id,markers); marker.Position=Vector3.new(w.Origin[1]+88,7,0)
 end
end
local function newPlayer(id)
 local p=object("Player","Player"..id,players); p.UserId=id; users[id]=p
 p.Character=object("Model","Character",workspace); local root=object("Part","HumanoidRootPart",p.Character); root.Position=Vector3.new(54,8,0); root.Anchored=false
 local h=object("Humanoid","Humanoid",p.Character); h.Health=100; return p
end
local p=newPlayer(1)
local function motor(char,name) local m=object("Motor6D",name,char); m.C0=CFrame.new(0,0,0); return m end
local shoulder=motor(p.Character,"RightShoulder"); local base=shoulder.C0
for _,n in {"LeftShoulder","RightElbow","LeftElbow","Neck","Waist"} do motor(p.Character,n) end
local animations=true; local pose=MogPose.new(function() return animations end)
pose:Play(p); check(#pose.Active[p].Joints==6); poseClock.Now=.4; services.RunService.PreSimulation:Fire(); check(shoulder.C0~=base)
poseClock.Now=1; services.RunService.PreSimulation:Fire(); check(shoulder.C0==base and pose.Active[p]==nil)
local r6=newPlayer(2); for _,n in {"Right Shoulder","Left Shoulder","Neck"} do motor(r6.Character,n) end
pose:Play(r6); check(#pose.Active[r6].Joints==3); animations=false; services.RunService.PreSimulation:Fire(); check(pose.Active[r6]==nil); pose:Play(p); check(pose.Active[p]==nil)
local collected,traveled,opened=0,0,0
local world=WorldService.new(Config,{
 Collect=function(who,id,crystal) check(who==p and id=="meadow" and crystal.Name=="Shard_01"); collected+=1 end,
 Portal=function(who,id) check(who==p and id=="candy"); traveled+=1 end,
 OpenPanel=function(who,panel) check(who==p and panel=="Pets"); opened+=1 end,
})
local tags,prompts=0,0
for o,tag in services.CollectionService.Tags do check(tag=="MogCrystal" and o:GetAttribute("CrystalId")~=nil); tags+=1 end
for _,o in map:GetDescendants() do if o.ClassName=="ProximityPrompt" then prompts+=1 end end
check(tags==60 and prompts==84)
map.meadow.Shards.Shard_01.CollectPrompt.Triggered:Fire(p); check(collected==1)
local root=p.Character.HumanoidRootPart; root.Position=Vector3.new(500,8,500); map.meadow.Shards.Shard_01.CollectPrompt.Triggered:Fire(p); check(collected==1)
root.Position=Vector3.zero; map.meadow.Portals.candy:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p); map.meadow.Markers.PetShop:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p); check(traveled==1 and opened==1)
check(world:Teleport(p,"cosmos")); check(root.Position.X==18000 and root.Position.Z==29 and root.Position.Y==9.5); check(not root.Anchored and p._streamRequests[1].Anchored); check(not world:Teleport(p,"forged"))
p.Character.Humanoid.Health=0; check(not world:Teleport(p,"meadow")); p.Character.Humanoid.Health=100
local records={}; local adapter={Fail=false}
function adapter:UpdateAsync(key,f) if self.Fail then error("simulated outage") end; local r=f(Engine.Clone(records[key])); if r then records[key]=Engine.Clone(r) end; return Engine.Clone(r) end
local store=Store.new(adapter,{Clock=function() return 1000 end,SessionId="test",LeaseSeconds=180,Normalize=function(raw) return Engine:Normalize(raw) end,Prepare=function(profile,now) Engine:Initialize(profile,now) end}); check(store:Load(1)~=nil)
local settings={ProductIds={},PassIds={}}
for i,v in Config.Products do settings.ProductIds[v.Key]=5000+i end
for i,v in Config.Passes do settings.PassIds[v.Key]=9000+i end
local deliveries,changed=0,0
local callbacks={Purchased=function(who,key) check(who==p and Engine.Products[key]~=nil); deliveries+=1 end,Changed=function() changed+=1 end,CatalogReady=function() end}
local commerce=Commerce.new(Config,settings,store,Engine,false,callbacks)
check(commerce.Catalog.flex_gems_small.Enabled and commerce.Catalog.flex_gems_small.Price==49)
check(not commerce:Prompt(p,"forged")); check(commerce:Prompt(p,"flex_gems_small")); check(marketplace.Prompts[1].Id==settings.ProductIds.flex_gems_small); check(not commerce:Prompt(p,"flex_gems_small"))
local receipt={PlayerId=1,ProductId=settings.ProductIds.flex_gems_small,PurchaseId="r1"}
check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted); check(store:Get(1).FlexGems==100 and deliveries==1)
check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted); check(store:Get(1).FlexGems==100 and deliveries==1)
adapter.Fail=true; receipt.PurchaseId="r2"; check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.NotProcessedYet); check(store:Get(1).FlexGems==100 and store:Get(1).Receipts.r2==nil)
adapter.Fail=false; check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted); check(store:Get(1).FlexGems==200)
check(marketplace.ProcessReceipt({PlayerId=999,ProductId=receipt.ProductId,PurchaseId="offline"})==Enum.ProductPurchaseDecision.NotProcessedYet)
check(marketplace.ProcessReceipt({PlayerId=1,ProductId=99999,PurchaseId="unknown"})==Enum.ProductPurchaseDecision.NotProcessedYet)
store:Get(1).FlexGems=Config.MaxCurrency-1; commerce.LastPrompt[1]=nil; check(not commerce:Prompt(p,"flex_gems_small")); receipt.PurchaseId="cap"; check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.NotProcessedYet); check(store:Get(1).Receipts.cap==nil)
store:Get(1).FlexGems=200; check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted); check(store:Get(1).FlexGems==300)
commerce:RefreshPasses(p); check(not commerce:GetPasses(p).VIP)
marketplace.PromptGamePassPurchaseFinished:Fire(p,settings.PassIds.VIP,true); check(not commerce:GetPasses(p).VIP)
marketplace.Ownership["1/"..settings.PassIds.VIP]=true; marketplace.PromptGamePassPurchaseFinished:Fire(p,settings.PassIds.VIP,true); check(commerce:GetPasses(p).VIP==true and changed>0)
check(not commerce:Prompt(p,"VIP")); check(store:Get(1).FlexGems==300)
local sandbox=Commerce.new(Config,settings,store,Engine,true,callbacks); check(not sandbox.Catalog.flex_gems_small.Enabled and not sandbox:Prompt(p,"flex_gems_small")); check(marketplace.ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.NotProcessedYet)
local duplicate=Engine.Clone(settings); duplicate.ProductIds.flex_gems_small=duplicate.ProductIds.aura_small; check(not pcall(function() Commerce.new(Config,duplicate,store,Engine,false,callbacks) end))
marketplace.Failure=true; local unavailable=Commerce.new(Config,settings,store,Engine,false,callbacks); check(not unavailable.Catalog.flex_gems_small.Enabled)
print(string.format("PASS: %d service-boundary assertions for world, commerce, and R6/R15 pose lifecycle",checks))
