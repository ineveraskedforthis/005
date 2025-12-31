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
	uint8_t data_data;
	uint8_t padding[2]; 
} to_server;
void* memcpy( void *restrict dest, const void *restrict src, size_t count );
]]

local from_server_size = 4 * 4;

local to_server_size = 5 * 4;
local payload_type = "uint8_t[" .. tostring(to_server_size) .. "]"

function send_payload(data)
	local buffer = ffi.new(payload_type)
	ffi.C.memcpy(buffer, data, to_server_size)
	TCP:send(ffi.string(buffer, to_server_size))
end

SCENE_CHOOSE_LOBBY = 0
SCENE_CHOOSE_CLASS = 1
SCENE_FIGHT = 2

function love.load(args)
	love.window.setMode(800, 600) 
	
	print("Game started")

	TCP = socket.tcp() 
	
	TCP:settimeout(0)
	TCP:connect(args[1] or "127.0.0.1", tonumber(args[2]) or 8080)

	print("Connected")

	FIGHTERS = {}
	PROJECTILES = {}

	CURRENT_SCENE = SCENE_CHOOSE_LOBBY	

	MY_ID = nil;
	MY_FIGHTER = nil;
	MY_SELECTION = nil
	MY_CLASS = nili

	BG_IMAGE = love.graphics.newImage("bg.png")
	BG_FIELD_IMAGE = love.graphics.newImage("bg_field.png")


	SPRITE_MAGE_IDLE = love.graphics.newImage("mage-idle.png")
	SPRITE_MAGE_MOVE = love.graphics.newImage("mage-move.png")
	SPRITE_MAGE_CAST = love.graphics.newImage("mage-cast.png")

	SPRITE_WARRIOR_MOVE_FORWARD_1 = love.graphics.newImage("sprites/warrior/step-1-forward.png")
	SPRITE_WARRIOR_MOVE_FORWARD_2 = love.graphics.newImage("sprites/warrior/step-2-forward.png")
	SPRITE_WARRIOR_MOVE_BACK_1 = love.graphics.newImage("sprites/warrior/step-1-back.png")
	SPRITE_WARRIOR_MOVE_BACK_2 = love.graphics.newImage("sprites/warrior/step-2-back.png")
	SPRITE_WARRIOR_MOVE_LEFT_1 = love.graphics.newImage("sprites/warrior/step-1-left.png")
	SPRITE_WARRIOR_MOVE_LEFT_2 = love.graphics.newImage("sprites/warrior/step-2-left.png")
	SPRITE_WARRIOR_MOVE_RIGHT_1 = love.graphics.newImage("sprites/warrior/step-1-right.png")
	SPRITE_WARRIOR_MOVE_RIGHT_2 = love.graphics.newImage("sprites/warrior/step-2-right.png")
	SPRITE_WARRIOR_ATTACK = love.graphics.newImage("sprites/warrior/attack.png")

	SPRITE_ROGUE_MOVE_FORWARD_1 = love.graphics.newImage("sprites/rogue/forward-1.png")
	SPRITE_ROGUE_MOVE_FORWARD_2 = love.graphics.newImage("sprites/rogue/forward-2.png")
	SPRITE_ROGUE_MOVE_FORWARD_LEFT_1 = love.graphics.newImage("sprites/rogue/forward-left-1.png")
	SPRITE_ROGUE_MOVE_FORWARD_LEFT_2 = love.graphics.newImage("sprites/rogue/forward-left-2.png")
	SPRITE_ROGUE_MOVE_LEFT_1 = love.graphics.newImage("sprites/rogue/left-1.png")
	SPRITE_ROGUE_MOVE_LEFT_2 = love.graphics.newImage("sprites/rogue/left-2.png")
	SPRITE_ROGUE_MOVE_BACK_LEFT_1 = love.graphics.newImage("sprites/rogue/back-left-1.png")
	SPRITE_ROGUE_MOVE_BACK_LEFT_2 = love.graphics.newImage("sprites/rogue/back-left-2.png")
	SPRITE_ROGUE_MOVE_BACK_1 = love.graphics.newImage("sprites/rogue/back-1.png")
	SPRITE_ROGUE_MOVE_BACK_2 = love.graphics.newImage("sprites/rogue/back-2.png")
	SPRITE_ROGUE_ATTACK = love.graphics.newImage("sprites/rogue/attack.png")
end

CONTROL_RATE = 1 / 30
CURRENT_CONTROL_TIMER = 0

LAST_DX = 0
LAST_DY = 0

SCALE = 250

BASE_SHIFT_X = 400
BASE_SHIFT_Y = 300

SHIFT_X = 0
SHIFT_Y = 0

TARGET_SHIFT_X = 0
TARGET_SHIFT_Y = 0

function love.update(dt)
	if MY_ID then
		local dx = 0
		local dy = 0

		if love.keyboard.isDown( "w" ) then
			dy = dy - 1
		end
		if love.keyboard.isDown( "a" ) then
			dx = dx - 1
		end
		if love.keyboard.isDown( "s" ) then
			dy = dy + 1
		end
		if love.keyboard.isDown( "d" ) then
			dx = dx + 1
		end

		if dx ~= LAST_DX or dy ~= LAST_DY then
			CURRENT_CONTROL_TIMER = CONTROL_RATE

			LAST_DX = dx
			LAST_DY = dy
			
			local data = ffi.new("to_server[1]")
			data[0].x = dx
			data[0].y = dy
			data[0].data_type = 0
			data[0].id = MY_ID

			send_payload(data);
		end
	end


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
					x = buf[0].x,
					y = buf[0].y,
					hp = buf[0].additional_data,
					direction = 0,
					speed = 0,
					char_chass = buf[0].is_you,
					path_length = 0
				}
			else
				local dx = buf[0].x - FIGHTERS[lua_index].x
				local dy = buf[0].y - FIGHTERS[lua_index].y
				
				local speed = math.sqrt(dx * dx + dy * dy)
				if speed ~= 0 then
					FIGHTERS[lua_index].direction = math.atan2(dy, dx)
				end
				FIGHTERS[lua_index].speed = speed / dt;
				
				FIGHTERS[lua_index].x = buf[0].x
				FIGHTERS[lua_index].y = buf[0].y
				FIGHTERS[lua_index].hp = buf[0].additional_data
				FIGHTERS[lua_index].char_class = buf[0].is_you
				FIGHTERS[lua_index].path_length = FIGHTERS[lua_index].path_length + speed
			end

			if lua_index == MY_FIGHTER then
				TARGET_SHIFT_X = -buf[0].x * SCALE
				TARGET_SHIFT_Y = -buf[0].y * SCALE
			end
		end

		if (buf[0].data_type == 1) then
			local lua_index = tonumber(buf[0].id)
			if PROJECTILES[lua_index] == nil then
				PROJECTILES[lua_index] = {
					x = buf[0].x,
					y = buf[0].y
				}
			else
				PROJECTILES[lua_index].x = buf[0].x
				PROJECTILES[lua_index].y = buf[0].y
			end
		end
	
		if (buf[0].data_type == 2) then
			if buf[0].is_you > 0 then
				print("I am " .. tostring(buf[0].id));
				MY_ID = buf[0].id
				
				local data = ffi.new("to_server[1]")
				data[0].data_type = 6
				data[0].id = MY_ID
				send_payload(data)				
			end
		end
		
		if (buf[0].data_type == 4) then
			if buf[0].is_you > 0 then
				print("I control " .. tostring(buf[0].id));
				MY_FIGHTER = buf[0].id
				
				local data = ffi.new("to_server[1]")
				data[0].data_type = 10
				data[0].id = MY_ID
				send_payload(data)				
			end
		end
		
		if (buf[0].data_type == 3) then
			print(tostring(buf[0].event))
			local lua_index = tonumber(buf[0].id)
			if buf[0].event == 3 then
				print("no damage")
				FIGHTERS[lua_index].no_damage_timer = 0.3
			elseif buf[0].event == 4 and lua_index == MY_ID then
				CURRENT_SCENE = SCENE_CHOOSE_CLASS
			elseif buf[0].event == 5 and lua_index == MY_ID then
				CURRENT_SCENE = SCENE_FIGHT
			elseif buf[0].event == 6 or buf[0].event == 9 then
				FIGHTERS[lua_index] = nil
			elseif buf[0].x > 0 then
				if FIGHTERS[lua_index] then
					FIGHTERS[lua_index].progress = buf[0].x
					FIGHTERS[lua_index].max_progress = buf[0].x
				end
			end
		end

		data, error = TCP:receive(16)
	end

	for i, val in pairs(FIGHTERS) do
		if val.progress then
			val.progress = math.max(0, val.progress - dt)
		end

		if val.no_damage_timer then
			val.no_damage_timer = math.max(0, val.no_damage_timer - dt)
		end
	end
end

LOBBY_SELECTOR_X = 20
LOBBY_SELECTOR_Y = 20
LOBBY_SELECTOR_H = 20
LOBBY_SELECTOR_W = 200
CLASS_SELECTOR_X = 20
CLASS_SELECTOR_Y = 20
CLASS_SELECTOR_H = 20
CLASS_SELECTOR_W = 200

function in_rect(cx, cy, x, y, w, h) 
	if cx < x then
		return false
	end
	if cx > x + w then
		return false
	end
	if cy < y then
		return false
	end
	if cy > y + h then
		return false
	end
	return true
end

CLASS_NAME = { "MAGE", "WARRIOR", "ROGUE" }

function love.draw(dt)
	SHIFT_X = SHIFT_X * 0.9 + TARGET_SHIFT_X * 0.1
	SHIFT_Y = SHIFT_Y * 0.9 + TARGET_SHIFT_Y * 0.1

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(BG_IMAGE, SHIFT_X / 2 - BASE_SHIFT_X / 2, SHIFT_Y / 2 - BASE_SHIFT_Y / 2)


	
	love.graphics.setColor(0, 0, 0)
	if CURRENT_SCENE == SCENE_CHOOSE_LOBBY then
		for i = 0, 2 do
			love.graphics.setColor(1, 1, 1)

		
			love.graphics.rectangle(
				"fill", 
				LOBBY_SELECTOR_X, 
				LOBBY_SELECTOR_Y + LOBBY_SELECTOR_H * i, 
				LOBBY_SELECTOR_W, 
				LOBBY_SELECTOR_H
			)
			love.graphics.setColor(0, 0, 0)

			love.graphics.rectangle(
				"line", 
				LOBBY_SELECTOR_X, 
				LOBBY_SELECTOR_Y + LOBBY_SELECTOR_H * i, 
				LOBBY_SELECTOR_W, 
				LOBBY_SELECTOR_H
			)

			
			love.graphics.print(
				"ENTER ROOM " .. tostring(i), 
				LOBBY_SELECTOR_X, 
				LOBBY_SELECTOR_Y + LOBBY_SELECTOR_H * i
			)				
		end

		return
	end

	if CURRENT_SCENE == SCENE_CHOOSE_CLASS then
		love.graphics.setColor(0, 0, 0)
		for i = 0, 2 do
			love.graphics.setColor(1, 1, 1)
			love.graphics.rectangle(
				"fill", 
				LOBBY_SELECTOR_X, 
				LOBBY_SELECTOR_Y + LOBBY_SELECTOR_H * i, 
				LOBBY_SELECTOR_W, 
				LOBBY_SELECTOR_H
			)
			love.graphics.setColor(0, 0, 0)
			love.graphics.rectangle(
				"line", 
				CLASS_SELECTOR_X, 
				CLASS_SELECTOR_Y + CLASS_SELECTOR_H * i, 
				CLASS_SELECTOR_W, 
				CLASS_SELECTOR_H
			)

			love.graphics.print(
				"SELECT CLASS " .. CLASS_NAME[i + 1], 
				CLASS_SELECTOR_X, 
				CLASS_SELECTOR_Y + CLASS_SELECTOR_H * i
			)
		end

		return
	end
		
	love.graphics.setColor(1, 1, 1)

	love.graphics.draw(
		BG_FIELD_IMAGE, 
		SHIFT_X, 
		SHIFT_Y - 40,
		0,
		0.65, 
		0.65
	)
	

	for i, val in pairs(FIGHTERS) do
		if (val.hp > 0) then

			local x = BASE_SHIFT_X + val.x * SCALE + SHIFT_X
			local y = BASE_SHIFT_Y + val.y * SCALE + SHIFT_Y

			if val.char_class == 0 then
				love.graphics.setColor(1, 1, 1)
				if val.progress and val.progress > 0 then
					if math.cos(val.direction) >= 0 then
						love.graphics.draw(
							SPRITE_MAGE_CAST, 
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_MAGE_CAST,
							x + 30, y - 60, 0, -0.25, 0.25
						)
					end
				elseif val.speed == 0 then
					if math.cos(val.direction) >= 0 then
						love.graphics.draw(
							SPRITE_MAGE_IDLE, 
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_MAGE_IDLE,
							x + 30, y - 60, 0, -0.25, 0.25
						)
					end
				else	
					if math.cos(val.direction) >= 0 then
						love.graphics.draw(
							SPRITE_MAGE_MOVE, 
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_MAGE_MOVE,
							x + 30, y - 60, 0, -0.25, 0.25
						)
					end
				end
			elseif val.char_class == 1 then
				love.graphics.setColor(1, 1, 1)
				local dx = math.cos(val.direction)
				local dy = math.sin(val.direction)
				local step = math.floor((val.path_length % 0.4) / 0.2)
				
				if val.progress and val.progress > 0 then
					if math.cos(val.direction) >= 0 then
						love.graphics.draw(
							SPRITE_WARRIOR_ATTACK, 
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_WARRIOR_ATTACK,
							x + 30, y - 60, 0, -0.25, 0.25
						)
					end
				elseif dx > math.abs(dy) * 2 then
					-- right
					if step == 0 then
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_RIGHT_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_RIGHT_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				elseif -dx > math.abs(dy) * 2 then
					-- left
					if step == 0 then
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_LEFT_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_LEFT_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				elseif dy * 2 > math.abs(dx) then
					-- forward
					if step == 0 then
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_FORWARD_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_FORWARD_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				else
					-- back
					if step == 0 then
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_BACK_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_WARRIOR_MOVE_BACK_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				end
			elseif val.char_class == 2 then
				love.graphics.setColor(1, 1, 1)

				local dx = math.cos(val.direction)
				local dy = math.sin(val.direction)
				local step = math.floor((val.path_length % 0.3) / 0.15)

				if val.progress and val.progress > 0 then
					if math.cos(val.direction) >= 0 then
						love.graphics.draw(
							SPRITE_ROGUE_ATTACK, 
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_ATTACK,
							x + 30, y - 60, 0, -0.25, 0.25
						)
					end
				elseif dx > math.abs(dy) * 2 then
					-- right
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_LEFT_1,
							60 + x - 30, y - 60, 0, -0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_LEFT_2,
							60 + x - 30, y - 60, 0, -0.25, 0.25
						)
					end
				elseif -dx > math.abs(dy) * 2 then
					-- left
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_LEFT_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_LEFT_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				elseif dy > 2 * math.abs(dx) then
					-- forward
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_FORWARD_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_FORWARD_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				elseif -dy > 2 * math.abs(dx) then
					-- back
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_BACK_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_BACK_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				elseif 2 * dy > math.abs(dx) and dx < 0 then
					-- forward left
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_FORWARD_LEFT_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_FORWARD_LEFT_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				elseif 2 * dy > math.abs(dx) and dx > 0 then
					-- forward right
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_FORWARD_LEFT_1,
							60 + x - 30, y - 60, 0, -0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_FORWARD_LEFT_2,
							60 + x - 30, y - 60, 0, -0.25, 0.25
						)
					end
				elseif -2 * dy > math.abs(dx) and dx > 0 then
					-- back right
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_BACK_LEFT_1,
							60 + x - 30, y - 60, 0, -0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_BACK_LEFT_2,
							60 + x - 30, y - 60, 0, -0.25, 0.25
						)
					end
				elseif -2 * dy > math.abs(dx) and dx < 0 then
					-- back left
					if step == 0 then
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_BACK_LEFT_1,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					else
						love.graphics.draw(
							SPRITE_ROGUE_MOVE_BACK_LEFT_2,
							x - 30, y - 60, 0, 0.25, 0.25
						)
					end
				end


			else
				love.graphics.setColor(0.1, 0.1, 0.1)
				love.graphics.circle("fill", x, y, 3)
			end
			
			love.graphics.setColor(0.1, 0.1, 0.1)
			love.graphics.circle("line", x, y, SCALE * 0.1)


			if (i == MY_SELECTION) then
				love.graphics.circle("line", x, y, 10)
			end

			if val.no_damage_timer and val.no_damage_timer > 0 then
				love.graphics.setColor(1, 1, 0)
				love.graphics.circle("line", x, y, 3)
			end

			hp_size = 5
	
			for hitpoint = 0, val.hp - 1 do
				love.graphics.setColor(0.6, 0.6, 0.1)
				love.graphics.rectangle(
					"fill", x + 15, y - 10 + hitpoint * hp_size, hp_size, hp_size
				) 
			end
			for hitpoint = 0, 4 do
				love.graphics.setColor(0.9, 1.0, 0.3)
				love.graphics.rectangle(
					"line", x + 15, y - 10 + hitpoint * hp_size, hp_size, hp_size
				) 
			end
			
			if val.progress and val.progress > 0 then
				love.graphics.rectangle(
					"fill", 
					x - 10, 
					y + 10, 
					val.progress / val.max_progress * 20, 
					5
				)
			end
		end
	end

	love.graphics.setColor(1, 0, 0)

	for i, val in pairs(PROJECTILES) do
		local x = BASE_SHIFT_X + val.x * SCALE + SHIFT_X
		local y = BASE_SHIFT_Y + val.y * SCALE + SHIFT_Y
		love.graphics.circle("fill", x, y, 3)
	end

	love.graphics.circle("line", BASE_SHIFT_X + SHIFT_X, BASE_SHIFT_Y + SHIFT_Y, SCALE)


	love.graphics.print("WASD: MOVE", 20, 20)
	love.graphics.print("TAB: SELECT_NEXT_TARGET", 20, 40)
	love.graphics.print("K: PARRY", 20, 60)

	if MY_CLASS == 0 then
		love.graphics.print("SPACE: SPELL", 20, 80)
	end

	if MY_CLASS == 1 then
		love.graphics.print("SPACE: ATTACK", 20, 80)
		love.graphics.print("J: CHARGE", 20, 100)
	end

	if MY_CLASS == 2 then
		love.graphics.print("SPACE: ATTACK", 20, 80)
		love.graphics.print("J: INVISIBILITY", 20, 100)
	end
end



function love.mousepressed(x, y, button)
	if MY_ID == nil then
		return
	end

	if CURRENT_SCENE == SCENE_CHOOSE_LOBBY then
		for i = 0, 2 do
			if in_rect(x, y, 
				LOBBY_SELECTOR_X,
				LOBBY_SELECTOR_Y + LOBBY_SELECTOR_H * i,
				LOBBY_SELECTOR_W,
				LOBBY_SELECTOR_H
			) then
				local data = ffi.new("to_server[1]")
				data[0].data_type = 5
				data[0].data_data = i
				data[0].id = MY_ID
				send_payload(data)
			end
		end
		return
	end

	if CURRENT_SCENE == SCENE_CHOOSE_CLASS then
		for i = 0, 2 do
			if in_rect(x, y,
				CLASS_SELECTOR_X,
				CLASS_SELECTOR_Y + CLASS_SELECTOR_H * i,
				CLASS_SELECTOR_W,
				CLASS_SELECTOR_H
			) then
				MY_CLASS = i
				local data = ffi.new("to_server[1]")
				data[0].data_type = 4
				data[0].data_data = i
				data[0].id = MY_ID
				send_payload(data)
			end
		end

		return
	end

	if false then
		local data = ffi.new("to_server[1]")
		data[0].x = (x - SHIFT_X) / SCALE 
		data[0].y = (y - SHIFT_Y) / SCALE
		data[0].data_type = 0
		data[0].id = MY_ID
		local buffer = ffi.new("uint8_t[" .. tostring(to_server_size) .. "]")
		ffi.C.memcpy(buffer, data, to_server_size)
		print("send command")
		TCP:send(ffi.string(buffer, to_server_size))
	end
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
		if MY_CLASS == 0 then
			data[0].data_type = 1
		else
			data[0].data_type = 7
		end
		data[0].id = MY_ID
		data[0].target = MY_SELECTION
		local buffer = ffi.new("uint8_t["..tostring(to_server_size).."]")
		ffi.C.memcpy(buffer, data, to_server_size)
		print("send spell")
		TCP:send(ffi.string(buffer, to_server_size))
	end

	if key == "j" then
		local data = ffi.new("to_server[1]")
		
		data[0].id = MY_ID

		if MY_CLASS == 1 then
			if MY_SELECTION == nil then
				return
			end
			data[0].data_type = 9
			data[0].target = MY_SELECTION
		end

		if MY_CLASS == 2 then
			data[0].data_type = 8
		end

		send_payload(data)
	end

	if key == "k" then
		local data = ffi.new("to_server[1]")
		data[0].data_type = 3 
		data[0].id = MY_ID
		local buffer = ffi.new("uint8_t["..tostring(to_server_size).."]")
		ffi.C.memcpy(buffer, data, to_server_size)
		print("send spell")
		TCP:send(ffi.string(buffer, to_server_size))
		
	end
end

