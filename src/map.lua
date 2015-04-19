
local Map = {}
Map.__index = Map


function Map.new(level)
	local self = setmetatable({}, Map)

	self.map = {}

	self.tileset = love.graphics.newImage("images/tileset.png")
	self.tileset:setFilter("nearest", "nearest")

	self.tw = 24
	self.th = 24
	self.tpl = self.tileset:getWidth() / self.tw

	self.doors = {}

	self.width = level.width
	self.height = level.height

	for y = 1, level.height do
		local values = {}
		for x = 1, level.width do
			local rx, ry = self:block_rect(x, y)
			value = level.layers[1].data[(y - 1) * level.width + x]

			if value == 9 then
				-- Left door
				table.insert(self.doors, {
					x = rx,
					y = ry,
					dir = "left",
					block = 8,
				})

				table.insert(values, 0)
			elseif value == 10 then
				-- Right door
				table.insert(self.doors, {
					x = rx,
					y = ry,
					dir = "right",
					block = 9,
				})

				table.insert(values, 0)
			elseif value == 25 then
				-- Up door
				table.insert(self.doors, {
					x = rx,
					y = ry,
					dir = "up",
					block = 24,
				})

				table.insert(values, 0)
			elseif value == 26 then
				-- Down door
				table.insert(self.doors, {
					x = rx,
					y = ry,
					dir = "down",
					block = 25,
				})

				table.insert(values, 0)
			else
				table.insert(values, value)
			end
		end

		table.insert(self.map, values)
	end

	return self
end


function Map:block_rect(x, y)
	return (x + 0.5) * self.tw, (y + 0.5) * self.th, self.tw, self.th
end


function Map:draw_block(camera, block, x, y)
	local screen_x = x * self.tw - camera.x +
		love.window.getWidth() / 2
	local screen_y = y * self.th - camera.y +
		love.window.getHeight() / 2

	local source_x = ((block - 1) % self.tpl) * self.tw
	local source_y = (((block - 1) - ((block - 1) % self.tpl)) /
		self.tpl) * self.th

	local quad = love.graphics.newQuad(source_x, source_y,
		self.tw, self.th,
		self.tileset:getWidth(), self.tileset:getHeight())

	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(self.tileset, quad, math.floor(screen_x),
		math.floor(screen_y))
end


function Map:draw(camera)
	for x = 1, self.width do
		for y = 1, self.height do
			local block = self.map[y][x]
			if block ~= 0 then
				self:draw_block(camera, block, x, y)
			end
		end
	end
end


return Map
