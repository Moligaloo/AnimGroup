
local tween = require 'tween'

local loop_create, sequence_create, parallel_create, empty_action

local next_dt = function()
	local self, dt = coroutine.yield(false)
	return dt
end

local extend = function(a, b)
	for k, v in pairs(b) do
		a[k] = v
	end
end

local become = function(a, b)
	for k in pairs(a) do
		a[k] = nil
	end

	extend(a, b)

	setmetatable(a, getmetatable(b))
end

local invoke = function(list, method_name)
	for _, elem in ipairs(list) do
		elem[method_name](elem)
	end
end

local map = function(list, func)
	local results = {}
	for _, elem in ipairs(list) do
		table.insert(results, func(elem))
	end
	return results
end

local dummy_func = function() end

local create_mt = function(config)
	local mt = {
		__index = {}
	}
	function mt:__add(action)
		return sequence_create{self, action}
	end
	function mt:__mul(action)
		return loop_create(self, action)
	end
	function mt:__div(action)
		return parallel_create{self, action}
	end

	function mt.__index:update(dt)
		if self.step == nil then
			error("step method should be implemented")
		end
		self.update = coroutine.wrap(
			function(self, dt)
				self:step(dt)

				while true do
					coroutine.yield(true)
				end
			end
		)

		return self:update(dt)
	end

	function mt.__index:reset()
		self.update = nil
	end

	function mt.__index:estimated_duration()
		return nil
	end

	for k, v in pairs(config) do
		if k == '__index' then
			extend(mt.__index, v)
		else
			mt[k] = v
		end
	end

	return mt
end

-- sequence
local sequence_mt = create_mt {
	__index = {
		step = function(self, dt)
			for _, action in ipairs(self.actions) do
				while not action:update(dt) do
					dt = next_dt()
				end
			end
		end,
		reset = function(self)
			self.update = nil
			invoke(self.actions, 'reset')
		end,
		estimated_duration = function(self)
			local sum = 0
			for _, action in ipairs(self.actions) do
				local duration = action:estimated_duration()
				if duration == nil then
					return nil
				else
					sum = sum + duration
				end
			end
			return sum
		end
	},
	__add = function(self, action)
		table.insert(self.actions, action)
		return self
	end,
}

local function anim_group_create(actions, mt)
	local actions = map(actions, function(action) if action ~= empty_action then return action end end)
	return next(actions) and setmetatable({ actions = actions }, mt) or empty_action
end

sequence_create = function(t)
	return anim_group_create(t, sequence_mt)
end

-- parallel
parallel_mt = create_mt{
	__index = {
		update = function(self, dt)
			local all_complete = true
			for _, action in ipairs(self.actions) do
				local complete = action:update(dt)
				if not complete then
					all_complete = false
				end
			end

			return all_complete
		end,
		reset = function(self)
			invoke(self.actions, 'reset')
		end,
		estimated_duration = function(self)
			local max = 0
			for _, action in ipairs(self.actions) do
				local duration = action:estimated_duration()
				if duration == nil then
					return nil
				else
					max = math.max(max, duration)
				end
			end
			return max
		end
	},
	__div = function(self, action)
		table.insert(self.actions, action)
		return self
	end
}

parallel_create = function(t)
	return anim_group_create(t, parallel_mt)
end

-- empty action
empty_action = {}
local empty_mt = {
	__index = {
		update = function(self, dt)
			return true
		end,
		reset = dummy_func,
		estimated_duration = function()
			return 0
		end
	},
	__mul = function(self, times)
		return self
	end,
	__add = function(self, another)
		return another
	end,
	__div = function(self, another)
		return another
	end
}
setmetatable(empty_action, empty_mt)

-- loop
local loop_number_mt = create_mt{
	__index = {
		step = function(self, dt)
			for i=1, self.times do
				while not self.action:update(dt) do
					dt = next_dt()
				end
				self.action:reset()
			end
		end,
		reset = function(self)
			self.update = nil
			self.action:reset()
		end,
		estimated_duration = function(self)
			local duration = self.action:estimated_duration()
			if duration then
				return duration * self.times
			end
		end
	}
}

local loop_function_mt = create_mt{
	__index = {
		update = function(self, dt)
			local state = self:condition()
			if state == 'running' then
				local complete = self.action:update(dt)
				if complete then
					self.action:reset()
				end
				return false
			elseif state == 'paused' then
				return false
			elseif state == 'stopped' then
				return true
			elseif state == 'once' then
				become(self, self.action)
				return self:update(dt)
			else 
				return self.action:update(dt)
			end
		end,
		reset = function(self)
			self.action:reset()
		end,
	}
}

loop_create = function(action, times)
	if times == true or times == 1 then
		return action
	elseif times == false or times == nil or times == 0 then
		return empty_action
	elseif type(times) == 'number' then
		if getmetatable(action) == loop_number_mt then
			action.times = action.times * times
			return action
		else
			return setmetatable({action = action, times = times}, loop_number_mt)
		end
	elseif type(times) == 'function' then
		return setmetatable({action = action, condition = times}, loop_function_mt)
	end
end

-- delay
local delay_mt = create_mt{
	__index = {
		step = function(self, dt)
			local left = self.duration
			while left > 0 do
				left = left - dt
				dt = next_dt()
			end
		end,
		estimated_duration = function(self)
			return self.duration
		end
	},
	__mul = function(self, times)
		if type(times) == 'number' then
			self.duration = self.duration * times
			return self
		else
			return loop_create(self, times)
		end
	end,
	__add = function(self, action)
		if getmetatable(action) == delay_mt then
			self.duration = self.duration + action.duration
			return self
		else
			return sequence_create{self, action}
		end
	end,
	__div = function(self, action)
		if getmetatable(action) == delay_mt then
			self.duration = math.max(self.duration, action.duration)
			return self
		else
			return parallel_create{self, action}
		end
	end
}

local function delay_create(duration)
	return setmetatable({duration = duration}, delay_mt)
end

-- tween

local tween_mt = create_mt{
	__index = {
		step = function(self, dt)
			local t = self.config
			if t.from then
				extend(t.subject, t.from)
			end

			local target = t.to
			if target == nil then
				target = {}
				for key, value in pairs(t.delta) do
					target[key] = t.subject[key] + t.delta[key]
				end
			end

			local tween = tween.new(self:estimated_duration(), t.subject, target, t.easing)
			while not tween:update(dt) do
				dt = next_dt(dt)
			end
		end,
		estimated_duration = function(self)
			return self.config.duration or 1
		end
	}
}

local function tween_create(config)
	return setmetatable({config = config}, tween_mt)
end

-- tween_group

local function tween_group_create(t)
	local subject = t.subject
	return ((t.order == 'parallel') and parallel_create or sequence_create)(
		map(t.tweens, function(tween) tween.subject = subject; return tween_create(tween) end)
	)
end

-- func
local func_mt = create_mt{
	__index = {
		step = function(self, dt)
			self:func()
		end,
		reset = dummy_func,
		estimated_duration = function(self)
			return 0
		end
	}
}

local function func_create(func)
	return setmetatable({func = func}, func_mt)
end

return {
	sequence = sequence_create,
	parallel = parallel_create,
	tween = tween_create,
	tween_group = tween_group_create,
	delay = delay_create,
	func = func_create,

	empty = empty_action,

	infinite_loop = function() return 'running' end
}
