--!nonstrict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local DataStoreService=game:GetService("DataStoreService")
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local shared=ReplicatedStorage:WaitForChild("MogShared")
local Config=require(shared.Config)
local Engine=require(shared.Economy).new(Config)
local Settings=require(script.ServerSettings)
local Store=require(script.SessionStore)
local RateLimiter=require(script.RateLimiter)
local WorldService=require(script.WorldService)
local Commerce=require(script.Commerce)
local sandbox=RunService:IsStudio() and not Settings.StudioUseLiveDataStores
local adapter
if sandbox then
 local records={}
 adapter={UpdateAsync=function(_,key,transform)
  local nextRecord=transform(Engine.Clone(records[key])); if nextRecord then records[key]=Engine.Clone(nextRecord) end; return Engine.Clone(nextRecord)
 end}
 warn("MOG MODE STUDIO SANDBOX: temporary progress; purchases off.")
else adapter=DataStoreService:GetDataStore(Settings.DataStoreName) end
local store=Store.new(adapter,{Normalize=function(raw) return Engine:Normalize(raw) end,Clock=os.time,SessionId=game.JobId..":"..HttpService:GenerateGUID(false),LeaseSeconds=Settings.LeaseSeconds})
local folder=Instance.new("Folder"); folder.Name="MogRemotes"; folder.Parent=ReplicatedStorage
local function remote(class,name) local r=Instance.new(class); r.Name=name; r.Parent=folder; return r end
local action=remote("RemoteFunction","Action")
local click=remote("RemoteEvent","Click")
local stateRemote=remote("RemoteEvent","State")
local effect=remote("RemoteEvent","Effect")
local clickLimit=RateLimiter.new(Config.ClickRate,Config.ClickBurst)
local actionLimit=RateLimiter.new(3,6)
local stateLimit=RateLimiter.new(.5,3)
local promptLimit=RateLimiter.new(3,5)
local runtime,loading={},{}
local commerce,worldService
local closing=false
local function context(player) return {Now=os.time(),Passes=if commerce then commerce:GetPasses(player) else {}} end
local function appearance(player,p)
 local ctx=context(player); local pets={}
 for i,id in p.Equipped do if i<=Engine:EquipSlots(ctx) then table.insert(pets,{Id=id,Level=p.Pets[id]}) end end
 player:SetAttribute("MogPets",HttpService:JSONEncode(pets))
 for _,kind in {"Trail","Aura","Title"} do
  local id=p.ActiveCosmetics[kind]; local item=id and Engine.Cosmetics[id]
  player:SetAttribute("Mog"..kind,if item and (p.Cosmetics[id] or (item.Pass and ctx.Passes[item.Pass])) then id else "")
 end
 player:SetAttribute("MogPatron",ctx.Passes.VIP==true); player:SetAttribute("MogRank",Engine:Rank(p.Level))
end
local function snapshot(player)
 local p=store:Get(player.UserId); if not p then return nil end
 Engine:RefreshDay(p,os.time()); local view=Engine.Clone(p); local ctx=context(player)
 view.Receipts=nil; view.ClickValue=Engine:ClickValue(p,ctx); view.XPRequired=Engine:XPRequired(p.Level)
 view.UpgradeCost=Engine:UpgradeCost(p.Upgrade); view.RebirthCost=Engine:RebirthCost(p.Rebirths)
 view.EquipSlots=Engine:EquipSlots(ctx); view.PetMultiplier=Engine:PetMultiplier(p,ctx)
 view.Passes=Engine.Clone(ctx.Passes); view.Catalog=Engine.Clone(if commerce then commerce.Catalog else {})
 view.Sandbox=sandbox; view.ServerTime=os.time(); return view
end
local function push(player)
 if not player.Parent then return end
 local view=snapshot(player); if not view then return end
 stateRemote:FireClient(player,view)
 local stats=player:FindFirstChild("leaderstats"); if stats then stats.Level.Value=view.Level; stats.Rebirths.Value=view.Rebirths end
end
local function changed(player) local p=store:Get(player.UserId); if p then appearance(player,p); push(player) end end
local function warp(player,id)
 local p=store:Get(player.UserId); local rt=runtime[player.UserId]
 if not p or not rt or not Engine.Worlds[id] or not p.Worlds[id] then return false,"Discover this island first." end
 if os.clock()-rt.LastTeleport<2 then return false,"Portal recharging. One moment!" end
 if not worldService:Teleport(player,id) then return false,"Wait for your character to respawn." end
 p.CurrentWorld=id; rt.LastTeleport=os.clock(); changed(player); return true,"Welcome to "..Engine.Worlds[id].Name.."!"
end
worldService=WorldService.new(Config,{
 Collect=function(player,id,crystal)
  if not promptLimit:Allow(player.UserId,os.clock()) then return end
  local p=store:Get(player.UserId); local rt=runtime[player.UserId]
  if not p or not rt or p.CurrentWorld~=id or not p.Worlds[id] then return end
  local key=crystal:GetAttribute("CrystalId"); local now=os.clock()
  if (rt.Crystals[key] or 0)>now then return end
  rt.Crystals[key]=now+Config.ShardCooldown
  local result=Engine:Collect(p,id,crystal.Name:sub(1,5)=="Bonus",context(player))
  if result.Levels>0 then appearance(player,p) end
  effect:FireClient(player,{Kind="Crystal",Id=key,Amount=result.Amount,Cooldown=Config.ShardCooldown}); rt.Dirty=true
 end,
 Portal=function(player,id)
  if not promptLimit:Allow(player.UserId,os.clock()) then return end
  local p=store:Get(player.UserId)
  if p and p.Worlds[id] then local ok,message=warp(player,id); effect:FireClient(player,{Kind=if ok then "Travel" else "Notice",Message=message})
  else effect:FireClient(player,{Kind="OpenPanel",Panel="Worlds"}) end
 end,
 OpenPanel=function(player,panel) if promptLimit:Allow(player.UserId,os.clock()) then effect:FireClient(player,{Kind="OpenPanel",Panel=panel}) end end,
})
commerce=Commerce.new(Config,Settings,store,Engine,sandbox,{
 Changed=changed,
 Purchased=function(player,key) changed(player); effect:FireClient(player,{Kind="Purchase",Message=Engine.Products[key].Name.." delivered!"}) end,
 CatalogReady=function() for _,player in Players:GetPlayers() do push(player) end end,
})
action.OnServerInvoke=function(player,name,payload)
 if closing then return {Ok=false,Message="Server is saving. Please rejoin shortly."} end
 if type(name)~="string" or #name>32 then return {Ok=false,Message="Invalid request."} end
 if name=="GetState" then
  if not stateLimit:Allow(player.UserId,os.clock()) then return {Ok=false,Message="Please wait."} end
  local state=snapshot(player); return {Ok=state~=nil,State=state}
 end
 if not actionLimit:Allow(player.UserId,os.clock()) then return {Ok=false,Message="A little slower, please."} end
 if type(payload)~="table" then return {Ok=false,Message="Invalid request."} end
 local safe={}; if type(payload.Id)=="string" and #payload.Id<=40 then safe.Id=payload.Id end
 if type(payload.Value)=="boolean" then safe.Value=payload.Value end
 local p,reason=store:Get(player.UserId)
 if not p then return {Ok=false,Message=if reason=="busy" then "Saving progress. Try again in a moment." else "Your adventure is loading."} end
 local ok,message
 if name=="Purchase" then ok,message=commerce:Prompt(player,safe.Id)
 elseif name=="Travel" then ok,message=warp(player,safe.Id)
 else ok,message=Engine:Apply(p,name,safe,context(player)); if ok then changed(player) end end
 return {Ok=ok,Message=message,State=snapshot(player)}
end
click.OnServerEvent:Connect(function(player)
 if closing or not clickLimit:Allow(player.UserId,os.clock()) then return end
 local p=store:Get(player.UserId); local rt=runtime[player.UserId]
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not p or not rt or not humanoid or humanoid.Health<=0 then return end
 local result=Engine:Click(p,context(player)); rt.Dirty=true; rt.PendingAura+=result.Amount; rt.PendingClicks+=1
 if result.Levels>0 then appearance(player,p) end
 if result.Burst then effect:FireAllClients({Kind="Mog",UserId=player.UserId}) end
end)
local function release(player)
 local deadline=os.clock()+20
 repeat
  local ok,reason=store:Save(player.UserId,true); if ok or reason=="not_loaded" then return end
  task.wait(if reason=="busy" then .2 else 1)
 until os.clock()>=deadline
 warn("MOG profile release deferred until lease expiry",player.UserId)
end
local function joined(player)
 if closing then player:Kick("This server is closing. Please join another."); return end
 if loading[player.UserId] or runtime[player.UserId] then return end
 loading[player.UserId]=true
 local p,reason
 for attempt=1,4 do
  p,reason=store:Load(player.UserId); if p then break end
  if not player.Parent then return end; task.wait(attempt*1.5)
 end
 if not p then player:Kick("We couldn't safely load your progress ("..tostring(reason).."). Please rejoin in a minute. Saved data was not replaced."); return end
 if not player.Parent or closing then release(player); return end
 runtime[player.UserId]={Dirty=true,PendingAura=0,PendingClicks=0,Crystals={},LastTeleport=-100}
 Engine:RefreshDay(p,os.time())
 local stats=Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=player
 for _,name in {"Level","Rebirths"} do local stat=Instance.new("IntValue"); stat.Name=name; stat.Parent=stats end
 local function characterAdded(c)
  local h=c:WaitForChild("Humanoid",10); local root=c:WaitForChild("HumanoidRootPart",10)
  if not h or not root or not player.Parent then return end
  h.WalkSpeed=22; h.UseJumpPower=true; h.JumpPower=52
  local profile=store:Get(player.UserId); worldService:Teleport(player,if profile then profile.CurrentWorld else "meadow")
 end
 player.CharacterAdded:Connect(characterAdded); if player.Character then task.spawn(characterAdded,player.Character) end
 changed(player); task.spawn(function() commerce:RefreshPasses(player); changed(player) end)
end
Players.PlayerAdded:Connect(joined); for _,p in Players:GetPlayers() do task.spawn(joined,p) end
Players.PlayerRemoving:Connect(function(player)
 release(player); runtime[player.UserId]=nil; loading[player.UserId]=nil
 for _,limiter in {clickLimit,actionLimit,stateLimit,promptLimit} do limiter:Forget(player.UserId) end
 commerce:Forget(player)
end)
task.spawn(function()
 while not closing do
  task.wait(.2)
  for _,p in Players:GetPlayers() do
   local rt=runtime[p.UserId]
   if rt and rt.Dirty and store:Get(p.UserId) then
    rt.Dirty=false; push(p)
    if rt.PendingClicks>0 then effect:FireClient(p,{Kind="Clicks",Amount=rt.PendingAura,Count=rt.PendingClicks}); rt.PendingAura=0; rt.PendingClicks=0 end
   end
  end
 end
end)
task.spawn(function()
 while not closing do
  task.wait(Settings.AutosaveSeconds)
  for _,p in Players:GetPlayers() do task.spawn(function()
   local ok,reason=store:Save(p.UserId); if not ok and reason~="busy" and reason~="not_loaded" then warn("MOG autosave failed",reason) end
  end) end
 end
end)
task.spawn(function()
 while not closing do
  task.wait(2)
  for _,p in Players:GetPlayers() do
   local profile,reason=store:Get(p.UserId)
   if reason=="session_expired" then p:Kick("Your save session disconnected. Please rejoin to protect your progress.") end
   local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
   if profile and root and root.Position.Y< -30 then worldService:Teleport(p,profile.CurrentWorld) end
  end
 end
end)
game:BindToClose(function()
 closing=true; local remaining=0
 for _,p in Players:GetPlayers() do remaining+=1; task.spawn(function() release(p); remaining-=1 end) end
 local deadline=os.clock()+25; while remaining>0 and os.clock()<deadline do task.wait(.1) end
end)
