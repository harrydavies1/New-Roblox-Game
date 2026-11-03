-- Execute the actual server entry point. Perpetual workers are parked at task.wait;
-- handler, persistence, streaming, and checkpoint calls use explicit boundary fakes.
local bootChecks=0
local function expect(value,message) assert(value,message); bootChecks+=1 end
local bootClock={Now=0}
local bootOs={clock=function() return bootClock.Now end,time=function() return 1000000+math.floor(bootClock.Now) end}
local bootQueue={}
local bootTasks={
 spawn=function(callback,...)
  local args={...}; table.insert(bootQueue,function() callback(table.unpack(args)) end)
 end,
 wait=function() error("background worker parked",0) end,
}
local function runBootQueue()
 local count=0
 while #bootQueue>0 do
  local callback=table.remove(bootQueue,1); local ok,message=pcall(callback)
  if not ok and not tostring(message):find("background worker parked",1,true) then error(message) end
  count+=1; assert(count<100)
 end
end
local bootPlayer=newPlayer(101)
function players:GetPlayers() return {bootPlayer} end
storageMode.Studio=false; storageMode.InitAllowed=true; storageMode.ReadAllowed=true
function services.HttpService:JSONEncode(value)
 local function encode(item)
  if type(item)=="string" then return string.format("%q",item) end
  if type(item)=="number" or type(item)=="boolean" then return tostring(item) end
  local out={}
  if #item>0 then for _,v in item do table.insert(out,encode(v)) end; return "["..table.concat(out,",").."]" end
  for k,v in item do table.insert(out,encode(k)..":"..encode(v)) end; return "{"..table.concat(out,",").."}"
 end
 return encode(value)
end
services.ReplicatedStorage=object("ReplicatedStorage","ReplicatedStorage",nil)
local sharedFolder=object("Folder","MogShared",services.ReplicatedStorage)
for _,name in {"Config","Economy","Objectives"} do object("ModuleScript",name,sharedFolder) end
local bootScript=object("Script","MogServer",nil)
for _,name in {"ServerSettings","RateLimiter","WorldService","ObbyService","Commerce","Storage"} do object("ModuleScript",name,bootScript) end
local bootStore
local bootClose
function game:BindToClose(callback) bootClose=callback end
local nativeRequire=require
local bootSettings=nativeRequire("../src/server/ServerSettings")
-- BOOT MODULES --
local bootModules={
 Config=Config,Economy=nativeRequire("../src/shared/Economy"),Objectives=nativeRequire("../src/shared/Objectives"),
 ServerSettings=bootSettings,RateLimiter=nativeRequire("../src/server/RateLimiter"),WorldService=BootWorldService,ObbyService=BootObbyService,Commerce=BootCommerce,
 Storage={create=function(settings,engine) local loaded,mode=BootStorage.create(settings,engine); bootStore=loaded; return loaded,mode end},
}
local bootRequire=function(token) assert(bootModules[token.Name],token.Name); return bootModules[token.Name] end
-- BOOT SOURCE --
runBootQueue()
expect(bootPlayer.KickReason==nil)
expect(bootPlayer.Character.Humanoid.WalkSpeed==18 and bootPlayer.Character.Humanoid.JumpPower==50)
local bootRemotes=services.ReplicatedStorage.MogRemotes
local actionRemote=bootRemotes.Action
local function request(name,payload)
 bootClock.Now+=.4
 local result=actionRemote.OnServerInvoke(bootPlayer,name,payload or {})
 expect(type(result)=="table","real server handler returned invalid data")
 return result
end
local initial=request("GetState")
expect(initial.Ok and initial.State.Save.Persistent and initial.State.Save.State=="saved")
expect(initial.State.Receipts==nil and initial.State.Objective.Title=="Build your first Aura")
expect(not initial.State.LoginStatus.Ready and initial.State.Login.FirstSeenAt==1000000)
local data=bootStore:Get(101); data.Level=100; data.Aura=1000000000
for _,id in {"candy","coral","cosmos","citadel"} do
 local result=request("UnlockWorld",{Id=id})
 expect(result.Ok and result.State.CurrentWorld==id,"unlock must travel to the new zone")
 local spec=Engine.Worlds[id]; local point=bootPlayer.Character.HumanoidRootPart.Position
 expect(point.X==spec.Origin[1] and point.Z==spec.Origin[2]+29)
 expect(not bootPlayer.Character.HumanoidRootPart.Anchored,"stream preparation must release character physics")
end
data=bootStore:Get(101)
local before=data.Aura
for _=1,1000 do bootRemotes.Click.OnServerEvent:Fire(bootPlayer,999999999) end
expect(data.Aura==before+16 and data.TotalClicks==1,"payloads and autoclick spam cannot multiply authoritative rewards")
bootClock.Now+=.201; bootRemotes.Click.OnServerEvent:Fire(bootPlayer); expect(data.TotalClicks==2)
local forged=request("ClaimObby",{Id="citadel_expert"}); expect(not forged.Ok and data.Pets.citadel_expert==nil)
local buy=request("BuyPet",{Id="citadel_expert"}); expect(not buy.Ok,"exclusive pets cannot be bought even with currency")
local started=request("StartObby",{Id="citadel_warmup"})
expect(started.Ok and started.State.ObbyRun.Id=="citadel_warmup")
local bootRoot=bootPlayer.Character.HumanoidRootPart
local course=map.citadel.Obbies.citadel_warmup
for stage=1,12 do
 bootClock.Now+=.6
 local platform=course.Steps[string.format("%02d",stage)]
 bootRoot.Position=platform.Position+Vector3.new(0,3,0); platform.Touched:Fire(bootRoot)
end
expect(storageRecords.player_101.Data.Obby.FirstClear.citadel_warmup==true,"real handler course completion must be durable")
expect(bootStore:Get(101).Obby.Clears==1)
local delivered
for _,event in bootRemotes.Effect._events do if event.Data.Kind=="ObbyComplete" then delivered=event.Data end end
expect(delivered and delivered.RouteId=="citadel_warmup" and delivered.XP==Engine.Obbies.citadel_warmup.FirstXP,"the real server must deliver the complete prize packet")
local hardStart=request("StartObby",{Id="citadel_expert"}); expect(hardStart.Ok)
local hardCourse=map.citadel.Obbies.citadel_expert
for stage=1,31 do bootClock.Now+=.6; local platform=hardCourse.Steps[string.format("%02d",stage)]; bootRoot.Position=platform.Position+Vector3.new(0,3,0); platform.Touched:Fire(bootRoot) end
storageMode.WriteAllowed=false; bootClock.Now+=.6; bootRoot.Position=hardCourse.Steps["32"].Position+Vector3.new(0,3,0); hardCourse.Steps["32"].Touched:Fire(bootRoot)
expect(bootStore:Get(101).Pets.citadel_expert==nil,"the actual server must not reveal a pet after a failed write")
local leavePending=request("LeaveObby"); expect(not leavePending.Ok and leavePending.State.ObbyRun.RewardPending)
local travelPending=request("Travel",{Id="meadow"}); expect(not travelPending.Ok and travelPending.State.CurrentWorld=="citadel")
storageMode.WriteAllowed=true; bootClock.Now+=5.1; services.RunService.Heartbeat:Fire(.1)
expect(bootStore:Get(101).Pets.citadel_expert==1 and storageRecords.player_101.Data.Pets.citadel_expert==1,"standing still retries and durably delivers the actual server's exclusive prize")
local musicVolume=request("Setting",{Id="MusicVolume",Value=75}); expect(musicVolume.Ok and musicVolume.State.Settings.MusicVolume==75,"numeric music volume must reach the real handler")
local musicMute=request("Setting",{Id="Music",Value=false}); expect(musicMute.Ok and not musicMute.State.Settings.Music and musicMute.State.Settings.SFX)
local badVolume=request("Setting",{Id="MusicVolume",Value=math.huge}); expect(not badVolume.Ok and badVolume.State.Settings.MusicVolume==75)
local save=request("SaveNow"); expect(save.Ok and save.State.Save.State=="saved")
expect(storageRecords.player_101.Data.Settings.MusicVolume==75 and not storageRecords.player_101.Data.Settings.Music,"music preferences persist without muting SFX")
data=bootStore:Get(101); data.Login.FirstSeenAt=bootOs.time()-86400
local login=request("ClaimLogin"); expect(login.Ok and login.State.Login.Claims==1 and login.State.Save.State=="saved")
expect(storageRecords.player_101.Data.Login.Claims==1)
local repeated=request("ClaimLogin"); expect(not repeated.Ok and bootStore:Get(101).Login.Claims==1)
expect(type(bootClose)=="function")
players.PlayerRemoving:Fire(bootPlayer)
expect(bootStore:Get(101)==nil and storageRecords.player_101.Session==nil)
expect(storageRecords.player_101.Data.CurrentWorld=="citadel" and storageRecords.player_101.Data.Login.Claims==1)
print(string.format("PASS: %d actual server-bootstrap handler assertions, including all four zone unlocks, click cooldown, saving and login claims",bootChecks))
