
local RandomAi = {}
RandomAi.__index = RandomAi


RandomAi.wait_min = 0.5
RandomAi.wait_max = 2.4
RandomAi.walk_min = 0.5
RandomAi.walk_max = 1.2
RandomAi.lazy_walk_speed = 2.0
RandomAi.walk_speed = 7.0
RandomAi.image = nil


RandomAi.walk_animation_speed = 0.08
RandomAi.frame_width = 0
RandomAi.frame_height = 0


RandomAi.destruction_time = 1



function RandomAi.new()
	local self = setmetatable({}, RandomAi)

	self.walk_timer = 0
	self.is_walking = false
	self.walk_state = 0

	self.x = 0
	self.y = 0
	self.orientation = math.random() * math.pi * 2
	self.timer = 0
	self.state = "walk"
	self.see_player = false

	if not RandomAi.image then
		RandomAi.image = love.graphics.newImage("images/ai.png")
		RandomAi.frame_width = RandomAi.image:getWidth() / 3
		RandomAi.frame_height = RandomAi.image:getHeight()
	end

	local min = RandomAi.frame_height * 10
	local max = RandomAi.frame_height * 13
	self.activation_distance = math.random() * (max - min) + min

	self.framew = RandomAi.frame_width
	self.frameh = RandomAi.frame_height
	self.before = false

	return self
end


function RandomAi:rect(px, py)
	local size = math.min(RandomAi.frame_width, RandomAi.frame_height)
	return px, py, size, size
end


function RandomAi:resolve(map, px, py, bx, by)
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


function RandomAi:resolve_collisions(map, px, py)
	local flag = false
	for x = 1, map.width do
		for y = 1, map.height do
			local block = map.map[y][x]
			if block ~= 0 then
				px, py = self:resolve(map, px, py, x, y)
			end
		end
	end

	return px, py, flag
end


function RandomAi:attack(player)
	player.health = player.health - 100
end


function RandomAi:intersect(x, y, w, h, ax, ay, aw, ah)
	return not (x - w / 2 > ax + aw / 2 or x + w / 2 < ax - aw / 2 or
		y - h / 2 > ay + ah / 2 or y + h / 2 < ay - ah / 2)
end


function RandomAi:getRoom(rooms)
	for _, room in pairs(rooms) do
		if self:intersect(room.x + room.w / 2, room.y + room.h / 2, room.w, room.h,
				self.x, self.y, self.framew, self.frameh) then
			return room
		end
	end

	return nil
end


function RandomAi:path_to(map, x, y, dx, dy)
	if x == dx and y == dy then
		return {{x=x, y=y}}
	end

	local queue = {}
	local checked = {x .. ":" .. y}
	local maxDist = 15

	table.insert(queue, {trace={}, x=x + 1, y=y})
	table.insert(queue, {trace={}, x=x - 1, y=y})
	table.insert(queue, {trace={}, x=x, y=y + 1})
	table.insert(queue, {trace={}, x=x, y=y - 1})

	local i = 1
	while true do
		if i >= #queue then
			break
		end

		local item = queue[i]
		local xWithinRange = math.abs(item.x - dx) <= maxDist
		local yWithinRange = math.abs(item.y - dy) <= maxDist
		if not checked[item.x .. ":" .. item.y] and xWithinRange and yWithinRange then
			checked[item.x .. ":" .. item.y] = true

			local newTrace = {}
			for k, v in pairs(item.trace) do
				newTrace[k] = v
			end

			table.insert(newTrace, {x = item.x, y = item.y})

			if item.x == dx and item.y == dy then
				return item.trace
			end

			if map.map[item.y] and map.map[item.y][item.x] == 0 then
				-- Can go through
				table.insert(queue, {trace=newTrace, x=item.x + 1, y=item.y})
				table.insert(queue, {trace=newTrace, x=item.x - 1, y=item.y})
				table.insert(queue, {trace=newTrace, x=item.x, y=item.y + 1})
				table.insert(queue, {trace=newTrace, x=item.x, y=item.y - 1})
				table.insert(queue, {trace=newTrace, x=item.x - 1, y=item.y + 1})
				table.insert(queue, {trace=newTrace, x=item.x - 1, y=item.y - 1})
				table.insert(queue, {trace=newTrace, x=item.x + 1, y=item.y + 1})
				table.insert(queue, {trace=newTrace, x=item.x + 1, y=item.y - 1})
			end
		end

		i = i + 1
	end

	return {}
end


function RandomAi:update(dt, map, camera, player, rooms)
	local mindis = math.max(player.frame_size.width, player.frame_size.height) / 2.5
	local playerdis = math.sqrt((player.x - self.x) ^ 2 + (player.y - self.y) ^ 2)
	local a = true

	if playerdis <= mindis and self.has_seen then
		self.timer = 0
		self.orientation = math.atan2(player.y - self.y, player.x - self.x)
		self.before = true
		a = false

		self.x = player.x
		self.y = player.y
		self:attack(player)
	elseif playerdis < self.activation_distance and self.has_seen then
		-- Find route to player
		a = false
		local x = math.floor(self.x / map.tw)
		local y = math.floor(self.y / map.th)
		local dx = math.floor(player.x / map.tw)
		local dy = math.floor(player.y / map.th)

		local closest = self:path_to(map, x, y, dx, dy)

		if #closest <= 1 then
			a = true
		else
			-- Move along route
			local waypoint = closest[2]
			local ax = waypoint.x * map.tw
			local ay = waypoint.y * map.th

			local dir = math.atan2(ay - self.y, ax - self.x)
			self.x = self.x + math.cos(dir) * RandomAi.walk_speed
			self.y = self.y + math.sin(dir) * RandomAi.walk_speed
			self.orientation = math.atan2(player.y - self.y, player.x - self.x)
			self.before = true
		end
	elseif self:getRoom(rooms) and player:inRoom(self:getRoom(rooms)) then
		self.has_seen = true
	end

	if a then
		self.is_walking = false

		if self.timer <= 0 then
			-- Change state
			if self.state == "walk" then
				self.state = "wait"
			else
				self.state = "walk"
			end

			-- Update timer
			if self.state == "walk" then
				self.orientation = math.random() * math.pi * 2
				self.timer = math.random() * (RandomAi.walk_max -
					RandomAi.walk_min) + RandomAi.walk_min
			else
				self.timer = math.random() * (RandomAi.wait_max -
					RandomAi.wait_min) + RandomAi.wait_min
			end
		elseif not self.see_player then
			self.timer = self.timer - dt

			if self.state == "walk" then
				local new_x = self.x + math.cos(self.orientation) *
					RandomAi.lazy_walk_speed
				local new_y = self.y + math.sin(self.orientation) *
					RandomAi.lazy_walk_speed
				self.x, self.y = self:resolve_collisions(map, new_x, new_y)

				self.is_walking = true
			end
		end

		if self.is_walking then
			if self.walk_timer <= 0 then
				self.walk_timer = RandomAi.walk_animation_speed

				if self.walk_state == 0 then
					self.walk_state = 1
				elseif self.walk_state == 1 then
					self.walk_state = 2
				elseif self.walk_state == 2 then
					self.walk_state = 1
				end
			else
				self.walk_timer = self.walk_timer - dt
			end
		else
			self.walk_state = 0
		end
	end
end


function RandomAi:screen(camera)
	return self.x - camera.x + camera.width / 2,
		self.y - camera.y + camera.height / 2
end


function RandomAi:draw(camera, map, player)
	local frame_x = self.walk_state * RandomAi.frame_width
	local frame_y = 0
	local quad = love.graphics.newQuad(frame_x, frame_y, RandomAi.frame_width,
		RandomAi.frame_height, RandomAi.image:getWidth(),
		RandomAi.image:getHeight())

	local x, y = self:screen(camera)
	love.graphics.draw(RandomAi.image, quad, x, y,
		self.orientation + math.pi / 2, 1, 1,
		RandomAi.frame_width / 2, RandomAi.frame_height / 2)
end


return RandomAi
