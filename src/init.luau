--[=[
	@class Attempt
]=]

local sleep: (number?) -> number = if _G.RUNTIME == "lune"
	then require("@lune/task").wait
	elseif _G.RUNTIME == "roblox" then task.wait
	else error("unreachable")

--[=[
	@within Attempt
	@type Status "success" | "retry" | "quit"

	The first return argument of the function passed to [Attempt.custom].
	Check it to understand how it interprets the different statuses.

	A common pattern is to just return "retry" upon a function throwing an error, and "success" otherwise.
	For this you can use the [Attempt.wrap] function.
	
	For example:
	```lua
	attempt.custom(nil, function()
		local success, data = pcall(func)
		return if success then "success" else "retry", data
	end)
	```
	Could be written as:
	```lua
	attempt.custom(nil, attempt.wrap(func))
	```
]=]
export type Status = "success" | "retry" | "quit"

--[=[
	@within Attempt
	@type Delay number | (attempt: number) -> number

	The delay between retries in seconds.
	
	If this is a function, it gets called with the current amount of attempts that have already been made,
	and the return value is the delay until the next retry.
]=]
export type Delay = number | (attempt: number) -> number

--[=[
	@within Attempt
	@interface Settings
	.maxAttempts number? -- Max amount of retries that can be made (default: 5)
	.delay Delay? -- The delay between retries (default: 1)

	Settings that you can pass to [Attempt.custom].
]=]
export type Settings = {
	maxAttempts: number?,
	delay: Delay?,
}

--[=[
	@within Attempt

	Takes in a [Settings] object, a function that returns a [Status] along with any other return values,
	and any extra values that should be passed to the function.

	This function then begins a series of steps:
	1. Call the function with the extra parameters passed into this function.
	2. If the function doesn't throw an error and returns "success":  
	this function immediately quits and returns true along with any other return values from the function.
	3. If the function doesn't throw an error and returns "quit":  
	this function immediately quits and returns false along with any other return values from the function.
	4. If the function does throw an error or returns "retry",  
	and if the current amount of attempts that have been made is equal to the set amount of max attempts:  
	this function immediately quits and returns false along with the error message if the function threw an error,
	or any other return values from the function.
	5. 
]=]
local function custom<T..., U...>(settings: Settings, func: (T...) -> (Status, U...), ...: T...): (boolean, U...)
	local attempt = 0
	local maxAttempts = settings.maxAttempts or 5
	local delay = settings.delay or 1

	while true do
		attempt += 1

		local result = table.pack(pcall(func, ...)) :: { [number]: any, n: number }
		if result[1] == true and result[2] == "success" then
			return true, unpack(result, 3, result.n)
		end

		if result[2] == "quit" or attempt >= maxAttempts then
			return false, result[2]
		end

		if maxAttempts == math.huge and attempt == 30 then
			(warn or print)(debug.traceback(`Infinite attempt possible`, 2))
		end

		local currentDelay: number?
		if type(delay) == "number" then
			currentDelay = delay
		elseif type(delay) == "function" then
			currentDelay = delay(attempt)
		end

		if currentDelay ~= nil and currentDelay > 0 then
			sleep(currentDelay)
		end
	end
end

--[=[
	@within Attempt

	Takes a function and return a new one, that will call the original function and return either "success" or "retry"
	along with the other return values from the original function.

	```lua
	attempt.custom(nil, attempt.wrap(func))
	```
	Would be the same as writing:
	```lua
	attempt.custom(nil, function(...)
		local result = table.pack(pcall(func, ...))
		local status = if result[1] == true then "success" else "retry"
		return status, unpack(result, 2, result.n)
	end)
	```
]=]
local function wrap<T..., U...>(func: (T...) -> U...): (T...) -> (Status, U...)
	return function(...)
		local result = table.pack(pcall(func, ...)) :: { [number]: any, n: number }
		return if result[1] == true then "success" else "retry", unpack(result, 2, result.n)
	end
end

local function exponentialBackoff(attempt: number): number
	return 2 ^ (attempt - 1)
end

--[=[
	@within Attempt
]=]
local function forever<T..., U...>(delay: Delay?, func: (T...) -> U..., ...: T...): (boolean, U...)
	return custom({
		maxAttempts = math.huge,
		delay = delay,
	}, wrap(func), ...) :: any
end

--[=[
	@within Attempt
]=]
local function exponentially<T..., U...>(maxAttempts: number?, func: (T...) -> U..., ...: T...): (boolean, U...)
	return custom({
		maxAttempts = maxAttempts,
		delay = exponentialBackoff,
	}, wrap(func), ...) :: any
end

return setmetatable({
	custom = custom,
	wrap = wrap,

	forever = forever,
	exponentially = exponentially,
}, {
	__call = function<T..., U...>(_, maxAttempts: number?, delay: Delay?, func: (T...) -> U..., ...: T...): (boolean, U...)
		return custom({
			maxAttempts = maxAttempts,
			delay = delay,
		}, wrap(func), ...) :: any
	end,
})
