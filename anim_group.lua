
local tween = require 'tween'

local loop_create, sequence_create, parallel_create, empty_action

local common_multiplier = function(self, times)
	return loop_create(self, times)
end

local common_adder = function(self, action)
	return sequence_create{self, action}
end

local common_divider = function(self, action)
	return parallel_create{self, action}
end

local common_update = function(self, dt)
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

local nonempty_actions = function(actions)
	local filtered = {}
	for _, action in ipairs(actions) do
		if action ~= empty_action then
			table.insert(filtered, action)
		end
	end

	if next(filtered) then
		return filtered
	else
		return nil
	end
end

local dummy_func = function() end

-- sequence
local sequence_mt = {
	__index = {
		step = function(self, dt)
			for _, action in ipairs(self.actions) do
				local complete = false
				repeat
					complete = action:update(dt)
					dt = next_dt()
				until complete
			end
		end,
		update = common_update,
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
	__mul = common_multiplier,
	__add = function(self, action)
		table.insert(self.actions, action)
		return self
	end,
	__div = common_divider
}

local function anim_group_create(actions, mt)
	local actions = nonempty_actions(actions)
	if actions then
		return setmetatable({ actions = actions }, mt)
	else
		return empty_action
	end
end

sequence_create = function(t)
	return anim_group_create(t, sequence_mt)
end

-- parallel
parallel_mt = {
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
			for _, action in ipairs(self.actions) do
				action:reset()
			end
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
	__mul = common_multiplier,
	__add = common_adder,
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
local loop_number_mt = {
	__index = {	
		update = function(self, dt)
			if self.left == nil then
				self.left = self.times
			end

			local complete = self.action:update(dt)
			if complete then
				self.left = self.left - 1
				if self.left == 0 then
					return true
				else
					self.action:reset()
				end
			end

			return false
		end,
		reset = function(self)
			self.left = nil
			self.action:reset()
		end,
		estimated_duration = function(self)
			local duration = self.action:estimated_duration()
			if duration then
				return duration * self.times
			end
		end
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
}

local loop_function_mt = {
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
				error('Unknown state ' .. tostring(state))
			end
		end,
		reset = function(self)
			self.action:reset()
		end,
		estimated_duration = dummy_func,
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
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
local delay_mt = {
	__index = {
		update = function(self, dt)
			local new_value = self.left - dt
			if new_value <= 0 then
				return true
			else
				self.left = new_value
				return false
			end
		end,
		reset = function(self)
			self.left = self.duration
		end,
		estimated_duration = function(self)
			return self.duration
		end
	},
	__mul = function(self, times)
		self.duration = self.duration * times
		self.left = self.duration
	end,
	__add = function(self, action)
		if getmetatable(action) == delay_mt then
			self.duration = self.duration + action.duration
			self.left = self.duration
		else
			return common_adder(self, action)
		end
	end,
	__div = function(self, action)
		if getmetatable(action) == delay_mt then
			self.duration = math.max(self.duration, action.duration)
			self.left = self.duration
		else
			return common_divider(self, action)
		end
	end
}

local function delay_create(t)
	local duration = type(t) == 'number' and t or t.duration
	local delay_action = {left = duration, duration = duration}
	setmetatable(delay_action, delay_mt)
	return delay_action
end

-- tween

local tween_mt = {
	__index = {
		update = function(self, dt)
			if self.tween == nil then
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

				self.tween = tween.new(t.duration or 1, t.subject, target, t.easing)
			end

			return self.tween:update(dt)
		end,
		reset = function(self)
			self.tween = nil
		end,
		estimated_duration = function(self)
			return self.config.duration or 1
		end
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
}

local function tween_create(t)
	assert(type(t.subject) == 'table' or type(t.subject) == 'userdata', 'tween expect a subject')
	assert(t.to or t.delta, 'tween expect to or delta')

	local tween_action = {config = t}
	setmetatable(tween_action, tween_mt)
	return tween_action
end

-- tween_group

local function tween_group_create(t)
	local subject = t.subject
	local actions = {}
	for _, tween in ipairs(t.tweens) do
		tween.subject = subject
		table.insert(actions, tween_create(tween))
	end

	return (t.order == 'parallel') and parallel_create(actions) or sequence_create(actions)
end

-- func
local func_mt = {
	__index = {
		update = function(self, dt)
			self:func()
			return true
		end,
		reset = dummy_func,
		estimated_duration = function(self)
			return 0
		end
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
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
