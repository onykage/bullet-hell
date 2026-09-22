--!strict
--[[
	Signal.luau — minimal synchronous signal.

	Used for service-to-service communication so services never reach into each
	other's internals, and so listeners can be disconnected deterministically
	during cleanup.
]]

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable({} :: { _handlers: { (T...) -> () } }, Signal))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal.Connect<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	table.insert(self._handlers, handler)

	local connection
	connection = {
		Connected = true,
		Disconnect = function()
			if not connection.Connected then
				return
			end
			connection.Connected = false
			local index = table.find(self._handlers, handler)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
	return connection
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	-- Iterate a copy: handlers may disconnect themselves or others.
	local snapshot = table.clone(self._handlers)
	for _, handler in snapshot do
		local ok, err = pcall(handler, ...)
		if not ok then
			warn(`[Signal] handler error: {err}`)
		end
	end
end

function Signal.DisconnectAll<T...>(self: Signal<T...>)
	table.clear(self._handlers)
end

return Signal
