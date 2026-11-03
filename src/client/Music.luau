--!nonstrict
-- One client-local song at a time: 1 → 2 → 3 → 1. No respawn/travel restarts.
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Music = {}
function Music.new(config, getSettings)
	assert(#config.Tracks > 0, "Music playlist is empty")
	local self = { Index = 0, Current = nil, NextAt = 0, Failures = 0, State = "waiting", Destroyed = false }
	local function volume(slot, target, immediate)
		if slot.Target == target then return end
		slot.Target = target
		if slot.Tween then slot.Tween:Cancel(); slot.Tween = nil end
		if immediate then slot.Sound.Volume = target
		else slot.Tween = TweenService:Create(slot.Sound, TweenInfo.new(config.FadeSeconds), { Volume = target }); slot.Tween:Play() end
	end
	local function discard()
		local slot = self.Current
		if not slot then return end
		self.Current = nil
		slot.Connection:Disconnect()
		if slot.Tween then slot.Tween:Cancel() end
		slot.Sound:Stop(); slot.Sound:Destroy()
	end
	local function advance(failed)
		discard()
		self.Failures = if failed then self.Failures + 1 else 0
		self.State = if failed then "retrying" else "between"
		self.NextAt = os.clock() + (if self.Failures >= #config.Tracks then config.RetrySeconds else .25)
		if self.Failures >= #config.Tracks then self.Failures = 0 end
	end
	local function start()
		self.Index = self.ResumeIndex or (self.Index % #config.Tracks + 1)
		self.ResumeIndex = nil
		local definition = config.Tracks[self.Index]
		local sound = Instance.new("Sound")
		sound.Name = "MogBackgroundMusic"; sound.SoundId = "rbxassetid://" .. definition.Id
		sound.Volume = 0; sound.Looped = false; sound.PlaybackSpeed = 1
		local slot = { Sound = sound, State = "loading", LoadAt = os.clock(), Ended = false }
		self.Current = slot; self.State = "loading"
		slot.Connection = sound.Ended:Connect(function()
			if self.Current == slot then slot.Ended = true end
		end)
		-- Parenting starts Roblox asset loading; Heartbeat checks IsLoaded without
		-- blocking on Loaded:Wait or spawning an unbounded preload loop.
		sound.Parent = SoundService
	end
	function self:Update()
		if self.Destroyed then return end
		local settings = getSettings()
		if not settings then return end -- wait for persisted preferences before playing
		local slot = self.Current
		if settings.Music == false then
			self.State = "muted"
			if slot and slot.State == "loading" then self.ResumeIndex = self.Index; discard()
			elseif slot and slot.State == "playing" and not slot.Ended then
				volume(slot, 0, true); slot.Sound:Pause(); slot.State = "paused"
			end
			return
		end
		local now = os.clock()
		if not slot then
			if now >= self.NextAt then start() end
			return
		end
		if slot.Ended then advance(false); return end
		local desired = config.MaxVolume * math.clamp(settings.MusicVolume or 50, 0, 100) / 100
		if slot.State == "loading" then
			if slot.Sound.IsLoaded and slot.Sound.TimeLength > 0 then
				slot.State = "playing"; slot.Sound:Play()
				slot.StartedAt = now; slot.Deadline = now + slot.Sound.TimeLength + 4
			elseif now - slot.LoadAt >= config.LoadTimeout then advance(true); return end
		elseif slot.State == "paused" then
			slot.Sound:Resume(); slot.State = "playing"; slot.StartedAt = now
			slot.Deadline = now + math.max(1, slot.Sound.TimeLength - slot.Sound.TimePosition) + 4
		end
		if slot.State == "playing" then
			self.State = "playing"; volume(slot, desired)
			-- Ended is primary. Recover if the asset stops or a native event is lost.
			if now >= slot.Deadline or (now - slot.StartedAt > 2 and not slot.Sound.IsPlaying) then advance(true) end
		end
	end
	function self:View()
		local track = config.Tracks[self.Index]
		return { State = self.State, Title = if track then track.Title else "Three-track playlist", Index = self.Index }
	end
	function self:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true; self.Connection:Disconnect(); discard()
	end
	local elapsed = 0
	self.Connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt; if elapsed >= .1 then elapsed = 0; self:Update() end
	end)
	return self
end
return Music
