--!strict
--[[
	tests/init.luau — tiny assertion-based test runner.

	Deliberately not a framework. The scaffold asks for unit tests on the pure
	calculators and validators (§C18), and those need exactly three things:
	run a function, compare a value, report the failure with a useful message.

	Tests run inside Roblox (Studio play-test, or a published run) because the
	modules under test use Vector3, CFrame, and Random. Running them headlessly
	would mean shimming the Roblox types, and a shim that drifts from the real
	engine gives false confidence — worse than no test.
]]

local Tests = {}

export type Context = {
	describe: (name: string, body: () -> ()) -> (),
	it: (name: string, body: () -> ()) -> (),
	expectEqual: (actual: any, expected: any, message: string?) -> (),
	expectNear: (actual: number, expected: number, tolerance: number, message: string?) -> (),
	expectTrue: (value: any, message: string?) -> (),
	expectFalse: (value: any, message: string?) -> (),
	expectError: (body: () -> (), message: string?) -> (),
}

function Tests.run(specs: { ModuleScript }): (number, number)
	local passed, failed = 0, 0
	local prefix = ""

	local context: Context
	context = {
		describe = function(name, body)
			local previous = prefix
			prefix = if previous == "" then name else `{previous} › {name}`
			body()
			prefix = previous
		end,

		it = function(name, body)
			local label = if prefix == "" then name else `{prefix} › {name}`
			local ok, err = pcall(body)
			if ok then
				passed += 1
			else
				failed += 1
				warn(`  ✗ {label}\n      {err}`)
			end
		end,

		expectEqual = function(actual, expected, message)
			if actual ~= expected then
				error(
					`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`,
					2
				)
			end
		end,

		expectNear = function(actual, expected, tolerance, message)
			if math.abs(actual - expected) > tolerance then
				error(`{message or "values differ"}: expected {expected} ± {tolerance}, got {actual}`, 2)
			end
		end,

		expectTrue = function(value, message)
			if not value then
				error(`{message or "expected truthy"}, got {tostring(value)}`, 2)
			end
		end,

		expectFalse = function(value, message)
			if value then
				error(`{message or "expected falsy"}, got {tostring(value)}`, 2)
			end
		end,

		expectError = function(body, message)
			local ok = pcall(body)
			if ok then
				error(message or "expected the call to error, but it succeeded", 2)
			end
		end,
	}

	for _, spec in specs do
		if not spec:IsA("ModuleScript") or spec.Name == "init" then
			continue
		end
		local ok, err = pcall(function()
			require(spec)(context)
		end)
		if not ok then
			failed += 1
			warn(`  ✗ {spec.Name} failed to load\n      {err}`)
		end
	end

	return passed, failed
end

return Tests
