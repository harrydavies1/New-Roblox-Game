--!nonstrict
-- Owner-selected full clips plus the game's short bundled arcade motifs.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SOURCES = {
	Tap = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Thud = "rbxasset://sounds/action_jump_land.mp3",
	Air = "rbxasset://sounds/action_jump.mp3",
	Pop = "rbxasset://sounds/impact_water.mp3",
	Bell = "rbxasset://sounds/electronicpingshort.wav",
}
local function note(semitones, volume, duration, at)
	return { "Bell", 0.9 * 2 ^ (semitones / 12), volume, duration, at }
end
local CUES = {
	Click = { { "Tap", 2.7, .065, .055 }, { "Pop", 2.2, .022, .065 } },
	Error = { note(-5, .055, .12), note(-9, .04, .16, .09) },
	CourseStart = { { "Air", 1.8, .035, .13 }, note(0, .05, .12, .02), note(7, .055, .17, .11) },
	Upgrade = { { "Tap", 1.6, .06, .07 }, note(0, .065, .12, .04), note(4, .06, .14, .11), note(12, .065, .22, .18) },
	Level = { note(0, .07, .16), note(7, .065, .17, .10), note(12, .075, .29, .20) },
	Quest = { { "Pop", 1.5, .055, .1 }, note(4, .06, .17, .03), note(12, .075, .26, .14) },
	PetUnlock = { { "Thud", 1.4, .065, .12 }, note(-12, .07, .16, .04), note(0, .075, .18, .17), note(4, .07, .17, .28), note(7, .07, .2, .39), note(12, .08, .36, .51) },
	ObbyReset = { { "Pop", 1.3, .035, .1 }, note(-12, .03, .12, .04) },
	Mog = { { "Thud", .9, .06, .09 }, { "Pop", 1.4, .045, .08, .035 }, note(-5, .04, .14, .07) },
	Travel = { { "Air", 1.25, .055, .21 }, note(7, .04, .17, .06), note(12, .055, .21, .15) },
	Purchase = { note(0, .065, .16), note(4, .065, .18, .11), note(7, .065, .2, .22), note(12, .075, .3, .33) },
	Rebirth = { { "Air", .85, .06, .3 }, note(-12, .075, .24, .03), note(-5, .07, .23, .15), note(0, .075, .24, .28), note(12, .08, .4, .42) },
}
local MAJOR = { PetUnlock = true, ObbyComplete = true, Rebirth = true, Purchase = true }
local Audio = {}
function Audio.new(getSettings, assetConfig)
	local self = { Last = {}, Voices = 0, Active = {}, Generation = 0, Muted = false, BigRewardUntil = 0 }
	local sources, cues = table.clone(SOURCES), table.clone(CUES)
	for key, definition in assetConfig.Effects do sources[key] = "rbxassetid://" .. definition.Id end
	-- False duration means play the selected clip naturally until Ended.
	cues.Panel = { { "Bubble", 1, assetConfig.Effects.Bubble.Volume, false } }
	cues.Crystal = { { "AuraPickup", 1, assetConfig.Effects.AuraPickup.Volume, false } }
	cues.Checkpoint = { { "AuraPickup", 1, assetConfig.Effects.AuraPickup.Volume * .7, false } }
	cues.ObbyComplete = { { "Victory", 1, assetConfig.Effects.Victory.Volume, false } }
	task.spawn(function()
		local ids = {}; for _, id in sources do table.insert(ids, id) end
		pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
	end)
	local function finish(sound)
		local record = self.Active[sound]
		if not record then return end
		self.Active[sound] = nil; self.Voices -= 1
		for _, connection in record.Connections do connection:Disconnect() end
		if sound.Parent then sound:Stop(); sound:Destroy() end
	end
	function self:SyncSettings()
		local muted = not getSettings().SFX
		if muted and not self.Muted then
			self.Generation += 1
			for sound in self.Active do finish(sound) end
		end
		self.Muted = muted
	end
	local function voice(data, generation, gain)
		if generation ~= self.Generation or not getSettings().SFX or self.Voices >= 12 then return end
		self.Voices += 1
		local sound = Instance.new("Sound")
		sound.Name = "MogCue"; sound.SoundId = sources[data[1]]
		sound.PlaybackSpeed = data[2]; sound.Volume = 0
		local record = { Connections = {}, Armed = false }
		self.Active[sound] = record
		if data[4] then
			local eq = Instance.new("EqualizerSoundEffect")
			eq.HighGain = if data[1] == "Bell" then -8 else -5
			eq.MidGain = if data[1] == "Bell" then -2 else 0
			eq.LowGain = if data[1] == "Bell" or data[1] == "Air" then -12 else -2
			eq.Parent = sound
		else
			table.insert(record.Connections, sound.Ended:Connect(function() finish(sound) end))
			local function arm()
				if not self.Active[sound] or record.Armed or not sound.IsLoaded or sound.TimeLength <= 0 then return end
				record.Armed = true
				local length = sound.TimeLength / sound.PlaybackSpeed
				if data[1] == "Victory" then self.BigRewardUntil = math.max(self.BigRewardUntil, os.clock() + length) end
				-- Ended is primary; this guard also cleans up a missing native event.
				task.delay(length + 1, function() finish(sound) end)
			end
			table.insert(record.Connections, sound.Loaded:Connect(arm))
			sound.Parent = SoundService
			arm()
			task.delay(12, function() if self.Active[sound] and not record.Armed then finish(sound) end end)
		end
		sound.Parent = SoundService; sound:Play()
		-- Short attacks and releases avoid abrupt, harsh cuts when cues overlap.
		TweenService:Create(sound, TweenInfo.new(.008), { Volume = data[3] * gain }):Play()
		local duration = data[4]
		if duration then
			task.delay(math.max(.012, duration - .04), function()
				if self.Active[sound] and sound.Parent then TweenService:Create(sound, TweenInfo.new(.04), { Volume = 0 }):Play() end
			end)
			task.delay(duration, function() finish(sound) end)
			Debris:AddItem(sound, duration + .2)
		end
	end
	function self:Play(kind)
		self:SyncSettings()
		local cue = cues[kind]
		if self.Muted or not cue then return false end
		local now = os.clock()
		local interval = if kind == "Click" then .19 elseif kind == "ObbyReset" then 1 elseif MAJOR[kind] then .65 else .15
		if now - (self.Last[kind] or -100) < interval then return false end
		if kind == "Level" and now < self.BigRewardUntil then return false end
		self.Last[kind] = now
		if MAJOR[kind] then self.BigRewardUntil = math.max(self.BigRewardUntil, now + .9) end
		local gain = if kind == "Click" and now < self.BigRewardUntil then .3 else 1
		local generation = self.Generation
		for _, data in cue do
			if data[5] then task.delay(data[5], function() voice(data, generation, gain) end) else voice(data, generation, gain) end
		end
		return true
	end
	return self
end
return Audio
