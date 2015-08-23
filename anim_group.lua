
local tween = require 'tween'

local loop_create, sequence_create, parallel_create

local common_multiplier = function(self, times)
	return loop_create{action = self, times = times}
end

local common_adder = function(self, action)
	return sequence_create{self, action}
end

local common_divider = function(self, action)
	return parallel_create{self, action}
end

-- sequence
local sequence_mt = {
	__index = {
		update = function(self, dt)
			if self.index == nil then
				return true 
			end

			local action = self.actions[self.index]
			if action == nil then
				return true 
			end

			local complete = action:update(dt)
			if complete then
				self.index = self.index + 1
				if self.actions[self.index] == nil then
					self.index = nil
					return true
				end
			end

			return false
		end,
		reset = function(self)
			self.index = 1

			for _, action in ipairs(self.actions) do
				action:reset()
			end
		end
	}, 
	__mul = common_multiplier,
	__add = function(self, action)
		table.insert(self.actions, action)
		return self
	end,
	__div = common_divider
}

sequence_create = function(t)
	local sequence_action = { actions = t, index = 1 }
	setmetatable(sequence_action, sequence_mt)
	return sequence_action
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
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = function(self, action)
		table.insert(self.actions, action)
		return self
	end
}

parallel_create = function(t)
	local parallel_action = {actions = t}
	setmetatable(parallel_action, parallel_mt)
	return parallel_action
end

-- loop
local loop_mt = {
	__index = {	
		update = function(self, dt)
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
			self.left = self.times
			self.action:reset()
		end
	},
	__mul = function(self, times)
		self.times = self.times * times
		self.left = self.times
	end,
	__add = common_adder,
	__div = common_divider
}

loop_create = function(t)
	local loop_action = {left = t.times, times = t.times, action = t.action}
	setmetatable(loop_action, loop_mt)
	return loop_action
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
					for key, value in pairs(t.from) do
						t.subject[key] = value
					end
				end
				
				local target = t.to
				if target == nil then
					target = {}
					for key, value in pairs(t.offset) do
						target[key] = t.subject[key] + t.offset[key]
					end
				end

				self.tween = tween.new(t.duration or 1, t.subject, target, t.easing)
			end

			return self.tween:update(dt)
		end,
		reset = function(self)
			self.tween = nil
		end
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
}

local function tween_create(t)
	assert(type(t.subject) == 'table' or type(t.subject) == 'userdata', 'tween expect a subject')
	assert(t.to or t.offset, 'tween expect to or offset')

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
			self.func()
			return true
		end,
		reset = function(self) end
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
}

local function func_create(t)
	local func_action = {func = type(t) == 'function' and t or t.func}
	setmetatable(func_action, func_mt)
	return func_action
end

return {
	sequence = sequence_create,
	parallel = parallel_create,
	loop = loop_create,
	tween = tween_create,
	tween_group = tween_group_create,
	delay = delay_create,
	func = func_create,
}
