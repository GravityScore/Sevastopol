
local Door = {}
Door.__index = Door


function Door.new(x, y, dir, id)
	local self = setmetatable({}, Door)

	self.x = x
	self.y = y
	self.ox = x
	self.oy = y
	self.dir = dir
	self.id = id

	return self
end


function Door:update(dt, players, map)
	local maxdis = 2 * map.tw + map.tw

	local closest = maxdis + 1
	for _, player in pairs(players) do
		local pdis = math.sqrt((player.x - self.ox) ^ 2 + (player.y -
			self.oy) ^ 2)
		if pdis < closest then
			closest = pdis
		end
	end

	if closest < maxdis then
		if self.dir == "left" then
			self.x = self.ox - (maxdis - closest)
		elseif self.dir == "right" then
			self.x = self.ox + (maxdis - closest)
		elseif self.dir == "up" then
			self.y = self.oy - (maxdis - closest)
		elseif self.dir == "down" then
			self.y = self.oy + (maxdis - closest)
		end
	else
		self.x = self.ox
		self.y = self.oy
	end
end


function Door:draw(camera, map)
	local screen_x = self.x - camera.x + camera.width / 2
	local screen_y = self.y - camera.y + camera.height / 2

	local source_x = (self.id % map.tpl) *
		map.tw
	local source_y = ((self.id - (self.id % map.tpl)) /
		map.tpl) * map.th

	local quad = love.graphics.newQuad(source_x, source_y,
		map.tw, map.th,
		map.tileset:getWidth(), map.tileset:getHeight())

	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(map.tileset, quad, math.floor(screen_x),
		math.floor(screen_y), 0, 1, 1, map.tw / 2,
		map.th / 2)
end


return Door
