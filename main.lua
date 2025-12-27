local socket = require("socket")
local ffi = require("ffi")

ffi.cdef[[
typedef struct { 
	int32_t id; 
	float x; 
	float y; 
	uint8_t data_type;
	uint8_t is_you;
	uint8_t padding[2]; 
} from_server;


typedef struct { 
	int32_t id; 
	float x; 
	float y; 
	uint8_t data_type;
	uint8_t padding[3]; 
} to_server;

void* memcpy( void *restrict dest, const void *restrict src, size_t count );
]]

function love.load()
	print("Game started")

	TCP = socket.tcp() 
	
	TCP:settimeout(0)
	TCP:connect("127.0.0.1", 8080)

	print("Connected")

	FIGHTERS = {}

	MY_ID = nil;
end


function love.update(dt)
	local data, error = TCP:receive(16)

	while data ~= nil do	
		local buf = ffi.new("from_server[1]");
		ffi.C.memcpy(buf, data, 16);

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
					y = 320 + buf[0].y * 160
				}
			else
				FIGHTERS[lua_index].x = 320 + buf[0].x * 160
				FIGHTERS[lua_index].y = 320 + buf[0].y * 160
			end
		end
	
		if (buf[0].data_type == 2) then
			if buf[0].is_you > 0 then
				print("I am " .. tostring(buf[0].id));
				MY_ID = buf[0].id
			end
		end

		data, error = TCP:receive(16)
	end
end


function love.draw(dt)
	for i, val in pairs(FIGHTERS) do
		love.graphics.circle("fill", val.x, val.y, 10)
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
	
	local buffer = ffi.new("uint8_t[16]")
	ffi.C.memcpy(buffer, data, 16)

	print("send command")

	TCP:send(ffi.string(buffer, 16))
end
