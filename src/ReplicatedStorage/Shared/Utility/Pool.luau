--!strict
--[[
	Pool.luau — generic instance pool.

	The scaffold (§16.3) requires that tracers, projectiles, damage numbers, and
	impact effects are pooled rather than created and destroyed per event. A
	bullet-hell pattern can create hundreds of visuals per second; Instance.new
	churn is the single easiest way to lose frame time on mobile.
]]

local Pool = {}
Pool.__index = Pool

export type Pool<T> = typeof(setmetatable(
	{} :: {
		_factory: () -> T,
		_reset: (T) -> (),
		_free: { T },
		_inUse: number,
		_maxRetained: number,
	},
	Pool
))

function Pool.new<T>(factory: () -> T, reset: (T) -> (), prewarm: number?, maxRetained: number?): Pool<T>
	local self = setmetatable({
		_factory = factory,
		_reset = reset,
		_free = {},
		_inUse = 0,
		_maxRetained = maxRetained or 256,
	}, Pool)

	for _ = 1, prewarm or 0 do
		table.insert(self._free, factory())
	end

	return self :: any
end

function Pool.Get<T>(self: Pool<T>): T
	local item = table.remove(self._free)
	if item == nil then
		item = self._factory()
	end
	self._inUse += 1
	return item :: T
end

function Pool.Release<T>(self: Pool<T>, item: T)
	self._inUse -= 1
	self._reset(item)

	if #self._free >= self._maxRetained then
		-- Over budget: let it go rather than growing memory without bound.
		if typeof(item) == "Instance" then
			(item :: any):Destroy()
		end
		return
	end

	table.insert(self._free, item)
end

function Pool.InUse<T>(self: Pool<T>): number
	return self._inUse
end

function Pool.Clear<T>(self: Pool<T>)
	for _, item in self._free do
		if typeof(item) == "Instance" then
			(item :: any):Destroy()
		end
	end
	table.clear(self._free)
end

return Pool
