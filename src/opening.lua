
local Opening = {}
Opening.__index = Opening

Opening.character_delay = 0.04
Opening.texts_delay = 2
Opening.last_delay = 2


function Opening.new(texts)
	local self = setmetatable({}, Opening)

	self.ch_timer = 0
	self.text_timer = nil
	self.text_index = 1
	self.char_index = 1
	self.last_timer = 0
	self.done = false
	self.final = false
	self.texts = texts

	self.font = love.graphics.newFont(
		"fonts/font.ttf", 24)
	love.graphics.setFont(self.font)

	return self
end


function Opening:update(dt)
	if self.final then
		if self.last_timer > Opening.last_delay then
			self.done = true
		else
			self.last_timer = self.last_timer + dt
		end
	elseif self.text_timer and self.text_timer <= 0 then
		self.text_index = self.text_index + 1

		if self.text_index > #self.texts then
			self.text_index = self.text_index - 1
			self.final = true
			return
		end

		self.char_index = 1
		self.char_timer = 0
		self.text_timer = nil
	elseif self.text_timer and self.text_timer > 0 then
		self.text_timer = self.text_timer - dt
	elseif self.ch_timer > Opening.character_delay then
		self.ch_timer = 0
		self.char_index = self.char_index + 1

		if self.char_index > #self.texts[self.text_index] then
			self.text_timer = Opening.texts_delay
		end
	else
		self.ch_timer = self.ch_timer + dt
	end
end


function Opening:draw()
	local text = self.texts[self.text_index]:sub(1, self.char_index)
	local w = love.window.getWidth()
	local h = love.window.getHeight()
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.printf(text, w / 2 - 400 / 2, h / 2 - 100, 400, "center")
end


return Opening
