
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
			local doneList = self.doneList 
			if doneList == nil then
				doneList = {}
				self.doneList = doneList

				for i=1, #self.actions do
					table.insert(doneList, false)
				end
			end

			for i=1, #doneList do
				if doneList[i] == false then
					doneList[i] = self.actions[i]:update(dt)
				end
			end

			local allDone = true
			for _, done in ipairs(doneList) do
				if done == false then
					allDone = false
					break
				end
			end

			return allDone
		end,
		reset = function(self)
			self.doneList = nil

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
			return self.tween:update(dt)
		end,
		reset = function(self)
			return self.tween:reset()
		end
	},
	__mul = common_multiplier,
	__add = common_adder,
	__div = common_divider
}

local function tween_create(t)
	local target = t.target
	if target == nil then
		if t.offset == nil then
			error('target or offset of tween argument must be given')
		end

		target = {}
		for key, value in pairs(t.offset) do
			target[key] = t.subject[key] + t.offset[key]
		end
	end

	local tween_action = {tween = tween.new(t.duration or 1, t.subject, target, t.easing)}
	setmetatable(tween_action, tween_mt)
	return tween_action
end

-- lazy_tween 
local lazy_tween_mt = {
	__index = {
		update = function(self, dt)
			if self.tween == nil then
				self.tween = tween_create(self)
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

local function lazy_tween_create(t)
	local lazy_tween_action = {duration = t.duration, subject = t.subject, target = t.target, offset = t.offset, easing = t.easing}
	setmetatable(lazy_tween_action, lazy_tween_mt)
	return lazy_tween_action
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
	tween = lazy_tween_create,
	delay = delay_create,
	func = func_create,
}
