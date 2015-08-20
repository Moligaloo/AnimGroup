# AnimGroup
An animation library for löve game engine, depends on [tween.lua](https://github.com/kikito/tween.lua)
You can make animation groups, including sequential and parallel animation groups, 
and insert pause for specified seconds and function call inside animation group, or loop animation for specific times.

# Usage
Just drop [anim_group.lua](https://github.com/Moligaloo/AnimGroup/blob/master/anim_group.lua) to your Löve project and then require it.

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
`duration`, `subject`,`target` and `easing` has same meaning in tween.lua's `tween.new`  function. However,  you have to pass these parameters in a table. Additionally, this library provide some extras:
 * `duration` is optional (default to 1). 
 * Optional parameter `from`: if this parameter is given, `subject` will set fields from `from` before calculating interpolated values. It is useful when run repeated animation.
 * `target` can be replaced to `offset`, this is a relative offset to subject, below code shows an animation that down to 100 pixels:
```lua
local anim = ag.tween {
  subject = values,
  offset = {y = 100}
}
```

NOTE: Tween animation's internal interpolated values are calculated when run instead of being created.

# Sequential animation group

The two animations will group into one and run sequentially
```lua
local anim = ag.sequence{
	ag.tween{...}, 
	ag.tween{...}
}

-- more fancy way, use '+' operator
local anim = ag.tween{...} + ag.tween{...}

```

# Parallel animation group
The two animations will group into one and run parallel
```lua
local anim = ag.parallel{
	ag.tween{...}, 
	ag.tween{...}
}

-- more fancy way, use '/' operator
local anim = ag.tween{...} / ag.tween{...}
```

# Insert a pause for a specified duration
```lua
local anim = 
	ag.tween{...} + 
	ag.delay(2) + -- delay 2 seconds
	ag.tween{...}
```

# Insert function call
```lua
local anim = 
	ag.tween{...} +
	 -- this will call after first animation is done
	ag.func(function() ... end) +
	ag.tween{...}
```

# Repeat animation for specific times
```lua
local anim = ag.loop{
	times = 2,
	action = ag.tween{...}
}

-- more fancy way, use '*' operator
local anim = ag.tween{...} * 2
```

# Demo
Download this project and run by love executable and you will run the demo.