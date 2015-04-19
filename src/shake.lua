
local Shake = {}
Shake.__index = Shake


function Shake.new()
	local self = setmetatable({}, Shake)

	self.growth = 1
	self.amplitude = 1
	self.frequency = 1
	self.amount = 1
	self.time = 0

	return self
end


function Shake:reset()
	self.amount = 1
	self.time = 0
end


function Shake:update(dt)
	self.amount = math.max(1, self.amount ^ 0.8)
	self.time = self.time + dt
end


function Shake:shake()
	self.amount = self.amount + self.growth
end


function Shake:before_draw()
	local scale = math.abs(math.random() - 0.5) + 0.5

	local factor = self.amplitude * math.log(self.amount)
	local x = math.sin(self.time * self.frequency * scale)
	local y = math.cos(self.time * self.frequency * scale)

	love.graphics.push()
	love.graphics.translate(factor * x, factor * y)
end


function Shake:after_draw()
	love.graphics.pop()
end


return Shake
