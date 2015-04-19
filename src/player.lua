
local Player = {}
Player.__index = Player


Player.walk_timer_start = 0.08
Player.walk_speed = 8

Player.weapon_animation_speed = 0.00001
Player.click_sound = nil


function Player.new()
	local self = setmetatable({}, Player)

	self.x = 0
	self.y = 0
	self.walk_timer = 0
	self.is_walking = false
	self.orientation = 0

	self.image = love.graphics.newImage("images/player.png")
	self.weapon_image = love.graphics.newImage("images/attack.png")
	self.image:setFilter("nearest", "nearest")
	self.frame_size = {width = 95, height = 35}
	self.state = 0

	self.weapon_diff = self.weapon_image:getHeight() - self.image:getHeight()

	self.weapon_state = -1
	self.weapon_timer = 0

	self.prevx = nil
	self.prevy = nil

	self.health = 100

	if not Player.click_sound then
		Player.click_sound = love.audio.newSource("sounds/hit.wav")
		Player.click_sound:setVolume(0.2)
	end

	return self
end


function Player:rect(x, y)
	local size = math.min(self.frame_size.width, self.frame_size.height)
	return x, y, size, size
end


function Player:resolve(px, py, map, bx, by)
	local ox = px
	local oy = py

	local bx, by, bw, bh = map:block_rect(bx, by)
	local px, py, pw, ph = self:rect(px, py)

	if px - pw / 2 > bx + bw / 2 or
			px + pw / 2 < bx - bw / 2 or
			py - ph / 2 > by + bh / 2 or
			py + ph / 2 < by - bh / 2 then
		return ox, oy
	end

	if math.abs(px - bx) > math.abs(py - by) then
		if px < bx then
			px = bx - bw / 2 - pw / 2 - 1
		else
			px = bx + bw / 2 + pw / 2 + 1
		end
	else
		if py < by then
			py = by - bh / 2 - ph / 2 - 1
		else
			py = by + bh / 2 + ph / 2 + 1
		end
	end

	return px, py
end


function Player:resolve_collisions(map, new_x, new_y)
	for x = 1, map.width do
		for y = 1, map.height do
			local block = map.map[y][x]
			if block ~= 0 then
				new_x, new_y = self:resolve(new_x, new_y, map, x, y)
			end
		end
	end

	return new_x, new_y
end


function Player:check_point(map, x, y)
	x = math.floor(x / map.tw)
	y = math.floor(y / map.th)
	return not map.map[y] or map.map[y][x] ~= 0
end


function Player:cast_ray(map, x, y, orientation)
	local step_size = math.min(map.tw, map.th) / 8

	local sx = x
	local sy = y
	local steps = 0

	while not self:check_point(map, sx, sy) do
		sx = sx + math.cos(orientation) * step_size
		sy = sy + math.sin(orientation) * step_size
		love.graphics.setColor(255, 0, 0)
		love.graphics.rectangle('fill', sx * map.tw, sy * map.th, 10, 10)
		steps = steps + 1
	end

	return steps
end


function Player:update(dt, camera, map)
	-- Update the player's orientation
	self.orientation = math.atan2(love.mouse.getY() - self:screen_y(camera),
		love.mouse.getX() - self:screen_x(camera)) + math.pi / 2

	-- Update the player's state if they're walking
	if self.is_walking then
		-- Oscillate between states 1 and 2
		if self.state == 0 then
			-- Just starting to walk
			self.state = 1
			self.walk_timer = Player.walk_timer_start
		elseif self.state == 1 and self.walk_timer <= 0 then
			self.state = 2
			self.walk_timer = Player.walk_timer_start
		elseif self.state == 2 and self.walk_timer <= 0 then
			self.state = 1
			self.walk_timer = Player.walk_timer_start
		else
			-- Leave a gap between changing walk states
			self.walk_timer = self.walk_timer - dt
		end
	else
		-- Not walking
		self.state = 0
	end

	local forward = love.keyboard.isDown("w")
	local back = love.keyboard.isDown("s")
	local left = love.keyboard.isDown("a")
	local right = love.keyboard.isDown("d")

	local new_x = self.x
	local new_y = self.y

	if forward then
		new_y = self.y - Player.walk_speed
	end
	if back then
		new_y = self.y + Player.walk_speed
	end
	if left then
		new_x = self.x - Player.walk_speed
	end
	if right then
		new_x = self.x + Player.walk_speed
	end

	new_x, new_y = self:resolve_collisions(map, new_x, new_y)
	self.is_walking = false
	if new_x ~= self.x then
		self.x = new_x
		self.is_walking = true
	end

	if new_y ~= self.y then
		self.y = new_y
		self.is_walking = true
	end

	-- Update camera tracking
	-- In the player code??? Really??? Maybe create a camera:focus(x, y)
	-- function???
	if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
		if self.prevx == nil or self.prevy == nil then
			self.prevx = love.mouse.getX()
			self.prevy = love.mouse.getY()
		else
			local x, y = love.mouse.getX(), love.mouse.getY()
			local distance = math.sqrt((y - self.prevy) ^ 2 + (x - self.prevx) ^ 2)
			local direction = math.atan2(y - self.prevy, x - self.prevx)

			local xoffset = math.cos(direction) * distance
			local yoffset = math.sin(direction) * distance

			camera.x = self.x + xoffset
			camera.y = self.y + yoffset
		end
	else
		camera.x = self.x
		camera.y = self.y

		self.prevx = nil
		self.prevy = nil
	end

	-- Update weapon
	if self.weapon_state ~= -1 then
		if self.weapon_timer <= 0 then
			self.weapon_timer = Player.weapon_animation_speed
			self.weapon_state = self.weapon_state - 1
		else
			self.weapon_timer = self.weapon_timer - dt
		end
	end
end


function Player:intersect(x, y, w, h, ax, ay, aw, ah)
	return not (x - w / 2 > ax + aw / 2 or x + w / 2 < ax - aw / 2 or
		y - h / 2 > ay + ah / 2 or y + h / 2 < ay - ah / 2)
end


function Player:attack(map, ais, pss, camera)
	Player.click_sound:play()

	self.weapon_state = 4
	self.weapon_timer = Player.weapon_animation_speed

	-- local step = self:cast_ray(map, self.x, self.y, self.orientation)

	local toremove = {}
	local max = math.max(self.frame_size.width, self.frame_size.height) / 1.5
	for i, ai in pairs(ais) do
		local aimax = math.max(ai.framew, ai.frameh)
		if self:intersect(self.x, self.y, max, max, ai.x, ai.y, aimax, aimax) then
			table.insert(toremove, i)

			local canvas = love.graphics.newCanvas()
			love.graphics.setCanvas(canvas)
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.rectangle("fill", 0, 0, 10, 10)
			love.graphics.setCanvas()

			local img = love.graphics.newImage(canvas:getImageData())

			local ps = love.graphics.newParticleSystem(img, 32)
			-- local x, y = ai.x, ai.y
			-- ps:setPosition(x, y)
			ps:setParticleLifetime(0.5, 2)
			ps:setEmissionRate(20)
			ps:setColors(255, 255, 255, 255, 255, 255, 255, 0)
			ps:setLinearAcceleration(-200, -200, 200, 200)
			table.insert(pss, {ps = ps, x = ai.x, y = ai.y, w = ai.framew,
				h = ai.frameh, time = 2})
		end
	end

	for _, i in pairs(toremove) do
		table.remove(ais, i)
	end
end


function Player:inRoom(room)
	local size = math.min(self.frame_size.width, self.frame_size.height)
	return self:intersect(room.x + room.w / 2, room.y + room.h / 2, room.w, room.h,
		self.x, self.y, size, size)
end


function Player:screen_x(camera)
	return self.x - camera.x + camera.width / 2
end


function Player:screen_y(camera)
	return self.y - camera.y + camera.height / 2
end


function Player:draw(camera)
	if self.weapon_state == -1 then
		local frame_x = self.state * self.frame_size.width
		local frame_y = 0
		local quad = love.graphics.newQuad(frame_x, frame_y, self.frame_size.width,
			self.frame_size.height, self.image:getWidth(), self.image:getHeight())

		love.graphics.draw(self.image, quad, self:screen_x(camera),
			self:screen_y(camera), self.orientation, 1, 1,
			self.frame_size.width / 2, self.frame_size.height / 2)
	else
		local frame_x = self.weapon_state * self.frame_size.width
		local frame_y = 0
		local quad = love.graphics.newQuad(frame_x, frame_y, self.frame_size.width,
			self.frame_size.height + self.weapon_diff, self.weapon_image:getWidth(),
			self.weapon_image:getHeight())

		local x = self:screen_x(camera) - math.cos(self.orientation + math.pi / 2) *
			self.weapon_diff / 2
		local y = self:screen_y(camera) - math.sin(self.orientation + math.pi / 2) *
			self.weapon_diff / 2

		love.graphics.draw(self.weapon_image, quad, x, y, self.orientation,
			1, 1, self.frame_size.width / 2,
			(self.frame_size.height + self.weapon_diff) / 2)
	end
end


return Player
