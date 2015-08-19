
local logo = love.graphics.newImage('logo.png')
local ag = require 'anim_group'
local title = ''
local titleFont = love.graphics.newFont('AvenirNextLTPro-Regular.otf', love.window.toPixels(30))

local logo1_pos = {x = (love.graphics.getWidth()-logo:getWidth())/2, y = 0}
local logo2_pos = {x = 10000, y = 10000}
local logo1_angle = { angle = 0}
local turn_around = false

local anim = ag.sequence{
	function()
		title = 'Tween: Image drop to the screen center'
	end,
	ag.tween{
		subject = logo1_pos,
		target = {y = (love.graphics.getHeight()-logo:getHeight())/2},
		easing = 'outBounce'
	},

	function()
		title = 'Delay: Do nothing for 2 seconds'
	end,
	2,

	function()
		title = 'Lazy Tween Sequence: Image walks a route like a triangle'
	end,
	ag.sequence{
		ag.lazy_tween{
			subject = logo1_pos,
			offset = { x = 100, y = 100},
		},
		ag.lazy_tween{
			subject = logo1_pos,
			offset = { x = -200},
		},
		ag.lazy_tween{
			subject = logo1_pos,
			offset = { x = 100, y = -100},
		}
	},

	function()
		title = 'Parallel Animation: Two images go side'
		logo2_pos.x = logo1_pos.x
		logo2_pos.y = logo1_pos.y
	end,
	ag.parallel{
		ag.lazy_tween{
			subject = logo1_pos,
			offset = {x = -300}
		},
		ag.lazy_tween{
			subject = logo2_pos,
			offset = {x = 300}
		}
	},

	function()
		title = 'Loop: Turn around twice'
		turn_around = true
		logo2_pos.x = 10000
		logo2_pos.y = 10000
	end,
	ag.loop{
		times = 2,
		action = ag.tween{
			subject = logo1_angle,
			target = {angle = 2 * math.pi},
			duration = 0.8
		}
	}
}

function love.draw()
	love.graphics.setFont(titleFont)
	love.graphics.printf(title, 0, 0, love.graphics.getWidth(), 'center')

	if turn_around then
		local center_x = love.graphics.getWidth()/2
		local center_y = love.graphics.getHeight()/2
		local radius = 200
		love.graphics.draw(
			logo, 
			center_x + radius * math.cos(logo1_angle.angle) - logo:getWidth()/2, 
			center_y + radius * math.sin(logo1_angle.angle) - logo:getHeight()/2
		)
	else	
		love.graphics.draw(logo, logo1_pos.x, logo1_pos.y)
	end

	love.graphics.draw(logo, logo2_pos.x, logo2_pos.y)
end

function love.update(dt)
	anim:update(dt)
end
