# AnimGroup
An animation library for löve game engine, depends on [tween.lua](https://github.com/kikito/tween.lua)
You can make animation groups, including sequetial and parallel animation groups, 
and insert pause for specified seconds and function call inside animation group, or loop animation for specific times.

# Usage
Just drop anim_group.lua to your Löve project and then require it.

# Basic tween animation

```lua
local ag = require 'anim_group'

local logo = love.graphics.newImage('logo.png')
local logo_pos = {
	x = (love.graphics.getWidth()-logo:getWidth())/2,
	y = 0
}

-- create simple tween animation
local anim = ag.tween{
	subject = logo_pos,
	target = {
		y = (love.graphics.getHeight()-logo:getHeight())/2
	},
	duration = 1, 
	easing = 'outBounce'
}

-- don't forget update in love.update
function love.update(dt)
	anim:update(dt)
end

-- draw
function love.draw()
	love.graphics.draw(logo, logo_pos.x, logo_pos.y)
end

```

# Tween parameters
`subject`,  `target` and `duration` has same meaning in tween.lua's `tween.new ` function. However,  you have to passing these parameters in table.
 * `duration` is optional (default to 1). 
 * `target` can be replaced to `offset`, this is a relative offset to subject, below code shows an animation that down to 100 pixels:
```lua
local anim = ag.tween {
  subject = values,
  offset = {y = 100}
}
```

# Lazy Tween animation
Lazy tween animation is that tween's internal interpolated values are calculated when animation is run instead of the animation being created, this is useful when creating consecutive animation.

```lua
local anim = ag.sequence{
	ag.lazy_tween{
		subject = values,
		offset = { y = 100}
	},
	ag.lazy_tween{
		subject = values,
		offset = { y = 100}
	}
}
```

If you use normal tween animation, as its interpolated values is calculated when being created, you will see animation down 100 pixel and then back to original position and then down 100 pixels. If you use lazy tween, then animation is down 100 pixels twice, and don't back when first animation is done.

# Sequential animation group

The two animations will run sequentially
```lua
local anim = ag.sequence{
	ag.tween{...}, 
	ag.tween{...}
}
```

# Parallel animation group
The two animations will run parallel
```lua
local anim = ag.parallel{
	ag.tween{...}, 
	ag.tween{...}
}
```

# Insert pause
```lua
local anim = ag.sequence{
	ag.tween{...}, 
	ag.delay(2), -- delay 2 seconds
	ag.tween{...}
}
```

# Insert function call
```lua
local anim = ag.sequence{
	ag.tween{...}, 
	 -- this will call after first animation is done
	ag.func(function() ... end), 
	ag.tween{...}
}
```

# Repeat animation for specific times
```lua
local anim = ag.loop{
	times = 2,
	action = { ... } 
}
```
