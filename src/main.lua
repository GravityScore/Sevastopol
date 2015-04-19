
local current_level = 1
local levels = {
	require("maps/one"),
	require("maps/two"),
	require("maps/three"),
	require("maps/four"),
}

local current_inbetween = 1
local inbetween = {
	{
		"WARNING: GUIDANCE CONTROL SYSTEM FAILURE",
		"WARNING: ANOMALOUS LIFEFORMS DETECTED",
		"DISPERSION AIRLOCK: Located in the north wing, accessible from main control tower.",
		"INVENTORY: 1x pen knife\n\nTRAVERSAL ROUTE: The Nest.",
		"SRG MESSAGE:\n\nThis is it...",
		"This is our last hope.",
	},
	{
		"WARNING: APPROACHING LARGE CELESTIAL BODY",
		"IMPACT ESTIMATED IN: 2.3145286 HOURS",
	},
	{
		"SRG MESSAGE:\n\nWe're nearing the center of The Nest.",
		"God save us...",
	},
	{
		"SRG MESSAGE:\n\nThe main control tower is just ahead.",
		"It will offer no sanctuary.",
		"",
		"TRAVERSAL ROUTE: Main control tower.",
	},
	{
		"DISPERSION AIRLOCK: Straight ahead.",
		"...",
		"",
		"Thanks for playing! :)\n\nMade by Ben Anderson for Ludum Dare 32",
	},
}

local Player = require("player")
local Camera = require("camera")
local Map = require("map")
local Shake = require("shake")
local RandomAi = require("randomai")
local PathAi = require("pathai")
local Door = require("door")
local Title = require("title")
local Opening = require("opening")

local player
local camera
local map
local shader
local canvas
local time
local atmosphere
local global_shake
local ais
local doors
local rooms
local title
local level
local restart
local ps
local finished
local finished_game = false
local try_again = false

local first_time = true


function love.load()
	if finished_game then
		opening = Opening.new(inbetween[current_inbetween])
		return
	end

	level = levels[current_level]
	player = Player.new()
	camera = Camera.new()
	map = Map.new(level)
	title = Title.new()
	global_shake = Shake.new()
	opening = Opening.new(inbetween[current_inbetween])
	if try_again then
		opening.done = true
	end

	if not first_time then
		title.done = true
	end

	first_time = false
	try_again = false
	finished = false

	for i = 1, 50 do
		global_shake:shake()
	end

	doors = {}
	for _, door in pairs(map.doors) do
		local adoor = Door.new(door.x, door.y, door.dir, door.block)
		table.insert(doors, adoor)
	end

	rooms = {}
	for _, room in pairs(level.layers[2].objects) do
		rooms[tonumber(room.properties.room)] = {
			x = room.x + level.tilewidth,
			y = room.y + level.tileheight,
			w = room.width,
			h = room.height,
		}
	end

	ais = {}
	for i, object in pairs(level.layers[3].objects) do
		if object.properties.type == "random" then
			local ai = RandomAi.new()
			ai.x = object.x
			ai.y = object.y
			table.insert(ais, ai)
		else
			local dir
			if object.properties.orientation == "north" then
				dir = math.pi / 2
			elseif object.properties.orientation == "south" then
				dir = math.pi * 3 / 2
			elseif object.properties.orientation == "east" then
				dir = 0
			elseif object.properties.orientation == "west" then
				dir = math.pi
			end

			local ai = PathAi.new()
			ai.x = object.x
			ai.y = object.y
			ai.orientation = dir
			table.insert(ais, ai)
		end
	end

	ps = {}

	player.x = level.layers[4].objects[1].x + player.frame_size.width / 2
	player.y = level.layers[4].objects[1].y + player.frame_size.height / 2

	time = 0

	atmosphere = love.audio.newSource("sounds/atmosphere.mp3")
	atmosphere:setLooping(true)
	atmosphere:play()
	atmosphere:setVolume(0.9)
	canvas = love.graphics.newCanvas()
	shader = love.graphics.newShader([[

extern number time;

highp float rand(vec2 co) {
    highp float a = 12.9898;
    highp float b = 78.233;
    highp float c = 43758.5453;
    highp float dt= dot(co.xy ,vec2(a,b));
    highp float sn= mod(dt,3.14);
    return fract(sin(sn) * c);
}

// 0 to 1
// extern number noise_intensity = 1.0;

// 0 to 1
// extern number scanline_intensity = 1.0;

// 0 to 4096
// extern number scanline_count = 400;

vec4 effect(vec4 current_color, Image texture, vec2 coord, vec2 screen) {

//	vec4 original = Texel(texture, coord);
//
//	number x = coord.x * coord.y * time * 1000.0;
//	x = mod(x, 13.0) * mod(x, 123.0);
//	number dx = mod(x, 0.01);
//
//	vec3 color = original.rgb + original.rgb *
//		clamp(0.1 + dx * 100.0, 0.0, 1.0);
//	vec2 scan = vec2(sin(coord.y * scanline_count),
//		cos(coord.y * scanline_count));
//	color += original.rgb * vec3(scan.x, scan.y, scan.x) * scanline_intensity;
//	color = original.rgb + clamp(noise_intensity, 0.0, 1.0) *
//		(color - original.rgb);
//	return vec4(color, original.a);


	vec2 offset = vec2(
		rand(screen + time) / 1500,
		rand(screen - time) / 1500);

	vec2 q = coord;
	vec2 uv = 0.5 + (q - 0.5) * (0.96 + 0.02 * sin(0.3 * time));

	vec3 original = Texel(texture, vec2(q.x, 1.0 - q.y) + offset).rgb;
	vec3 color = vec3(
		Texel(texture, vec2(uv.x + 0.001, uv.y)).r,
		Texel(texture, vec2(uv.x + 0.000, uv.y)).g,
		Texel(texture, vec2(uv.x - 0.001, uv.y)).b
	);

	color = clamp(color * 0.5 + 0.5 * color * color * 1.2, 0.0, 1.0);
	color *= 1.0 - 0.07 * rand(vec2(time, tan(time)));
	color *= 0.9 + 0.2 * sin(10.0 * time - screen.y * 800.0);

	if (color.r == color.b && color.b == color.g && color.r == 0) {
		// Black
		float random = rand(screen + time);
		float gray = random / 8.0;
		color = vec3(gray, gray, gray);
	}

	return vec4(color, 1.0);

}

	]])
end


function love.update(dt)
	shader:send("time", time)
	global_shake:shake()
	global_shake:update(dt)

	if finished_game then
		opening:update(dt)
	elseif not title.done then
		title:update(dt)
	elseif not opening.done then
		opening:update(dt)
	elseif restart or finished then
	else
		if #ais == 0 then
			-- Finished level
			finished = true
		end

		for i, s in pairs(ps) do
			if s.time <= 0 then
				table.remove(ps, i)
			else
				s.ps:update(dt)
				s.time = s.time - dt
			end
		end

		player:update(dt, camera, map)

		local players = {}
		for _, ai in pairs(ais) do
			table.insert(players, ai)
			ai:update(dt, map, camera, player, rooms)
		end

		if player.health <= 0 then
			restart = true
		end

		table.insert(players, player)
		for _, door in pairs(doors) do
			door:update(dt, players, map)
		end
	end

	time = time + dt
end


function love.draw()
	love.graphics.setCanvas(canvas)
	global_shake:before_draw()

	love.graphics.setBackgroundColor(0, 0, 0)
	love.graphics.clear()

	if finished_game then
		opening:draw()
	elseif not title.done then
		-- Title scene
		title:draw()
	elseif not opening.done then
		opening:draw()
	else
		for _, s in pairs(ps) do
			local x, y = s.x - camera.x + camera.width,
				s.y - camera.y + camera.height
			love.graphics.draw(s.ps, x, y)
		end

		-- Game scene
		map:draw(camera)
		player:draw(camera)

		for _, ai in pairs(ais) do
			ai:draw(camera, map, player)
		end

		for _, door in pairs(doors) do
			door:draw(camera, map)
		end

		if restart then
			love.graphics.setColor(255, 255, 255)
			love.graphics.rectangle("fill", camera.width / 2 - 500 / 2,
				camera.height / 2 - 150 / 2, 500, 150)
			love.graphics.setColor(0, 0, 0)
			love.graphics.printf("Fatal wound sustained.\nPress `r` to try again.",
				camera.width / 2 - 400 / 2, camera.height / 2 - 40, 400, "center")
		elseif finished then
			love.graphics.setColor(255, 255, 255)
			love.graphics.rectangle("fill", camera.width / 2 - 500 / 2,
				camera.height / 2 - 150 / 2, 500, 150)
			love.graphics.setColor(0, 0, 0)
			love.graphics.printf("Sector cleared.\nPress `enter` to continue.",
				camera.width / 2 - 400 / 2, camera.height / 2 - 40, 400, "center")
		end
	end

	global_shake:after_draw()
	love.graphics.setCanvas()

	-- Render canvas
	love.graphics.setShader(shader)
	love.graphics.draw(canvas)
	love.graphics.setShader()
end


function love.mousepressed()
	if title.done and opening.done and not restart and not finished and not finished_game then
		player:attack(map, ais, ps, camera)
	end
end


function love.keypressed(key)
	if key == "r" and restart then
		restart = false
		try_again = true
		love.load()
	elseif key == "return" and finished then
		finished = false
		current_level = current_level + 1
		current_inbetween = current_inbetween + 1
		if current_level > #levels then
			-- Finished game
			finished_game = true
			love.load()
		else
			love.load()
		end
	elseif key == "escape" then
		love.event.quit()
	end
end
