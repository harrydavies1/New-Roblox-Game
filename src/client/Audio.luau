--!nonstrict
-- Bundled Roblox sounds, short envelopes, and layered notes; no upload IDs needed.
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
local CUES = {
	Click = { { "Tap", 2.7, 0.12, 0.055 } },
	Panel = { { "Tap", 3.2, 0.08, 0.04 } },
	Error = { { "Thud", 1.3, 0.09, 0.11 } },
	Crystal = { { "Pop", 1.9, 0.08, 0.075 }, { "Bell", 1.6, 0.07, 0.19, 0.025 } },
	Checkpoint = { { "Tap", 1.8, 0.09, 0.05 }, { "Bell", 1.25, 0.10, 0.25, 0.02 } },
	Success = { { "Bell", 1.05, 0.10, 0.23 }, { "Bell", 1.32, 0.09, 0.30, 0.10 } },
	Upgrade = { { "Bell", 0.94, 0.10, 0.22 }, { "Bell", 1.4, 0.10, 0.3, 0.09 } },
	Level = { { "Bell", 0.9, 0.11, 0.25 }, { "Bell", 1.2, 0.10, 0.3, 0.12 } },
	ObbyComplete = { { "Thud", 1.7, 0.08, 0.09 }, { "Bell", 0.88, 0.12, 0.3 }, { "Bell", 1.1, 0.11, 0.3, 0.13 }, { "Bell", 1.32, 0.11, 0.4, 0.26 } },
	ObbyReset = { { "Tap", 1.4, 0.07, 0.07 } },
	Mog = { { "Thud", 0.8, 0.10, 0.12 }, { "Bell", 0.85, 0.06, 0.18, 0.02 } },
	Travel = { { "Air", 1.3, 0.07, 0.16 }, { "Bell", 1.5, 0.05, 0.18, 0.07 } },
	Purchase = { { "Bell", 0.9, 0.1, 0.22 }, { "Bell", 1.12, 0.10, 0.24, 0.10 }, { "Bell", 1.35, 0.10, 0.35, 0.20 } },
}

local Audio = {}
function Audio.new(getSettings)
	local self = { Last = {}, Voices = 0 }
	task.spawn(function()
		local ids = {}; for _, id in SOURCES do table.insert(ids, id) end
		pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
	end)
	local function voice(note)
		local settings = getSettings()
		if not settings.SFX or self.Voices >= 16 then return end
		self.Voices += 1
		local sound = Instance.new("Sound")
		sound.Name = "MogCue"; sound.SoundId = SOURCES[note[1]]
		sound.PlaybackSpeed = note[2]; sound.Volume = note[3]
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = if note[1] == "Tap" then -7 else -3
		eq.LowGain = if note[1] == "Bell" then -12 else 0
		eq.Parent = sound; sound.Parent = SoundService; sound:Play()
		local duration = note[4]
		task.delay(math.max(0.01, duration - 0.035), function()
			if sound.Parent then TweenService:Create(sound, TweenInfo.new(0.035), { Volume = 0 }):Play() end
		end)
		task.delay(duration, function()
			if sound.Parent then sound:Stop(); sound:Destroy() end
			self.Voices -= 1
		end)
		Debris:AddItem(sound, duration + 0.1)
	end
	function self:Play(kind)
		local settings = getSettings()
		if not settings.SFX then return end
		local now = os.clock()
		local interval = if kind == "Click" then 0.19 elseif kind == "ObbyReset" then 1 else 0.06
		if now - (self.Last[kind] or -100) < interval then return end
		self.Last[kind] = now
		for _, note in CUES[kind] or CUES.Success do
			if note[5] then task.delay(note[5], function() voice(note) end) else voice(note) end
		end
	end
	return self
end
return Audio
