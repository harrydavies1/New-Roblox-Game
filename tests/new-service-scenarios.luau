-- Continue with the explicit boundary fakes and execute the real new modules.
local newChecks=0
local function verify(value,message) assert(value,message); newChecks+=1 end

local storageSettings={DataStoreName="test",StudioUseLiveDataStores=true,AllowStudioSandboxFallback=true,LeaseSeconds=180}
storageMode.Studio=true; storageMode.ReadAllowed=false
local preview,mode=Storage.create(storageSettings,Engine)
verify(not mode.Persistent and not mode.PurchasesAllowed,"unavailable Studio API must be clearly marked as preview")
local previewData=preview:Load(50); verify(previewData~=nil and previewData.Login.FirstSeenAt>0)
previewData.Aura=999; verify(preview:Save(50,true))
local newPreview=Storage.create(storageSettings,Engine); verify(newPreview:Load(50).Aura==0,"preview is not falsely called persistent")
storageMode.ReadAllowed=true
local cloud,cloudMode=Storage.create(storageSettings,Engine)
verify(cloudMode.Persistent and not cloudMode.PurchasesAllowed,"Studio saving must not enable real Robux purchases")
cloud:Load(51).Aura=4321; verify(cloud:Save(51,true))
local rejoin=Storage.create(storageSettings,Engine); verify(rejoin:Load(51).Aura==4321)
storageMode.Studio=false; storageMode.InitAllowed=false
local unavailable,liveMode=Storage.create(storageSettings,Engine)
verify(liveMode.Persistent and unavailable:Load(52)==nil,"live failures must not create unsaved paid profiles")
storageMode.InitAllowed=true

local function drainAudio()
 local steps=0
 while #audioQueue>0 do
  table.sort(audioQueue,function(a,b) return a.At<b.At end)
  local next=table.remove(audioQueue,1); audioClock.Now=next.At; next.Run(); steps+=1; assert(steps<1000)
 end
end
local audioSettings={SFX=true}
local sounds=Audio.new(function() return audioSettings end)
sounds:Play("Click"); verify(sounds.Voices==2)
local active=services.SoundService:GetChildren()
verify(active[1].SoundId=="rbxasset://sounds/action_footsteps_plastic.mp3" and active[1].PlaybackSpeed==2.7,"click uses a dry tap, not the reward bell")
sounds:Play("Click"); verify(sounds.Voices==2,"click sound spam is gated")
drainAudio(); verify(sounds.Voices==0 and #services.SoundService:GetChildren()==0)
audioClock.Now+=1; sounds:Play("ObbyComplete"); verify(sounds.Voices>0); drainAudio(); verify(sounds.Voices==0)
audioClock.Now+=1; sounds:Play("PetUnlock"); audioSettings.SFX=false; sounds:SyncSettings(); verify(sounds.Voices==0,"muting stops active voices immediately")
audioSettings.SFX=true; sounds:SyncSettings(); drainAudio(); verify(sounds.Voices==0,"unmuting cannot revive delayed notes from a muted fanfare")
audioSettings.SFX=false
sounds:Play("Click"); verify(sounds.Voices==0,"muted sound remains muted")
audioSettings.SFX=true; audioClock.Now+=1; verify(sounds:Play("PetUnlock")); verify(not sounds:Play("Level"),"large reward fanfares suppress overlapping level jingles"); drainAudio()
for _,cue in {"Panel","Error","Crystal","Checkpoint","CourseStart","Upgrade","Level","Quest","ObbyComplete","PetUnlock","ObbyReset","Mog","Travel","Purchase","Rebirth"} do
 audioClock.Now+=2; verify(sounds:Play(cue),cue.." must have a distinct defined cue"); drainAudio(); verify(sounds.Voices==0 and #services.SoundService:GetChildren()==0)
end

local visibility=WorldVisibility.new(Engine.Worlds)
for _,spec in Config.Worlds do
 visibility:SetWorld(spec.Id)
 for _,other in Config.Worlds do
  local crystal=map[other.Id].Shards.Shard_01
  verify(crystal.LocalTransparencyModifier==(if spec.Id==other.Id then 0 else 1))
  verify(crystal.CollectPrompt.Enabled==(spec.Id==other.Id))
 end
end
local streamed=object("Part","NewlyStreamed",map.meadow.Landscape or map.meadow)
map.DescendantAdded:Fire(streamed); verify(streamed.LocalTransparencyModifier==1,"old streamed islands stay hidden")
visibility:SetWorld("meadow"); verify(streamed.LocalTransparencyModifier==0)
map.DescendantRemoving:Fire(streamed); verify(visibility.WorldOf[streamed]==nil)

local profile=store:Get(1); profile.CurrentWorld="meadow"; for _,w in Config.Worlds do profile.Worlds[w.Id]=true end
marketplace.Failure=false; root.Anchored=false
local rewards,notices={},{}
local obbies=ObbyService.new(Config,store,Engine,{
 Context=function() return {Now=1000+math.floor(obbyClock.Now),Passes={}} end,
 Changed=function() end,Open=function() end,
 Notice=function(_,message) table.insert(notices,message) end,
 Reward=function(_,kind,reward,route) table.insert(rewards,{Kind=kind,Reward=reward,Route=route.Id}) end,
})
for _,route in Config.Obbies do
 profile=store:Get(1); profile.CurrentWorld=route.World
 obbyClock.Now+=3; verify(obbies:Start(p,route.Id))
 local course=map[route.World].Obbies[route.Id]
 root.Position=course.Steps["02"].Position+Vector3.new(0,3,0)
 course.Steps["02"].Touched:Fire(root); verify(obbies.Active[1].Stage==0,"a client cannot skip numbered platforms")
 for stage=1,route.Count do
  obbyClock.Now+=.6
  local platform=course.Steps[string.format("%02d",stage)]
  root.Position=platform.Position+Vector3.new(0,3,0)
  if stage==2 then
   -- A temporary save may be busy while physics keeps running. Touches must be retained.
   store.Entries[1].Busy=true; platform.Touched:Fire(root); verify(obbies.Active[1].Stage==2)
   store.Entries[1].Busy=false; obbies:Drain(p)
  else platform.Touched:Fire(root) end
 end
 verify(obbies.Active[1]==nil,"completion must end the run")
 local last=rewards[#rewards]; verify(last.Kind=="ObbyComplete" and last.Route==route.Id and not last.Reward.Practice)
 verify(records.player_1.Data.Obby.FirstClear[route.Id]==true,"completion is saved before reward acknowledgement")
 if route.PetReward then verify(store:Get(1).Pets[route.PetReward]==1 and records.player_1.Data.Pets[route.PetReward]==1) end
end

profile=store:Get(1); profile.CurrentWorld="meadow"
obbyClock.Now+=3; verify(obbies:Start(p,"meadow_sky"))
local course=map.meadow.Obbies.meadow_sky
for stage=1,10 do obbyClock.Now+=.6; local platform=course.Steps[string.format("%02d",stage)]; root.Position=platform.Position+Vector3.new(0,3,0); platform.Touched:Fire(root) end
verify(obbies.Active[1].Checkpoint==8)
root.Position=course.Hazards.Hazard.Position
course.Hazards.Hazard.Touched:Fire(root); verify(obbies.Active[1].Stage==8,"hazards return to the last checkpoint")
local arm=object("Part","RightUpperArm",p.Character)
course.Hazards.Hazard.Touched:Fire(arm); verify(obbies.Active[1].Stage==8,"safe arms/accessories do not trigger a floor hazard")
obbies:Cancel(p)

-- A failed durable clear is retried at the finish, never granted in memory first.
profile=store:Get(1); profile.CurrentWorld="meadow"; profile.Obby.FirstClear.meadow_expert=nil; profile.Pets.meadow_expert=nil
obbyClock.Now+=3; verify(obbies:Start(p,"meadow_expert"))
course=map.meadow.Obbies.meadow_expert
for stage=1,31 do obbyClock.Now+=.6; local platform=course.Steps[string.format("%02d",stage)]; root.Position=platform.Position+Vector3.new(0,3,0); platform.Touched:Fire(root) end
local before=#rewards; adapter.Fail=true; obbyClock.Now+=.6; root.Position=course.Steps["32"].Position+Vector3.new(0,3,0); course.Steps["32"].Touched:Fire(root)
verify(store:Get(1).Pets.meadow_expert==nil and #rewards==before); verify(obbies.Active[1].Stage==32 and obbies.Active[1].Finished and obbies.Active[1].PendingFinish)
verify(not obbies:Cancel(p) and obbies.Active[1]~=nil,"leaving a course must not discard a verified prize waiting for a save")
verify(not obbies:Start(p,"meadow_warmup"),"a new course cannot overwrite a pending verified prize")
local attempts=adapter.Attempts
for _=1,20 do obbyClock.Now+=.1; services.RunService.Heartbeat:Fire(.1) end
verify(adapter.Attempts==attempts,"a failed prize save must back off instead of hammering storage")
adapter.Fail=false; obbyClock.Now+=5.1; services.RunService.Heartbeat:Fire(.1)
verify(store:Get(1).Pets.meadow_expert==1 and obbies.Active[1]==nil)

-- Walk-on entry and missed physics contacts must work without any menu action.
for _,route in Config.Obbies do
 profile=store:Get(1); profile.CurrentWorld=route.World
 obbyClock.Now+=3
 local c=map[route.World].Obbies[route.Id]
 root.Position=c.Start.Position+Vector3.new(0,3,0)
 c.Start.Touched:Fire(root)
 verify(obbies.Active[1] and obbies.Active[1].Stage==0,"walking onto a course must begin a tracked run")
 c.Start.Touched:Fire(root); verify(obbies.Active[1].Stage==0,"duplicate start contacts must not restart a run")
 local accepted=obbies:Claim(p,route.Id); verify(not accepted,"a prize cannot be claimed remotely from the entrance")
 root.Position=c.Finish.Position
 accepted=obbies:Claim(p,route.Id); verify(not accepted and obbies.Active[1].Stage==0,"the finish prize cannot bypass the route")
 for stage=1,route.Count do
  obbyClock.Now+=.6
  local platform=c.Steps[string.format("%02d",stage)]
  root.Position=platform.Position+Vector3.new(0,3,0)
  -- No Touched event: the actual heartbeat handles the next physical landing.
  services.RunService.Heartbeat:Fire(.1)
 end
 verify(obbies.Active[1]==nil,"every naturally entered course must finish through landing detection")
end

profile=store:Get(1); profile.CurrentWorld="meadow"; obbyClock.Now+=3
course=map.meadow.Obbies.meadow_warmup
root.Position=course.Start.Position+Vector3.new(0,3,0)
services.RunService.Heartbeat:Fire(.1)
verify(obbies.Active[1] and obbies.Active[1].Stage==0,"the entrance also recovers a missed start contact")
for stage=1,11 do obbyClock.Now+=.6; local platform=course.Steps[string.format("%02d",stage)]; root.Position=platform.Position+Vector3.new(0,3,0); platform.Touched:Fire(root) end
obbyClock.Now+=.6; root.Position=course.Steps["12"].Position+Vector3.new(0,3,0)
adapter.Fail=true; local priorAttempts=adapter.Attempts
course.Finish.ClaimPrize.Triggered:Fire(p)
verify(adapter.Attempts==priorAttempts+1 and obbies.Active[1].PendingFinish,"a prompt recovering a missed final contact must make only one delivery attempt")
course.Finish.ClaimPrize.Triggered:Fire(p); verify(adapter.Attempts==priorAttempts+1,"manual retries are rate limited")
adapter.Fail=false; obbyClock.Now+=5.1; services.RunService.Heartbeat:Fire(.1)
verify(obbies.Active[1]==nil,"the real prize prompt recovers a missed final contact")
local rewardCount=#rewards; course.Finish.ClaimPrize.Triggered:Fire(p)
verify(#rewards==rewardCount,"repeated prize interactions never duplicate rewards")

obbyClock.Now+=3; root.Position=course.Start.Position+Vector3.new(0,3,0)
store.Entries[1].Busy=true; course.Start.Touched:Fire(root)
verify(obbies.Active[1] and obbies.Active[1].Stage==0,"an autosave must not swallow a real walk-on start")
store.Entries[1].Busy=false; obbies:Cancel(p)

local guideState=Engine.Clone(store:Get(1)); guideState.Objective={Course="meadow_warmup"}; guideState.ObbyRun=nil
local guide=CourseGuide.new(Config,Engine,function() return guideState end)
guide:Update(); verify(guide.Arrow.Enabled and guide.Arrow.Adornee==course.Start)
guideState.ObbyRun={Id="meadow_warmup",Stage=3,Count=12}
guide:Update(); verify(guide.Arrow.Adornee==course.Steps["04"] and guide.Text.Text=="▼ NEXT 4/12")
guideState.CurrentWorld="candy"; guide:Update(); verify(not guide.Arrow.Enabled,"a previous island's guidance must disappear")
guideState.CurrentWorld="meadow"; guideState.ObbyRun.Stage=12; guideState.ObbyRun.RewardPending=true
guide:Update(); verify(guide.Arrow.Adornee==course.Finish and course.Finish.ClaimPrize.ActionText=="Retry prize save")
guideState.ObbyRun=nil; guideState.Obby.FirstClear.meadow_warmup=true; guide:Update()
verify(not course.Finish.ClaimPrize.Enabled and course.Finish.CourseSign.Label.Text=="PRIZE COLLECTED\nReplay from START")
guide:Celebrate("meadow_warmup"); guide:Update(); verify(not guide.Arrow.Enabled,"a prize celebration briefly clears the guidance marker")
local surface=object("SurfaceGui","StageNumber",course.Steps["01"])
map.DescendantAdded:Fire(surface); visibility:SetWorld("cosmos"); verify(not surface.Enabled)
visibility:SetWorld("meadow"); verify(surface.Enabled,"stage lettering respects island masking")

-- Execute the actual effect dispatcher with explicit UI/audio boundaries. A real
-- finish packet must open its prize card and choose the pet/route fanfare.
services.RunService.RenderStepped=signal()
function services.CollectionService:GetTagged(tag)
 local list={}; for item,value in self.Tags do if value==tag then table.insert(list,item) end end; return list
end
function services.CollectionService:GetInstanceAddedSignal() return signal() end
function services.CollectionService:GetInstanceRemovedSignal() return signal() end
function services.HttpService:JSONDecode() return {} end
local shown,played,celebrated={},{},{}
local fakeUI={State={Settings={Effects=false,SFX=true}},Screen=object("ScreenGui","EffectTest",nil)}
function fakeUI:ShowReward(event) table.insert(shown,event) end
function fakeUI:DismissReward() self.Dismissed=true end
function fakeUI:Toast(message,success) self.LastToast=message; self.LastSuccess=success end
function fakeUI:SetSaveStatus(state) self.SaveState=state end
local dispatcher=Effects.new(Config,Engine,require("../src/shared/Format"),{},fakeUI,{Play=function(_,cue) table.insert(played,cue) end,SyncSettings=function() end})
dispatcher.Guide={Celebrate=function(_,id) table.insert(celebrated,id) end}
for _,route in Config.Obbies do
 local fresh=Engine:NewProfile(); fresh.Worlds[route.World]=true; fresh.CurrentWorld=route.World
 local reward=Engine:CompleteRoute(fresh,route.Id,{Now=1000,Passes={}})
 local packet={Kind="ObbyComplete",Course=route.Name,RouteId=route.Id,Amount=reward.Amount,XP=reward.XP,Pet=reward.Pet,First=reward.First,Practice=false}
 dispatcher:Handle(packet)
 verify(shown[#shown]==packet and shown[#shown].XP==route.FirstXP,"finish XP and pet reach the actual prize dispatcher")
 verify(played[#played]==(if route.PetReward then "PetUnlock" else "ObbyComplete"))
 verify(celebrated[#celebrated]==route.Id)
end
local finishCount=#shown; dispatcher:Handle({Kind="ObbyComplete",Practice=true}); verify(#shown==finishCount,"practice never pretends to award a prize")
dispatcher:Handle({Kind="CourseStart",Course="Hop to the Top",Count=22}); verify(played[#played]=="CourseStart" and fakeUI.LastToast:find("22",1,true)~=nil and fakeUI.Dismissed==true)
dispatcher:Handle({Kind="RewardStatus",Message="Saving prize"}); verify(fakeUI.LastToast=="Saving prize" and fakeUI.LastSuccess==false)
dispatcher:Handle({Kind="SaveStatus",State="retry"}); verify(fakeUI.SaveState=="retry")

print(string.format("PASS: %d new service assertions for durable saving, layered audio, island masking, and all 15 courses",newChecks))
