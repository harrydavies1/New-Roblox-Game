-- Actual Music/Audio code against explicit engine boundaries; no audio is heard.
local cfg=require("../src/shared/AudioConfig")
local checks=0
local function verify(value,message) assert(value,message); checks+=1 end
local function drainUntil(untilTime)
 while #audioQueue>0 do
  table.sort(audioQueue,function(a,b) return a.At<b.At end)
  if audioQueue[1].At>untilTime then break end
  local item=table.remove(audioQueue,1); audioClock.Now=item.At; item.Run()
 end
 audioClock.Now=untilTime
end
local settings=nil
local music=Music.new(cfg.Music,function() return settings end)
local function tick(t) audioClock.Now+=t or .1; music:Update() end
tick(); verify(music.Current==nil,"saved preferences must load before music starts")
settings={Music=false,MusicVolume=50,SFX=true}; tick(); verify(music.Current==nil)
settings.Music=true
local retired
for _,id in {"139132289200391","117496769617516","9045766377","139132289200391"} do
 tick(.3); local current=music.Current
 verify(current and current.Sound.SoundId=="rbxassetid://"..id,"playlist must use the exact requested order and wrap")
 current.Sound.TimeLength=180 -- explicit fake duration, not real asset metadata
 tick(); verify(current.Sound.IsPlaying and not current.Sound.Looped)
 verify(math.abs(current.Sound.Volume-.12)<.0001)
 verify(#services.SoundService:GetChildren()==1,"only one song may exist at a time")
 if retired then retired.Ended:Fire(); verify(music.Current==current,"a late event from a previous song cannot skip the current song") end
 current.Sound.Ended:Fire(); tick()
 verify(music.Current==nil and current.Sound.Parent==nil)
 current.Sound.Ended:Fire(); verify(music.Current==nil,"a stale Ended event must not advance the new song")
 retired=current.Sound
end
tick(.3); music.Current.Sound.TimeLength=180; tick(); local current=music.Current
current.Sound.TimePosition=42
settings.Music=false; tick(); verify(not current.Sound.IsPlaying and current.Sound.Volume==0 and current.Sound.TimePosition==42)
settings.Music=true; tick(); verify(current.Sound.IsPlaying and current.Sound.TimePosition==42,"unmuting resumes instead of restarting")
settings.SFX=false; settings.MusicVolume=75; tick(); verify(math.abs(current.Sound.Volume-.18)<.0001,"music volume is independent of SFX")
settings.MusicVolume=0; tick(); verify(current.Sound.Volume==0)
music:Destroy(); verify(#services.SoundService:GetChildren()==0)
music:Update(); verify(music.Current==nil)

music=Music.new(cfg.Music,function() return settings end)
tick(.3); music.Current.Sound.TimeLength=10; tick()
music.Current.Sound.IsPlaying=false; tick(3); verify(music.Current==nil and music.State=="retrying","a stopped song cannot strand the playlist")
tick(.3); music.Current.Sound.TimeLength=1; tick(); tick(6)
verify(music.Current==nil,"watchdog recovers a lost Ended event")
music:Destroy()

-- Unavailable tracks skip in order, then back off if the whole list fails.
settings={Music=true,MusicVolume=50}; music=Music.new(cfg.Music,function() return settings end)
for index=1,3 do
 tick(.3); verify(music.Index==index)
 music.Current.Sound.IsLoaded=false; music.Current.Sound.TimeLength=0
 tick(cfg.Music.LoadTimeout+.1); verify(music.Current==nil and music.State=="retrying")
end
tick(10); verify(music.Current==nil,"all unavailable tracks must not cause a hot retry loop")
tick(21); verify(music.Index==1 and music.Current~=nil)
music.Current.Sound.IsLoaded=false; settings.Music=false; tick(); verify(music.Current==nil)
settings.Music=true; tick(); verify(music.Index==1,"muting during loading preserves the selected song")
music:Destroy()

local sfxSettings={SFX=true}; local sfx=Audio.new(function() return sfxSettings end,cfg)
for _,entry in {{"ObbyComplete","12222253"},{"Crystal","72264591133889"},{"Panel","132948338000932"},{"Checkpoint","72264591133889"}} do
 audioClock.Now+=2; verify(sfx:Play(entry[1]))
 local sound=services.SoundService:GetChildren()[1]
 verify(sound and sound.SoundId=="rbxassetid://"..entry[2] and sound.PlaybackSpeed==1)
 verify(sound:FindFirstChildOfClass("EqualizerSoundEffect")==nil,"chosen clips keep their original timbre")
 drainUntil(audioClock.Now+.3); verify(sound.Parent~=nil,"custom effects must not use the old short-note cutoff")
 sound.Ended:Fire(); verify(sfx.Voices==0 and sound.Parent==nil)
end
audioClock.Now+=2; sfx:Play("ObbyComplete"); sfxSettings.SFX=false; sfx:SyncSettings()
verify(sfx.Voices==0 and #services.SoundService:GetChildren()==0,"mute cleans up full-clip voices")
sfxSettings.SFX=true
local originalNew=Instance.new
Instance.new=function(class) local o=originalNew(class); if class=="Sound" then o.IsLoaded=false; o.TimeLength=0 end; return o end
audioClock.Now+=2; sfx:Play("Crystal"); local pending=services.SoundService:GetChildren()[1]
drainUntil(audioClock.Now+1); verify(pending.Parent~=nil)
pending.IsLoaded=true; pending.TimeLength=4; pending.Loaded:Fire()
drainUntil(audioClock.Now+2); verify(pending.Parent~=nil,"a slow load must still allow the full selected clip")
pending.Ended:Fire(); verify(sfx.Voices==0)
audioClock.Now+=2; sfx:Play("Panel"); drainUntil(audioClock.Now+13)
verify(sfx.Voices==0 and #services.SoundService:GetChildren()==0,"unavailable SFX release their voice slots")
Instance.new=originalNew
print(string.format("PASS: %d audio assertions for selected assets, playlist order/wrap, mute/resume, volume, load failure, and full effect playback",checks))
