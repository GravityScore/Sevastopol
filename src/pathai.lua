
local PathAi = {}
PathAi.__index = PathAi


PathAi.wait_min = 0.8
PathAi.wait_max = 3.0
PathAi.walk_min = 0.2
PathAi.walk_max = 0.8
PathAi.lazy_walk_speed = 2.0
PathAi.walk_speed = 7.0
PathAi.image = nil
PathAi.destruction_time = 1


PathAi.walk_animation_speed = 0.08
PathAi.frame_width = 0
PathAi.frame_height = 0


function PathAi.new()
	local self = setmetatable({}, PathAi)

	self.walk_timer = 0
	self.is_walking = false
	self.walk_state = 0

	self.x = 0
	self.y = 0
	self.orientation = 0
	self.timer = 0
	self.state = "walk"
	self.has_seen = false

	if not PathAi.image then
		PathAi.image = love.graphics.newImage("images/ai.png")
		PathAi.frame_width = PathAi.image:getWidth() / 3
		PathAi.frame_height = PathAi.image:getHeight()
	end

	local min = PathAi.frame_height * 10
	local max = PathAi.frame_height * 13
	self.activation_distance = math.random() * (max - min) + min

	self.framew = PathAi.frame_width
	self.frameh = PathAi.frame_height
	self.before = false

	return self
end


function PathAi:check_point(map, x, y)
	x = math.floor(x / map.tw)
	y = math.floor(y / map.th)
	return not map.map[y] or map.map[y][x] ~= 0
end


function PathAi:cast_ray(map, x, y, orientation)
	local step_size = math.min(map.tw,
		map.th) / 2

	local sx = x
	local sy = y
	local steps = 0

	while not self:check_point(map, sx, sy) do
		sx = sx + math.cos(orientation) * step_size
		sy = sy + math.sin(orientation) * step_size
		steps = steps + 1
	end

	return steps
end


function PathAi:check_orientation(map)
	local n = self:cast_ray(map, self.x, self.y, math.pi / 2)
	local s = self:cast_ray(map, self.x, self.y, math.pi * 3 / 2)
	local e = self:cast_ray(map, self.x, self.y, 0)
	local w = self:cast_ray(map, self.x, self.y, math.pi)

	local amount = 3
	if math.abs(self.orientation - math.pi / 2) < 0.01 and n <= amount then
		if e > w then
			-- Face east
			self.orientation = 0
		else
			-- Face west
			self.orientation = math.pi
		end
	elseif math.abs(self.orientation) < 0.01 and e <= amount then
		if n > s then
			-- Face north
			self.orientation = math.pi / 2
		else
			-- Face south
			self.orientation = math.pi * 3 / 2
		end
	elseif math.abs(self.orientation - math.pi * 3 / 2) < 0.01 and s <= amount then
		if e > w then
			-- Face east
			self.orientation = 0
		else
			-- Face west
			self.orientation = math.pi
		end
	elseif math.abs(self.orientation - math.pi) < 0.01 and w <= amount then
		if n > s then
			-- Face north
			self.orientation = math.pi / 2
		else
			-- Face south
			self.orientation = math.pi * 3 / 2
		end
	end
end


function PathAi:path_to(map, x, y, dx, dy)
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


function PathAi:attack(player)
	player.health = player.health - 100
end


function PathAi:intersect(x, y, w, h, ax, ay, aw, ah)
	return not (x - w / 2 > ax + aw / 2 or x + w / 2 < ax - aw / 2 or
		y - h / 2 > ay + ah / 2 or y + h / 2 < ay - ah / 2)
end


function PathAi:getRoom(rooms)
	for _, room in pairs(rooms) do
		if self:intersect(room.x + room.w / 2, room.y + room.h / 2, room.w, room.h,
				self.x, self.y, self.framew, self.frameh) then
			return room
		end
	end

	return nil
end


function PathAi:update(dt, map, camera, player, rooms)
	local mindis = math.max(player.frame_size.width, player.frame_size.height) / 2
	local playerdis = math.sqrt((player.x - self.x) ^ 2 + (player.y - self.y) ^ 2)
	local a = true

	if playerdis <= mindis and self.has_seen then
		self.orientation = math.atan2(player.y - self.y, player.x - self.x)
		self.before = true
		a = false

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
			self.x = self.x + math.cos(dir) * PathAi.walk_speed
			self.y = self.y + math.sin(dir) * PathAi.walk_speed
			self.orientation = math.atan2(player.y - self.y, player.x - self.x)
			self.before = true
		end
	elseif self:getRoom(rooms) and player:inRoom(self:getRoom(rooms)) then
		self.has_seen = true
	end

	if a then
		if self.before then
			self.before = false
			self.orientation = math.floor(self.orientation / (math.pi * 2)) *
				(math.pi / 2)
			self.has_seen = false
		end

		self.x = self.x + math.cos(self.orientation) * PathAi.lazy_walk_speed
		self.y = self.y + math.sin(self.orientation) * PathAi.lazy_walk_speed
		self:check_orientation(map)
		self.is_walking = true

		if self.is_walking then
			if self.walk_timer <= 0 then
				self.walk_timer = PathAi.walk_animation_speed

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


function PathAi:screen(camera)
	return self.x - camera.x + camera.width / 2, self.y - camera.y +
		camera.height / 2
end


function PathAi:draw(camera, map, player)
	local frame_x = self.walk_state * PathAi.frame_width
	local frame_y = 0
	local quad = love.graphics.newQuad(frame_x, frame_y, PathAi.frame_width,
		PathAi.frame_height, PathAi.image:getWidth(),
		PathAi.image:getHeight())

	local x, y = self:screen(camera)
	love.graphics.draw(PathAi.image, quad, x, y,
		self.orientation + math.pi / 2, 1, 1,
		PathAi.frame_width / 2, PathAi.frame_height / 2)
end


return PathAi
