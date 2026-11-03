--!strict
local RateLimiter = {}
RateLimiter.__index = RateLimiter
function RateLimiter.new(rate: number, burst: number): any
	assert(rate > 0 and burst >= 1)
	return setmetatable({ Rate = rate, Burst = burst, Buckets = {} }, RateLimiter)
end
function RateLimiter.Allow(self: any, key: any, now: number): boolean
	local bucket = self.Buckets[key]
	if not bucket then bucket = { Tokens = self.Burst, Time = now }; self.Buckets[key] = bucket end
	bucket.Tokens = math.min(self.Burst, bucket.Tokens + math.max(0, now - bucket.Time) * self.Rate)
	bucket.Time = math.max(bucket.Time, now)
	if bucket.Tokens < 1 then return false end
	bucket.Tokens -= 1
	return true
end
function RateLimiter.Forget(self: any, key: any) self.Buckets[key] = nil end
return RateLimiter
