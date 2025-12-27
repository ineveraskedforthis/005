local socket = require("socket")
local ffi = require("ffi")

ffi.cdef[[
typedef struct { 
	int32_t id; 
	float x; 
	float y; 
	uint8_t data_type;
	uint8_t is_you;
	uint8_t additional_data;
	uint8_t event; 
} from_server;
typedef struct { 
	int32_t id;
	int32_t target;
	float x; 
	float y; 
	uint8_t data_type;
	uint8_t padding[3]; 
} to_server;
void* memcpy( void *restrict dest, const void *restrict src, size_t count );
]]

local from_server_size = 4 * 4;
local to_server_size = 5 * 4;


function love.load()
	print("Game started")

	TCP = socket.tcp() 
	
	TCP:settimeout(0)
	TCP:connect("127.0.0.1", 8080)

	print("Connected")

	FIGHTERS = {}
	PROJECTILES = {}

	MY_ID = nil;
	MY_SELECTION = nil
end


function love.update(dt)
	local data, error = TCP:receive(16)

	while data ~= nil do	
		local buf = ffi.new("from_server[1]");
		ffi.C.memcpy(buf, data, from_server_size);

		--print(buf[0].id)
		--print(buf[0].x)
		--print(buf[0].y)
		--print(buf[0].data_type)
		--print("---")
	
		if (buf[0].data_type == 0) then
			local lua_index = tonumber(buf[0].id)
			if (FIGHTERS[lua_index] == nil) then
				FIGHTERS[lua_index] = {
					x = 320 + buf[0].x * 160,
					y = 320 + buf[0].y * 160,
					hp = buf[0].additional_data
				}
			else
				FIGHTERS[lua_index].x = 320 + buf[0].x * 160
				FIGHTERS[lua_index].y = 320 + buf[0].y * 160
				FIGHTERS[lua_index].hp = buf[0].additional_data
			end

		end

		if (buf[0].data_type == 1) then
			local lua_index = tonumber(buf[0].id)
			if PROJECTILES[lua_index] == nil then
				PROJECTILES[lua_index] = {
					x = 320 + buf[0].x * 160,
					y = 320 + buf[0].y * 160
				}
			else
				PROJECTILES[lua_index].x = 320 + buf[0].x * 160
				PROJECTILES[lua_index].y = 320 + buf[0].y * 160
			end
		end
	
		if (buf[0].data_type == 2) then
			if buf[0].is_you > 0 then
				print("I am " .. tostring(buf[0].id));
				MY_ID = buf[0].id
			end
		end

		if (buf[0].data_type == 3) then
			local lua_index = tonumber(buf[0].id)
			if buf[0].event == 1 then
				FIGHTERS[lua_index].cast_progress = 1
			end
			if buf[0].event == 2 then
				FIGHTERS[lua_index].parry_progress = 0.3
			end
			if buf[0].event == 3 then
				FIGHTERS[lua_index].no_damage_timer = 0.3
			end
		end

		data, error = TCP:receive(16)
	end

	for i, val in pairs(FIGHTERS) do

		if val.cast_progress then
			val.cast_progress = math.max(0, val.cast_progress - dt)
		end
		if val.parry_progress then
			val.parry_progress = math.max(0, val.parry_progress - dt)
		end
		if val.no_damage_timer then
			val.no_damage_timer = math.max(0, val.no_damage_timer - dt)
		end
	end
end


function love.draw(dt)
	for i, val in pairs(FIGHTERS) do
		if (val.hp > 0) then
			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.circle("fill", val.x, val.y, 10)
	
			if (i == MY_SELECTION) then
				love.graphics.circle("line", val.x, val.y, 15)
			end

			if val.no_damage_timer and val.no_damage_timer > 0 then
				love.graphics.setColor(1, 1, 0)
				love.graphics.circle("line", val.x, val.y, 10)
			end

			hp_size = 5
	
			for hitpoint = 0, val.hp - 1 do
				love.graphics.setColor(0.6, 0.6, 0.1)
				love.graphics.rectangle("fill", val.x + 15, val.y - 10 + hitpoint * hp_size, hp_size, hp_size) 
			end
			for hitpoint = 0, 4 do
				love.graphics.setColor(0.9, 1.0, 0.3)
				love.graphics.rectangle("line", val.x + 15, val.y - 10 + hitpoint * hp_size, hp_size, hp_size) 
			end
			
			if val.cast_progress and val.cast_progress > 0 then
				love.graphics.rectangle("fill", val.x - 10, val.y + 10, val.cast_progress * 20, 5)
			end

			if val.parry_progress and val.parry_progress > 0 then
				love.graphics.rectangle("fill", val.x - 10, val.y + 20, val.parry_progress / 0.3 * 20, 5)
			end
		end
	end

	love.graphics.setColor(1, 0, 0)

	for i, val in pairs(PROJECTILES) do
		love.graphics.circle("fill", val.x, val.y, 3)
	end

	love.graphics.circle("line", 320, 320, 160)
end


function love.mousepressed(x, y, button)
	if MY_ID == nil then
		return
	end

	local data = ffi.new("to_server[1]")
	data[0].x = (x - 320) / 160
	data[0].y = (y - 320) / 160
	data[0].data_type = 0
	data[0].id = MY_ID
	local buffer = ffi.new("uint8_t[" .. tostring(to_server_size) .. "]")
	ffi.C.memcpy(buffer, data, to_server_size)
	print("send command")
	TCP:send(ffi.string(buffer, to_server_size))
end

function love.keypressed(key, scancode, isrepeat)
	if MY_ID == nil then
		return
	end


	if key == "tab" then
		if MY_SELECTION == nil then
			MY_SELECTION = 0
		end

		local clamp = 0;
		for id, _ in pairs(FIGHTERS) do
			clamp = math.max(clamp, id)
		end
		
		MY_SELECTION = MY_SELECTION + 1
		
		for i = 1, 2 do
			while (FIGHTERS[MY_SELECTION] == nil) and MY_SELECTION <= clamp do
				MY_SELECTION = MY_SELECTION + 1
			end

			if MY_SELECTION == clamp + 1 then
				MY_SELECTION = 0
			end
		end

		if FIGHTERS[MY_SELECTION] == nil then
			MY_SELECTION = nil
		else
			local data = ffi.new("to_server[1]")
			data[0].data_type = 2
			data[0].id = MY_ID
			data[0].target = MY_SELECTION
			local buffer = ffi.new("uint8_t["..tostring(to_server_size).."]")
			ffi.C.memcpy(buffer, data, to_server_size)
			print("send selection")
			TCP:send(ffi.string(buffer, to_server_size))
		end
	end

	if key == "space" and MY_SELECTION then
		local data = ffi.new("to_server[1]")
		data[0].data_type = 1
		data[0].id = MY_ID
		data[0].target = MY_SELECTION
		local buffer = ffi.new("uint8_t["..tostring(to_server_size).."]")
		ffi.C.memcpy(buffer, data, to_server_size)
		print("send spell")
		TCP:send(ffi.string(buffer, to_server_size))
	end

	if key == "w" then
		local data = ffi.new("to_server[1]")
		data[0].data_type = 3 
		data[0].id = MY_ID
		local buffer = ffi.new("uint8_t["..tostring(to_server_size).."]")
		ffi.C.memcpy(buffer, data, to_server_size)
		print("send spell")
		TCP:send(ffi.string(buffer, to_server_size))
		
	end
end

