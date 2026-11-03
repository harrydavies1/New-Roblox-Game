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
sounds:Play("Click"); verify(sounds.Voices==1)
local active=services.SoundService:GetChildren()
verify(active[1].SoundId=="rbxasset://sounds/action_footsteps_plastic.mp3" and active[1].PlaybackSpeed==2.7,"click uses a dry tap, not the reward bell")
sounds:Play("Click"); verify(sounds.Voices==1,"click sound spam is gated")
drainAudio(); verify(sounds.Voices==0 and #services.SoundService:GetChildren()==0)
audioClock.Now+=1; sounds:Play("ObbyComplete"); verify(sounds.Voices>0); drainAudio(); verify(sounds.Voices==0)
audioClock.Now+=1; sounds:Play("Success"); audioSettings.SFX=false; drainAudio(); verify(sounds.Voices==0)
sounds:Play("Click"); verify(sounds.Voices==0,"muted sound remains muted")

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
verify(store:Get(1).Pets.meadow_expert==nil and #rewards==before); verify(obbies.Active[1].Stage==31 and not obbies.Active[1].Finished)
adapter.Fail=false; obbyClock.Now+=.6; course.Steps["32"].Touched:Fire(root)
verify(store:Get(1).Pets.meadow_expert==1 and obbies.Active[1]==nil)

print(string.format("PASS: %d new service assertions for durable saving, layered audio, island masking, and all 15 courses",newChecks))
