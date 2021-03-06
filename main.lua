
local logo = love.graphics.newImage('logo.png')
local ag = require 'anim_group'
local title = ''
local titleFont = love.graphics.newFont('AvenirNextLTPro-Regular.otf', love.window.toPixels(30))

local Sprite = {}
Sprite.__index = Sprite

function Sprite:draw()
	if self.visible then
		local x, y = love.window.toPixels(self.x), love.window.toPixels(self.y)
		love.graphics.draw(self.image, x, y, self.angle, 1, 1, self.image:getWidth()/2, self.image:getHeight()/2)
	end
end

function Sprite.new(image, x, y)
	local sprite = {image = image, x = x, y = y, angle = 0, visible = true}
	setmetatable(sprite, Sprite)
	return sprite
end

local screen_center = {
	x = love.window.getWidth()/2, 
	y = love.window.getHeight()/2
}

local logo1 = Sprite.new(logo, screen_center.x, 0)
local logo2 = Sprite.new(logo, 0, 0)
logo2.visible = false

local anim = 
	ag.func(function()
		title = 'Go around'
	end) +
	ag.tween{
		subject = {angle = 0},
		to = {angle = math.pi * 2},
		duration = 2
	} * function(anim)
		local angle = anim.action.config.subject.angle
		local radius = 100
		logo1.x = screen_center.x + math.cos(angle) * radius
		logo1.y = screen_center.y + math.sin(angle) * radius
	end +
	ag.func(function()
		logo1.x = screen_center.x
		logo1.y = 0
		title = 'Tween: Image drop to the screen center'
	end) +
	ag.tween{
		subject = logo1,
		to = {y = screen_center.y},
		easing = 'outBounce'
	} +

	ag.func(function()
		title = 'Delay: Do nothing for 2 seconds'
	end) +
	ag.delay(2) +

	ag.func(function()
		title = 'Lazy Tween Sequence: Image walks a route like a triangle'
	end) + 
	(
		ag.tween{
			subject = logo1,
			delta = { x = 100, y = 100},
		} + 
		ag.tween{
			subject = logo1,
			delta = { x = -200},
		} +
		ag.tween{
			subject = logo1,
			delta = { x = 100, y = -100},
		}
	) +

	ag.func(function()
		title = 'Parallel Animation: Two images go side'
		logo2.x, logo2.y = logo1.x, logo1.y
		logo2.visible = true
	end) + 
	(
		ag.tween{
			subject = logo1,
			delta = {x = -300}
		} /
		ag.tween{
			subject = logo2,
			delta = {x = 300},
			duration = 2
		}
	) +
	ag.delay(0.5) +

	ag.func(function()
		title = 'Loop: Turn around twice'
		logo2.visible = false
		logo1.x = screen_center.x
		logo1.y = screen_center.y
	end) +
	ag.tween{
		subject = logo1,
		from = {angle = 0},
		to = {angle = 2 * math.pi},
		duration = 0.8
	} * 2

function love.draw()
	love.graphics.setFont(titleFont)
	love.graphics.printf(title, 0, 0, love.graphics.getWidth(), 'center')

	logo1:draw()
	logo2:draw()
end

function love.update(dt)
	anim:update(dt)
end
