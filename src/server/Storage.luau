--!nonstrict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SessionStore = require(script.Parent.SessionStore)

local Storage = {}
function Storage.create(settings, engine)
	local studio = RunService:IsStudio()
	local ok, adapter = pcall(DataStoreService.GetDataStore, DataStoreService, settings.DataStoreName)
	local persistent = ok
	if studio then
		if not settings.StudioUseLiveDataStores then persistent = false
		elseif ok then persistent = pcall(function() adapter:GetAsync("__studio_readiness_v2") end) end
	end
	if not persistent and studio and settings.AllowStudioSandboxFallback then
		local records = {}
		adapter = { UpdateAsync = function(_, key, transform)
			local nextData = transform(engine.Clone(records[key]))
			if nextData then records[key] = engine.Clone(nextData) end
			return engine.Clone(nextData)
		end }
		warn("MOG MODE PREVIEW: saving is off. Publish a test place and enable Studio API access to test persistent saves.")
	elseif not persistent then
		-- Live servers never silently fall back to unsaved profiles.
		adapter = { UpdateAsync = function() error("Persistent storage is unavailable") end }
		persistent = true
	end
	local store = SessionStore.new(adapter, {
		Normalize = function(raw) return engine:Normalize(raw) end,
		Prepare = function(profile, now) engine:Initialize(profile, now) end,
		Clock = os.time, SessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false), LeaseSeconds = settings.LeaseSeconds,
	})
	return store, { Persistent = persistent, PurchasesAllowed = persistent and not studio, Studio = studio }
end
return Storage
