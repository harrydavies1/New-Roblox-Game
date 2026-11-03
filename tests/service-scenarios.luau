local Config=require("../src/shared/Config")
local Engine=require("../src/shared/Economy").new(Config)
local Store=require("../src/server/SessionStore")
local checks=0
local function check(value,message) assert(value,message); checks+=1 end
local function object(class,name,parent) local o=Instance.new(class); o.Name=name; o.Parent=parent; return o end
local users={}; local players=object("Players","Players",nil)
function players:GetPlayerByUserId(id) return users[id] end
services.Players=players
services.CollectionService={Tags={},AddTag=function(self,o,tag) self.Tags[o]=tag end}
services.RunService={PreSimulation=signal()}
local marketplace={Failure=false,Ownership={},Prompts={},PromptGamePassPurchaseFinished=signal()}
function marketplace:GetProductInfo(id,infoType) if self.Failure then error("simulated unavailable API") end; check(id>0 and infoType~=nil); return {PriceInRobux=49,IsForSale=true} end
function marketplace:UserOwnsGamePassAsync(user,id) return self.Ownership[user.."/"..id]==true end
function marketplace:PromptProductPurchase(player,id) table.insert(self.Prompts,{Player=player,Id=id}) end
function marketplace:PromptGamePassPurchase(player,id) table.insert(self.Prompts,{Player=player,Id=id}) end
services.MarketplaceService=marketplace
local warn=function() end
local poseClock={Now=0}
-- MODULES --
local map=object("Model","MogWorld",workspace)
for _,w in Config.Worlds do
 local island=object("Folder",w.Id,map); local markers=object("Folder","Markers",island)
 local spawn=object("Part","Spawn",markers); spawn.Position=Vector3.new(w.Origin[1],5.5,w.Origin[2]+29)
 for _,key in {"PetShop","Quests","Rebirth"} do if key=="Rebirth" and w.Id~="meadow" then continue end; local m=object("Part",key,markers); m.Position=Vector3.zero end
 local shards=object("Folder","Shards",island)
 for i=1,13 do local crystal=object("Part",if i==13 then "Bonus_01" else string.format("Shard_%02d",i),shards); crystal.Position=Vector3.new(w.Origin[1]+54,8,w.Origin[2]) end
 local portals=object("Folder","Portals",island)
 for _,target in Config.Worlds do if (w.Id=="meadow" and target.Id~="meadow") or (w.Id~="meadow" and target.Id=="meadow") then local p=object("Part",target.Id,portals); p.Position=Vector3.zero end end
end
local function newPlayer(id)
 local p=object("Player","Player"..id,players); p.UserId=id; users[id]=p
 p.Character=object("Model","Character",workspace); local root=object("Part","HumanoidRootPart",p.Character); root.Position=Vector3.new(54,8,0)
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
check(tags==52 and prompts==67)
map.meadow.Shards.Shard_01.CollectPrompt.Triggered:Fire(p); check(collected==1)
local root=p.Character.HumanoidRootPart; root.Position=Vector3.new(500,8,500); map.meadow.Shards.Shard_01.CollectPrompt.Triggered:Fire(p); check(collected==1)
root.Position=Vector3.zero; map.meadow.Portals.candy:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p); map.meadow.Markers.PetShop:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p); check(traveled==1 and opened==1)
check(world:Teleport(p,"cosmos")); check(root.Position.X==620 and root.Position.Z==649 and root.Position.Y==9.5); check(not world:Teleport(p,"forged"))
p.Character.Humanoid.Health=0; check(not world:Teleport(p,"meadow")); p.Character.Humanoid.Health=100
local records={}; local adapter={Fail=false}
function adapter:UpdateAsync(key,f) if self.Fail then error("simulated outage") end; local r=f(Engine.Clone(records[key])); if r then records[key]=Engine.Clone(r) end; return Engine.Clone(r) end
local store=Store.new(adapter,{Clock=function() return 1000 end,SessionId="test",LeaseSeconds=180,Normalize=function(raw) return Engine:Normalize(raw) end}); check(store:Load(1)~=nil)
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
