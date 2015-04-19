
local Title = {}
Title.__index = Title


Title.fade_duration = 8
Title.wait_duration = 3


function Title.new()
	local self = setmetatable({}, Title)

	self.done = false
	self.title_img = love.graphics.newImage("images/title.png")

	self.fade = 0
	self.fade_timer = 0

	return self
end


function Title:update(dt)
	if self.fade_timer > Title.fade_duration + Title.wait_duration then
		self.done = true
		return
	end

	if self.fade_timer > Title.fade_duration then
		self.fade = 0
	else
		self.fade = 255 * (1 - self.fade_timer / Title.fade_duration)
	end

	self.fade_timer = self.fade_timer + dt
end


function Title:draw()
	local w = love.window.getWidth()
	local h = love.window.getHeight()
	local x = w / 2 - self.title_img:getWidth() / 2
	local y = h / 2 - self.title_img:getHeight() / 2

	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.draw(self.title_img, x, y)

	love.graphics.setColor(0, 0, 0, self.fade)
	love.graphics.rectangle("fill", 0, 0, w, h)
end


return Title
