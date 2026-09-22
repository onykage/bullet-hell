--!strict
--[[
	Network/RateLimits.luau

	Per-player, per-action token buckets (§15.3).

	Exceeding a limit discards the request and records a signal. It does not
	punish: a player on a bad connection can burst legitimately, and the
	scaffold explicitly warns against automatic punishment of uncertain cases
	(§C18). Escalation is AntiAbuseService's decision, made over a longer window.
]]

local RateLimits = {}

export type Budget = {
	capacity: number, -- max burst
	refillPerSecond: number,
}

-- Budgets are deliberately generous relative to legitimate play; the precise
-- cadence check for firing lives in WeaponService, which knows the weapon.
RateLimits.Budgets = {
	FireWeapon = { capacity = 30, refillPerSecond = 25 } :: Budget,
	ReloadWeapon = { capacity = 4, refillPerSecond = 2 } :: Budget,
	EquipWeapon = { capacity = 6, refillPerSecond = 3 } :: Budget,
	MovementAbility = { capacity = 10, refillPerSecond = 6 } :: Budget,
	ArenaRequest = { capacity = 4, refillPerSecond = 1 } :: Budget,
}

type Bucket = { tokens: number, lastRefill: number, rejected: number }

local buckets: { [number]: { [string]: Bucket } } = {}

--[[
	Returns true when the action is allowed. Increments a per-action rejection
	counter otherwise, which AntiAbuseService reads.
]]
function RateLimits.consume(userId: number, action: string, now: number?): boolean
	local budget = RateLimits.Budgets[action]
	assert(budget, `[RateLimits] no budget declared for action {action}`)

	local timestamp = now or os.clock()
	local playerBuckets = buckets[userId]
	if not playerBuckets then
		playerBuckets = {}
		buckets[userId] = playerBuckets
	end

	local bucket = playerBuckets[action]
	if not bucket then
		bucket = { tokens = budget.capacity, lastRefill = timestamp, rejected = 0 }
		playerBuckets[action] = bucket
	end

	local elapsed = math.max(0, timestamp - bucket.lastRefill)
	bucket.tokens = math.min(budget.capacity, bucket.tokens + elapsed * budget.refillPerSecond)
	bucket.lastRefill = timestamp

	if bucket.tokens < 1 then
		bucket.rejected += 1
		return false
	end

	bucket.tokens -= 1
	return true
end

function RateLimits.rejectionCount(userId: number, action: string): number
	local playerBuckets = buckets[userId]
	local bucket = playerBuckets and playerBuckets[action]
	return bucket and bucket.rejected or 0
end

function RateLimits.clearPlayer(userId: number)
	buckets[userId] = nil
end

return RateLimits
