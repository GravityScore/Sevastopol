
local Camera = {}
Camera.__index = Camera


function Camera.new()
	local self = setmetatable({}, Camera)

	self.x = 0
	self.y = 0
	self.width = love.window.getWidth()
	self.height = love.window.getHeight()

	return self
end


return Camera
