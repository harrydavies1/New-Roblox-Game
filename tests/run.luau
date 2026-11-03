--!strict
local Config: any=require("../src/shared/Config")
local Engine=require("../src/shared/Economy").new(Config)
local Store=require("../src/server/SessionStore")
local Limiter=require("../src/server/RateLimiter")
local ObbyRun=require("../src/server/ObbyRun")
local Objectives=require("../src/shared/Objectives")
local Format=require("../src/shared/Format")
local passed,failed=0,0
local function test(name: string,callback: ()->())
 local ok,message=pcall(callback)
 if ok then passed+=1; print("PASS "..name) else failed+=1; print("FAIL "..name..": "..tostring(message)) end
end
local function eq(actual: any,expected: any) assert(actual==expected,"expected "..tostring(expected)..", got "..tostring(actual)) end
local function ctx(): any return {Now=100*86400+10,Passes={}} end
local function profile(): any local p=Engine:NewProfile(); Engine:Initialize(p,ctx().Now); return p end
local function rich(): any local p=profile(); p.Aura=Config.MaxCurrency; p.Level=50; return p end
local function act(p: any,name: any,id: any,context: any?): boolean local ok=Engine:Apply(p,name,{Id=id},context or ctx()); return ok end
test("new profiles have no paid currency",function() local p=profile(); eq(p.Aura,0); eq(p.FlexGems,0); eq(p.Worlds.meadow,true); eq(p.CurrentWorld,"meadow") end)
test("accepted clicks grant Aura, XP, and quest progress",function()
 local p=profile(); local result=Engine:Click(p,ctx()); eq(result.Amount,1); eq(p.Aura,1); eq(p.XP,1); eq(p.TotalClicks,1); eq(p.Daily.Clicks,1)
end)
test("level-up gives the exact level reward",function() local p=profile(); for _=1,60 do Engine:Click(p,ctx()) end; eq(p.Level,2); eq(p.XP,0); eq(p.Aura,140) end)
test("mog bursts are exactly every 25 accepted clicks",function()
 local p=profile(); local bursts=0
 for i=1,101 do local r=Engine:Click(p,ctx()); eq(r.Burst,i%25==0); if r.Burst then bursts+=1 end end; eq(bursts,4)
end)
test("saturated click counters cannot spam bursts",function() local p=profile(); p.TotalClicks=Config.MaxCurrency; eq(Engine:Click(p,ctx()).Burst,false) end)
test("rank thresholds are deterministic",function() eq(Engine:Rank(1),"Fresh Spawn"); eq(Engine:Rank(4),"Fresh Spawn"); eq(Engine:Rank(5),"Fit Check"); eq(Engine:Rank(200),"Mog Singularity") end)
test("upgrades spend server-calculated Aura",function() local p=rich(); local before=p.Aura; assert(act(p,"BuyUpgrade",nil)); eq(p.Upgrade,1); eq(p.Aura,before-75); eq(Engine:ClickValue(p,ctx()),2) end)
test("unaffordable and capped upgrades do not spend",function() local p=profile(); assert(not act(p,"BuyUpgrade",nil)); p=rich(); p.Upgrade=Config.MaxUpgrade; local n=p.Aura; assert(not act(p,"BuyUpgrade",nil)); eq(p.Aura,n) end)
test("locked-world pets cannot be purchased",function() local p=rich(); assert(not act(p,"BuyPet","dragon")); eq(p.Pets.dragon,nil) end)
test("forged pet IDs are rejected",function() local p=rich(); assert(not act(p,"BuyPet",{})); assert(not act(p,"BuyPet","forged")); eq(next(p.Pets),nil) end)
for _,pet in Config.Pets do
 test("guaranteed adoption and training: "..pet.Id,function()
  local p=rich(); for _,w in Config.Worlds do p.Worlds[w.Id]=true end
  if pet.ObbyOnly then
   assert(not act(p,"BuyPet",pet.Id)); p.CurrentWorld=pet.World
   local reward=Engine:CompleteRoute(p,pet.ObbyOnly,ctx()); eq(reward.Pet,pet.Id)
   eq(p.Pets[pet.Id],1); return
  end
  local old=p.Aura; assert(act(p,"BuyPet",pet.Id)); eq(p.Pets[pet.Id],1); eq(p.Aura,old-pet.Cost); eq(p.Equipped[1],pet.Id)
  old=p.Aura; assert(act(p,"BuyPet",pet.Id)); eq(p.Pets[pet.Id],2); eq(p.Aura,old-math.floor(pet.Cost*1.8)); eq(#p.Equipped,1)
 end)
end
test("resting and equipping cannot duplicate pets",function() local p=rich(); assert(act(p,"BuyPet","bunny")); assert(act(p,"EquipPet","bunny")); eq(#p.Equipped,0); assert(act(p,"EquipPet","bunny")); eq(#p.Equipped,1) end)
test("pet training stops at level ten",function() local p=rich(); p.Pets.bunny=10; local n=p.Aura; assert(not act(p,"BuyPet","bunny")); eq(p.Aura,n) end)
test("three normal pet slots are enforced",function()
 local p=rich(); p.Worlds.candy=true; for _,id in {"bunny","pup","fox","bee"} do assert(act(p,"BuyPet",id)) end; eq(#p.Equipped,3); assert(not act(p,"EquipPet","bee"))
end)
test("extra slots require a verified pass",function()
 local p=rich(); p.Worlds.candy=true; local c=ctx(); c.Passes.ExtraPets=true
 for _,id in {"bunny","pup","fox","bee","axolotl","dragon"} do assert(act(p,"BuyPet",id,c)) end
 eq(#p.Equipped,5); assert(not act(p,"EquipPet","dragon",c))
 local normal=Engine:PetMultiplier(p,ctx()); local paid=Engine:PetMultiplier(p,c); assert(paid>normal)
end)
test("worlds require levels, currency, and previous discovery",function()
 local p=rich(); assert(not act(p,"UnlockWorld","cosmos")); p.Level=7; assert(not act(p,"UnlockWorld","candy")); p.Level=8; p.Aura=24999; assert(not act(p,"UnlockWorld","candy"))
 p.Aura=25000; assert(act(p,"UnlockWorld","candy")); eq(p.Aura,0); assert(not act(p,"UnlockWorld","candy"))
end)
test("all worlds can be permanently unlocked in sequence",function() local p=rich(); for _,id in {"candy","coral","cosmos","citadel"} do assert(act(p,"UnlockWorld",id)); eq(p.Worlds[id],true) end end)
test("multipliers compose on the server",function()
 local p=profile(); p.Upgrade=9; p.Pets.bunny=1; p.Equipped={"bunny"}; p.Rebirths=4; p.CurrentWorld="candy"
 local c=ctx(); c.Passes.DoubleAura=true; eq(Engine:ClickValue(p,c),92)
end)
test("crystal rewards match their advertised multipliers",function() local p=profile(); eq(Engine:Collect(p,"meadow",false,ctx()).Amount,8); eq(Engine:Collect(p,"meadow",true,ctx()).Amount,12); eq(p.Daily.Collects,2); eq(p.XP,4) end)
test("locked or wrong-island crystals are refused",function() local p=rich(); assert(not pcall(function() Engine:Collect(p,"candy",false,ctx()) end)); p.Worlds.candy=true; assert(not pcall(function() Engine:Collect(p,"candy",false,ctx()) end)) end)
test("rebirth resets only documented fields",function()
 local p=rich(); p.FlexGems=100; p.Upgrade=9; p.Worlds.candy=true; p.Pets.bunny=3; p.Equipped={"bunny"}; p.Cosmetics.mint=true
 assert(act(p,"Rebirth",nil)); eq(p.Aura,0); eq(p.Upgrade,0); eq(p.Rebirths,1); eq(p.FlexGems,100); eq(p.Level,50); eq(p.Worlds.candy,true); eq(p.Pets.bunny,3); eq(p.Cosmetics.mint,true)
end)
test("unaffordable and capped rebirths preserve progress",function() local p=profile(); p.Upgrade=3; assert(not act(p,"Rebirth",nil)); eq(p.Upgrade,3); p=rich(); p.Rebirths=Config.MaxRebirths; assert(not act(p,"Rebirth",nil)) end)
for _,quest in Config.Quests do
 test("daily goal pays once: "..quest.Id,function()
  local p=profile(); assert(not act(p,"ClaimQuest",quest.Id)); p.Daily[quest.Counter]=quest.Target; assert(act(p,"ClaimQuest",quest.Id)); local n=p.Aura
  assert(not act(p,"ClaimQuest",quest.Id)); eq(p.Aura,n); eq(p.FlexGems,0)
 end)
end
test("UTC midnight resets daily progress, preserving currencies",function() local p=profile(); p.Daily.Clicks=250; p.Daily.Claimed.clicks=true; p.Aura=123; p.FlexGems=100; Engine:RefreshDay(p,101*86400); eq(p.Daily.Clicks,0); eq(next(p.Daily.Claimed),nil); eq(p.Aura,123); eq(p.FlexGems,100) end)
test("gameplay never mints paid Flex Gems",function()
 local p=rich(); for _=1,1000 do Engine:Click(p,ctx()) end; for _=1,12 do Engine:Collect(p,"meadow",false,ctx()) end
 for _,q in Config.Quests do act(p,"ClaimQuest",q.Id) end; for _,q in Config.Milestones do act(p,"ClaimMilestone",q.Id) end; act(p,"Rebirth",nil); eq(p.FlexGems,0)
end)
for _,product in Config.Products do
 test("exact paid reward: "..product.Key,function() local p=profile(); if product.Kind=="Boost" then
   assert(Engine:GrantProduct(p,product.Key,ctx().Now)); eq(p.Boosts[product.Boost.."Until"],ctx().Now+900)
  else assert(Engine:GrantProduct(p,product.Key)); eq(p[product.Currency],product.Amount) end; eq(p.TotalAura,0); eq(p.Daily.Earned,0); eq(p.XP,0) end)
end
test("unknown and over-cap paid rewards are deferred",function() local p=profile(); assert(not Engine:GrantProduct(p,"forged")); p.FlexGems=Config.MaxCurrency-50; assert(not Engine:GrantProduct(p,"flex_gems_small")); eq(p.FlexGems,Config.MaxCurrency-50) end)
test("cosmetics spend the exact paid balance once",function() local p=profile(); p.FlexGems=100; assert(act(p,"BuyCosmetic","mint")); eq(p.FlexGems,40); eq(p.Cosmetics.mint,true); eq(p.ActiveCosmetics.Trail,"mint"); assert(not act(p,"BuyCosmetic","mint")); eq(p.FlexGems,40) end)
test("unowned cosmetics cannot be equipped",function() local p=profile(); assert(not act(p,"EquipCosmetic","mint")); p.Cosmetics.mint=true; assert(act(p,"EquipCosmetic","mint")); assert(act(p,"EquipCosmetic","mint")); eq(p.ActiveCosmetics.Trail,nil) end)
test("free and pass titles cannot be acquired by zero-price calls",function() local p=rich(); p.FlexGems=1000; assert(not act(p,"BuyCosmetic","starter")); assert(not act(p,"BuyCosmetic","starwalker")); assert(not act(p,"BuyCosmetic","vip")); assert(not act(p,"EquipCosmetic","vip")); local c=ctx(); c.Passes.VIP=true; assert(act(p,"EquipCosmetic","vip",c)) end)
test("journal titles and claims survive rebirth and reload",function()
 local p=rich(); assert(not act(p,"ClaimMilestone","first_light")); p.TotalClicks=200; assert(act(p,"ClaimMilestone","first_light")); assert(not act(p,"ClaimMilestone","first_light")); assert(act(p,"Rebirth",nil))
 Engine:RefreshDay(p,ctx().Now+86400); p=Engine:Normalize(p); eq(p.Milestones.first_light,true); eq(p.Cosmetics.starter,true); eq(p.ActiveCosmetics.Title,"starter"); eq(p.FlexGems,0)
end)
test("journal metrics count pets and training levels",function() local p=rich(); p.Pets={bunny=3,pup=4,fox=3}; eq(Engine:MilestoneProgress(p,"pet_party"),3); eq(Engine:MilestoneProgress(p,"pet_student"),10); assert(act(p,"ClaimMilestone","pet_party")); assert(act(p,"ClaimMilestone","pet_student")) end)
test("settings and requests validate primitive types",function() local p=profile(); assert(Engine:Apply(p,"Setting",{Id="SFX",Value=false},ctx())); eq(p.Settings.SFX,false); assert(not Engine:Apply(p,"Setting",{Id="SFX",Value=1},ctx())); assert(not Engine:Apply(p,"GiveCurrency",{},ctx())); assert(not Engine:Apply(p,1,{},ctx())); assert(not Engine:Apply(p,"BuyPet","bunny",ctx())) end)
test("paid balances, retired cosmetics and receipt IDs round-trip",function() local p=rich(); p.FlexGems=123; p.Cosmetics.retired=true; p.Receipts.r1=true; local q=Engine:Normalize(p); eq(q.FlexGems,123); eq(q.Cosmetics.retired,true); eq(q.Receipts.r1,true) end)
test("corrupt paid data fails closed",function()
 for _,value in {-1,0/0,math.huge,1.5,"100"} do local p=profile(); p.FlexGems=value; assert(not pcall(function() Engine:Normalize(p) end)) end
 local p=profile(); p.Receipts="broken"; assert(not pcall(function() Engine:Normalize(p) end)); p=profile(); p.Version=99; assert(not pcall(function() Engine:Normalize(p) end))
end)
test("free progress normalizes and pet lists deduplicate",function() local p=profile(); p.Aura=0/0; p.Level=-4; p.Pets={bunny=500,bogus=9}; p.Equipped={"bunny","bunny","bogus"}; local q=Engine:Normalize(p); eq(q.Aura,0); eq(q.Level,1); eq(q.Pets.bunny,10); eq(#q.Equipped,1) end)
test("XP and currency caps stay finite",function() local p=profile(); p.Level=Config.MaxLevel; p.XP=Engine:XPRequired(p.Level)-1; p.Aura=Config.MaxCurrency; Engine:Click(p,ctx()); eq(p.Level,Config.MaxLevel); eq(p.XP,Engine:XPRequired(p.Level)-1); eq(p.Aura,Config.MaxCurrency) end)

local function persistence(): (any,any,any)
 local clock={Now=1000}; local adapter: any={Records={},Fail=false,Hook=nil,Retry=false}
 function adapter.UpdateAsync(self: any,key: string,transform: (any)->any): any
  if self.Hook then local hook=self.Hook :: (() -> ()); self.Hook=nil; hook() end
  if self.Fail then error("simulated outage") end
  if self.Retry then transform(Engine.Clone(self.Records[key])) end
  local record=transform(Engine.Clone(self.Records[key])); if record then self.Records[key]=Engine.Clone(record) end; return Engine.Clone(record)
 end
 local function make(id: string): any return Store.new(adapter,{Clock=function() return clock.Now end,SessionId=id,LeaseSeconds=180,Normalize=function(raw: any) return Engine:Normalize(raw) end,Prepare=function(p: any,now: number) Engine:Initialize(p,now) end}) end
 return adapter,clock,make
end
test("loading claims an atomic lease",function() local a,c,make=persistence(); local s=make("one"); assert(s:Load(1)); eq(a.Records.player_1.Session.Id,"one"); eq(a.Records.player_1.Session.ExpiresAt,c.Now+180) end)
test("a second server cannot claim a live lease",function() local _,_,make=persistence(); assert(make("one"):Load(1)); local p,r=make("two"):Load(1); eq(p,nil); eq(r,"session_locked") end)
test("autosave extends the lease and persists gameplay",function() local a,c,make=persistence(); local s=make("one"); s:Load(1).Aura=91; c.Now+=40; assert(s:Save(1)); eq(a.Records.player_1.Data.Aura,91); eq(a.Records.player_1.Session.ExpiresAt,1220) end)
test("release saves and allows a clean rejoin",function() local _,_,make=persistence(); local s=make("one"); s:Load(1).Aura=52; assert(s:Save(1,true)); eq(s:Get(1),nil); eq(make("two"):Load(1).Aura,52) end)
test("a stale session cannot overwrite a new owner",function() local a,c,make=persistence(); local s=make("one"); s:Load(1); c.Now+=181; assert(make("two"):Load(1)); local ok,r=s:Save(1); eq(ok,false); eq(r,"session_lost"); eq(a.Records.player_1.Session.Id,"two") end)
test("expired leases block gameplay access",function() local _,c,make=persistence(); local s=make("one"); s:Load(1); c.Now+=180; local p,r=s:Get(1); eq(p,nil); eq(r,"session_expired") end)
test("receipt balance and ID persist atomically",function() local a,_,make=persistence(); local s=make("one"); s:Load(1); assert(s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"flex_gems_small") end)); eq(s:Get(1).FlexGems,100); eq(a.Records.player_1.Data.FlexGems,100); eq(a.Records.player_1.Data.Receipts.r1,true) end)
test("duplicate receipts never rerun grants",function()
 local _,_,make=persistence(); local s=make("one"); s:Load(1); assert(s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"flex_gems_small") end))
 local ok,r=s:CompletePurchase(1,"r1",function(_p: any) error("duplicate grant executed") end); eq(ok,true); eq(r,"duplicate"); eq(s:Get(1).FlexGems,100)
end)
test("deduplication survives leaving and rejoining",function()
 local _,_,make=persistence(); local s=make("one"); s:Load(1); assert(s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"aura_small") end)); assert(s:Save(1,true))
 s=make("two"); s:Load(1); local _,r=s:CompletePurchase(1,"r1",function(_p: any) error("must not run") end); eq(r,"duplicate"); eq(s:Get(1).Aura,5000)
end)
test("failed purchase saves never expose undurable currency",function()
 local a,_,make=persistence(); local s=make("one"); s:Load(1); a.Fail=true; assert(not s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"flex_gems_small") end)); eq(s:Get(1).FlexGems,0); eq(s:Get(1).Receipts.r1,nil)
 a.Fail=false; assert(s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"flex_gems_small") end)); eq(s:Get(1).FlexGems,100)
end)
test("profile access is serialized while a receipt writes",function() local a,_,make=persistence(); local s=make("one"); s:Load(1); a.Hook=function() local p,r=s:Get(1); eq(p,nil); eq(r,"busy"); assert(not s:Save(1)) end; assert(s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"flex_gems_small") end)) end)
test("repeated UpdateAsync callbacks do not duplicate rewards",function() local a,_,make=persistence(); a.Retry=true; local s=make("one"); s:Load(1); assert(s:CompletePurchase(1,"r1",function(p: any) return Engine:GrantProduct(p,"flex_gems_small") end)); eq(s:Get(1).FlexGems,100) end)
test("invalid receipts, failed grants and offline players remain pending",function() local _,_,make=persistence(); local s=make("one"); assert(not s:CompletePurchase(1,"r1",function(_p: any) return true end)); s:Load(1); assert(not s:CompletePurchase(1,"",function(_p: any) return true end)); assert(not s:CompletePurchase(1,"r1",function(p: any) p.FlexGems=10; return false end)); eq(s:Get(1).FlexGems,0); eq(s:Get(1).Receipts.r1,nil) end)
test("corrupt saves and load failures cannot create replacement paid profiles",function() local a,_,make=persistence(); a.Records.player_1={Format=99,Data={}}; eq(make("one"):Load(1),nil); eq(a.Records.player_1.Format,99); a.Fail=true; local s=make("two"); eq(s:Load(2),nil); eq(s:Get(2),nil) end)
test("save failures retain progress for retry",function() local a,_,make=persistence(); local s=make("one"); s:Load(1).Aura=42; a.Fail=true; assert(not s:Save(1)); eq(s:Get(1).Aura,42); a.Fail=false; assert(s:Save(1)); eq(a.Records.player_1.Data.Aura,42) end)
test("click bucket replenishes at the documented server rate",function() local l=Limiter.new(12,12); for _=1,12 do assert(l:Allow(1,0)) end; assert(not l:Allow(1,0)); assert(l:Allow(1,1/12)); assert(not l:Allow(1,1/12)) end)
test("request limits are per player and reject backwards clock refills",function() local l=Limiter.new(1,1); assert(l:Allow(1,100)); assert(not l:Allow(1,99)); assert(not l:Allow(1,100)); assert(l:Allow(2,100)); l:Forget(1); assert(l:Allow(1,100)) end)
test("formatting preserves meaningful thresholds",function() eq(Format.number(999),"999"); eq(Format.number(1000),"1K"); eq(Format.number(1500),"1.5K"); eq(Format.percent(.15),"+15%") end)

test("version-one saves migrate without removing balances, receipts, pets, or titles",function()
 local p=rich(); p.Version=1; p.FlexGems=321; p.Receipts.original=true; p.Pets.bunny=10; p.Equipped={"bunny"}; p.Cosmetics.starwalker=true; p.Milestones.starwalker=true
 p.Login=nil; p.Obby=nil; p.Boosts=nil; p.CurrentWorld="cosmos"; p.Worlds.cosmos=true
 local q=Engine:Normalize(p); eq(q.Version,2); eq(q.Aura,p.Aura); eq(q.FlexGems,321); eq(q.Receipts.original,true); eq(q.Pets.bunny,10); eq(q.Equipped[1],"bunny"); eq(q.Cosmetics.starwalker,true); eq(q.CurrentWorld,"cosmos"); eq(q.Login.FirstSeenAt,0)
 Engine:Initialize(q,ctx().Now); eq(q.Login.FirstSeenAt,ctx().Now)
end)
test("first login day never grants a reward, even after UTC midnight",function()
 local p=profile(); local first=ctx().Now+86380; p.Login.FirstSeenAt=first
 assert(not Engine:LoginStatus(p,first).Ready); assert(not Engine:LoginStatus(p,first+100).Ready)
 local c=ctx(); c.Now=first+86399; assert(not act(p,"ClaimLogin",nil,c)); eq(p.Aura,0); eq(p.Login.Claims,0)
 c.Now=first+86400; assert(act(p,"ClaimLogin",nil,c)); eq(p.Login.Claims,1); eq(p.Aura,600); eq(p.FlexGems,0)
 assert(not act(p,"ClaimLogin",nil,c)); eq(p.Aura,600)
end)
test("login rewards wait a full interval after each claim without lost streaks",function()
 local p=profile(); local c=ctx(); c.Now+=86400; assert(act(p,"ClaimLogin",nil,c)); local first=p.Login.LastClaimAt
 c.Now=first+86399; assert(not act(p,"ClaimLogin",nil,c)); c.Now=first+86400; assert(act(p,"ClaimLogin",nil,c)); eq(p.Login.Claims,2)
 c.Now+=30*86400; assert(act(p,"ClaimLogin",nil,c)); eq(p.Login.Claims,3); eq(Engine:LoginStatus(p,c.Now).Index,4)
end)
test("first-seen timestamp is saved during lease acquisition",function()
 local a,c,make=persistence(); local s=make("one"); s:Load(1); eq(a.Records.player_1.Data.Login.FirstSeenAt,1000); assert(s:Save(1,true))
 c.Now+=86400; s=make("two"); local p=s:Load(1); eq(p.Login.FirstSeenAt,1000); assert(Engine:LoginStatus(p,c.Now).Ready)
end)
test("failed atomic login saves cannot spend or expose the reward",function()
 local a,c,make=persistence(); c.Now=100000; local s=make("one"); local p=s:Load(1); p.Login.FirstSeenAt=c.Now-86400; a.Fail=true
 local ok=s:CommitMutation(1,function(nextData: any) local context=ctx(); context.Now=c.Now; return Engine:Apply(nextData,"ClaimLogin",{},context) end)
 assert(not ok); eq(s:Get(1).Aura,0); eq(s:Get(1).Login.Claims,0)
 a.Fail=false; assert(s:CommitMutation(1,function(nextData: any) local context=ctx(); context.Now=c.Now; return Engine:Apply(nextData,"ClaimLogin",{},context) end))
 eq(s:Get(1).Aura,600); eq(a.Records.player_1.Data.Login.Claims,1)
end)
test("timed boosts stack their remaining paid duration and expire exactly",function()
 local p=profile(); local c=ctx(); assert(Engine:GrantProduct(p,"aura_boost",c.Now)); eq(Engine:ClickValue(p,c),2)
 assert(Engine:GrantProduct(p,"aura_boost",c.Now+100)); eq(p.Boosts.AuraUntil,c.Now+1800)
 c.Now=p.Boosts.AuraUntil; eq(Engine:ClickValue(p,c),1)
 assert(Engine:GrantProduct(p,"xp_boost",c.Now)); local before=p.XP; Engine:Click(p,c); eq(p.XP,before+2)
 local q=Engine:Normalize(p); eq(q.Boosts.XPUntil,p.Boosts.XPUntil)
end)
test("boost receipts cannot be replayed for additional time",function()
 local _,c,make=persistence(); local s=make("one"); s:Load(1)
 assert(s:CompletePurchase(1,"boost-1",function(p: any) return Engine:GrantProduct(p,"xp_boost",c.Now) end))
 assert(s:CompletePurchase(1,"boost-1",function(p: any) return Engine:GrantProduct(p,"xp_boost",c.Now) end)); eq(s:Get(1).Boosts.XPUntil,c.Now+900)
end)
test("new progression is slower than the previous XP curve",function()
 for _,level in {1,5,20,50} do assert(Engine:XPRequired(level)>math.floor(20*level^1.4)) end
 eq(Config.ClickRate,5); eq(Config.ClickBurst,1); eq(Config.ClickCooldown,.2); assert(Engine.Pets.bunny.Cost>=1500)
end)
test("rapid autoclick requests accept one event, with a real server cooldown",function()
 local limiter=Limiter.new(Config.ClickRate,Config.ClickBurst); local accepted=0
 for _=1,1000 do if limiter:Allow(1,0) then accepted+=1 end end; eq(accepted,1)
 assert(not limiter:Allow(1,.19)); assert(limiter:Allow(1,.200001)); assert(not limiter:Allow(1,.21)); assert(limiter:Allow(1,.400002))
end)
for _,route in Config.Obbies do
 test("ordered stages, checkpoints, rewards and earned pet: "..route.Id,function()
  local run=ObbyRun.new(route,0); assert(not ObbyRun.advance(run,2,1)); assert(not ObbyRun.advance(run,1,.01))
  local p=profile(); p.Worlds[route.World]=true; p.CurrentWorld=route.World
  for stage=1,route.Count do
   local ok,reason=ObbyRun.advance(run,stage,stage); assert(ok,reason)
   if reason=="checkpoint" then
    eq(run.Checkpoint,stage); local payout=Engine:CheckpointReward(p,route.Id,stage,ctx()); eq(payout.Amount,route.CheckpointAura)
    eq(Engine:CheckpointReward(p,route.Id,stage,ctx()).Amount,0)
   end
  end
  assert(run.Finished); assert(not ObbyRun.advance(run,route.Count,route.Count+1))
  local payout=Engine:CompleteRoute(p,route.Id,ctx()); eq(payout.First,true); eq(payout.Amount,route.FirstAura); eq(p.Obby.Clears,1)
  if route.Difficulty=="warmup" then eq(payout.Pet,nil) else eq(payout.Pet,route.PetReward); eq(p.Pets[route.PetReward],1) end
  local repeatReward=Engine:CompleteRoute(p,route.Id,ctx()); eq(repeatReward.Practice,true); eq(repeatReward.Amount,0); eq(p.Obby.Clears,1)
  local c=ctx(); c.Now+=Config.ObbyRewardCooldown; repeatReward=Engine:CompleteRoute(p,route.Id,c); eq(repeatReward.Pet,nil); eq(repeatReward.Amount,route.RepeatAura); eq(p.Obby.Clears,2); eq(p.FlexGems,0)
 end)
end
test("course resets preserve the last earned checkpoint and expiry rejects stale runs",function()
 local route=Engine.Obbies.meadow_sky; local run=ObbyRun.new(route,0)
 for stage=1,10 do assert(ObbyRun.advance(run,stage,stage)) end
 ObbyRun.reset(run,11); eq(run.Stage,8); assert(not ObbyRun.advance(run,10,12)); assert(ObbyRun.advance(run,9,12)); assert(not ObbyRun.advance(run,10,901))
end)
test("course stage payouts cannot be farmed or forged",function()
 local p=profile(); eq(Engine:CheckpointReward(p,"forged",8,ctx()).Amount,0); eq(Engine:CheckpointReward(p,"meadow_sky",1,ctx()).Amount,0); eq(Engine:CheckpointReward(p,"meadow_sky",22,ctx()).Amount,0)
 assert(not pcall(function() Engine:CompleteRoute(p,"citadel_sky",ctx()) end)); assert(not act(p,"CompleteRoute","meadow_sky"))
 local reward=Engine:CheckpointReward(p,"meadow_sky",8,ctx()); eq(reward.Amount,100); p=Engine:Normalize(p); eq(Engine:CheckpointReward(p,"meadow_sky",8,ctx()).Amount,0)
end)
test("failed atomic course completion never exposes an exclusive pet",function()
 local a,_,make=persistence(); local s=make("one"); s:Load(1); a.Fail=true
 assert(not s:CommitMutation(1,function(p: any) return true,Engine:CompleteRoute(p,"meadow_sky",ctx()) end)); eq(s:Get(1).Pets.meadow_sky,nil); eq(s:Get(1).Obby.FirstClear.meadow_sky,nil)
 a.Fail=false; assert(s:CommitMutation(1,function(p: any) return true,Engine:CompleteRoute(p,"meadow_sky",ctx()) end)); eq(s:Get(1).Pets.meadow_sky,1); eq(a.Records.player_1.Data.Obby.FirstClear.meadow_sky,true)
end)
test("every tutorial objective points to a real panel or course",function()
 local p=profile(); local goal=Objectives.get(p,Config,Engine); eq(goal.Title,"Build your first Aura")
 p.TotalClicks=10; goal=Objectives.get(p,Config,Engine); eq(goal.Course,"meadow_warmup")
 p.Obby.FirstClear.meadow_warmup=true; p.Upgrade=2; goal=Objectives.get(p,Config,Engine); eq(goal.Course,"meadow_sky")
 p.Obby.FirstClear.meadow_sky=true; goal=Objectives.get(p,Config,Engine); eq(goal.Panel,"Worlds")
end)

print(string.format("\n%d passed, %d failed",passed,failed))
if failed>0 then error("Core suite failed") end
