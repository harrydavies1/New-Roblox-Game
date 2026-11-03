--!strict
-- Adapter-injected persistence. Roblox DataStore UpdateAsync provides atomicity;
-- tests use the same module with a deterministic adapter and clock.
local SessionStore = {}
SessionStore.__index = SessionStore
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local output = {}
	for key, item in value do output[key] = clone(item) end
	return output
end
function SessionStore.new(adapter: any, options: any): any
	return setmetatable({ Adapter = adapter, Options = options, Entries = {} }, SessionStore)
end
function SessionStore.Load(self: any, userId: number): (any, string?)
	if self.Entries[userId] then return nil, "already_loaded" end
	local now = self.Options.Clock()
	local blocked = false
	local ok, record = pcall(function()
		return self.Adapter:UpdateAsync("player_" .. tostring(userId), function(old: any): any
			if old ~= nil then
				assert(type(old) == "table" and old.Format == 1 and type(old.Data) == "table", "Invalid save envelope")
			end
			if old and old.Session and old.Session.Id ~= self.Options.SessionId and old.Session.ExpiresAt > now then
				blocked = true; return nil
			end
			blocked = false
			local data = self.Options.Normalize(if old then old.Data else nil)
			if self.Options.Prepare then
				local prepare = self.Options.Prepare :: (any, number) -> ()
				prepare(data, now)
			end
			return { Format = 1, Data = data, Session = { Id = self.Options.SessionId, ExpiresAt = now + self.Options.LeaseSeconds } }
		end)
	end)
	if not ok then return nil, "load_failed" end
	if blocked or not record or not record.Session or record.Session.Id ~= self.Options.SessionId then return nil, "session_locked" end
	local entry = { Data = clone(record.Data), Busy = false, LeaseUntil = record.Session.ExpiresAt, Lost = false, LastSavedAt = now }
	self.Entries[userId] = entry
	return entry.Data, nil
end
function SessionStore.Get(self: any, userId: number): (any, string?)
	local entry = self.Entries[userId]
	if not entry then return nil, "not_loaded" end
	if entry.Lost or self.Options.Clock() >= entry.LeaseUntil then return nil, "session_expired" end
	if entry.Busy then return nil, "busy" end
	return entry.Data, nil
end
function SessionStore.Status(self: any, userId: number): any
	local entry = self.Entries[userId]
	if not entry then return { Loaded = false, Busy = false } end
	return { Loaded = not entry.Lost and self.Options.Clock() < entry.LeaseUntil, Busy = entry.Busy,
		World = entry.Data.CurrentWorld, LastSavedAt = entry.LastSavedAt, LeaseUntil = entry.LeaseUntil }
end
function SessionStore._write(self: any, userId: number, data: any, release: boolean): (boolean, string?)
	local entry = self.Entries[userId]
	local now = self.Options.Clock()
	local lost = false
	local ok, result = pcall(function()
		return self.Adapter:UpdateAsync("player_" .. tostring(userId), function(old: any): any
			if not old or not old.Session or old.Session.Id ~= self.Options.SessionId then lost = true; return nil end
			lost = false
			return { Format = 1, Data = clone(data), Session = if release then nil else { Id = self.Options.SessionId, ExpiresAt = now + self.Options.LeaseSeconds } }
		end)
	end)
	if lost then entry.Lost = true; return false, "session_lost" end
	if not ok or not result then return false, "save_failed" end
	entry.LeaseUntil = now + self.Options.LeaseSeconds
	entry.LastSavedAt = now
	return true, nil
end
function SessionStore.Save(self: any, userId: number, release: boolean?): (boolean, string?)
	local entry = self.Entries[userId]
	if not entry then return false, "not_loaded" end
	if entry.Busy then return false, "busy" end
	entry.Busy = true
	local ok, reason = self:_write(userId, entry.Data, release == true)
	entry.Busy = false
	if ok and release then self.Entries[userId] = nil end
	return ok, reason
end
function SessionStore.CompletePurchase(self: any, userId: number, receiptId: any, grant: (any) -> boolean): (boolean, string?)
	if type(receiptId) ~= "string" or #receiptId == 0 or #receiptId > 160 then return false, "invalid_receipt" end
	local data, reason = self:Get(userId)
	if not data then return false, reason end
	if data.Receipts[receiptId] == true then return true, "duplicate" end
	local entry = self.Entries[userId]
	entry.Busy = true
	local nextData = clone(data)
	local granted, accepted = pcall(grant, nextData)
	if not granted or accepted ~= true then entry.Busy = false; return false, "grant_failed" end
	nextData.Receipts[receiptId] = true
	local committed, saveReason = self:_write(userId, nextData, false)
	-- Balance and receipt marker enter memory together only AFTER durable success.
	if committed then entry.Data = nextData end
	entry.Busy = false
	return committed, saveReason
end
function SessionStore.CommitMutation(self: any, userId: number, mutate: (any) -> (boolean, any)): (boolean, any)
	local data, reason = self:Get(userId)
	if not data then return false, reason end
	local entry = self.Entries[userId]; entry.Busy = true
	local nextData = clone(data)
	local ran, accepted, result = pcall(mutate, nextData)
	if not ran or not accepted then entry.Busy = false; return false, if ran then result else "mutation_failed" end
	local committed, failure = self:_write(userId, nextData, false)
	if committed then entry.Data = nextData end
	entry.Busy = false
	return committed, if committed then result else failure
end
return SessionStore
