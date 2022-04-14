local circle = {on = false, radius = 1, axis = "y", origin = nil, hud_ids = nil}
local circles = {}

local prefix = minetest.colorize("red", "[circle]")
local function format_msg(msg) return ("%s %s"):format(prefix, msg) end

local function remove_huds()
	if #circle.hud_ids > 0 then
		for _, v in ipairs(circle.hud_ids) do
			minetest.localplayer:hud_remove(v)
		end
		circle.hud_ids = {}
	end
end

local function is_circle(radius, a, b)
	return a * a + b * b < radius * radius
end

local function is_within(radius, a, b)
	return (is_circle(radius, a - 1, b + 1) and is_circle(radius, a + 1, b + 1) and
		is_circle(radius, a - 1, b - 1) and is_circle(radius, a + 1, b - 1) and
		is_circle(radius, a - 1, b) and is_circle(radius, a, b + 1) and
		is_circle(radius, a, b - 1) and is_circle(radius, a + 1, b))
end

local function circle_positions1(radius, filled) -- result similar to donatstudios.com/PixelCircleGenerator
	local positions = {}
	local is_int = radius == math.floor(radius)
	for b = -radius + 0.5, radius - 0.5 do
		for a = -radius + 0.5, radius - 0.5 do
			if is_circle(radius, a, b) and (not is_within(radius, a, b) or filled) then
				local c, d = a, b
				if is_int then c, d = a + 0.5, b + 0.5 end
				positions[#positions + 1] = {x = c, y = 0, z = d}
			end
		end
	end
	return positions
end

local function circle_positions2(radius, filled) -- result similar to worldedit cylinder
	local positions = {}
	radius = math.floor(radius + 0.5)
	local min_radius, max_radius = radius * (radius - 1), radius * (radius + 1)
	for b = -radius, radius do
		for a = -radius, radius do
			local squared = a * a + b * b
			if squared <= max_radius and (squared >= min_radius or filled) then
				positions[#positions + 1] = {x = a, y = 0, z = b}
			end
		end
	end
	return positions
end

minetest.register_chatcommand("circle", {
	description = "Circle settings",
	params = "help|toggle|on|off|origin|radius|axis|gen|info",
	func = function(param)
		param = param:lower()
		if param == "" or param == "toggle" then
			circle.on = not circle.on
			if circle.on then
				return true, format_msg("HUDs enabled.")
			else
				circle.origin = nil
				if circle.hud_ids then remove_huds() end
				return true, format_msg("HUDs disabled.")
			end
		elseif param:sub(1,3) == "gen" then
			param = param:sub(5)
			local new_radius = math.max(1, tonumber(param:match("^[%d%.]+")) or circle.radius)
			if new_radius ~= circle.radius then
				circle.radius = new_radius
				minetest.display_chat_message(("%s Radius set to %s."):format(prefix, circle.radius))
			end
			local radius_str = tostring(circle.radius)
			if circles[radius_str] and not param:find("force") then
				return true, format_msg("Positions already generated.")
			else
				circles[radius_str] = {}
			end
			local circle_positions = tonumber(param:match("m(%d)$")) == 2 and circle_positions2 or circle_positions1
			local time = os.clock()
			circles[radius_str] = circle_positions(circle.radius, param:find("filled"))
			return true, ("%s %s positions generated (%.2f ms)."):format(
				prefix, #circles[radius_str], (os.clock() - time) * 1000)
		elseif param:sub(1,6) == "radius" then
			circle.radius = math.max(1, tonumber(param:sub(8)) or circle.radius)
			return true, ("%s Radius set to %s."):format(prefix, circle.radius)
		elseif param:sub(1,4) == "axis" then
			circle.axis = param:sub(6):match("[xyz]") or circle.axis
			return true, ("%s Axis set to %s."):format(prefix, circle.axis)
		elseif param:sub(1,6) == "origin" then
			local pos = param:sub(8):match("^[%d.-]+[, ] *[%d.-]+[, ] *[%d.-]+$")
			if pos then
				circle.origin = vector.round(minetest.string_to_pos(pos))
			else
				circle.origin = vector.round(minetest.localplayer:get_pos())
			end
			return true, ("%s Origin set to %s."):format(prefix, minetest.pos_to_string(circle.origin))
		elseif param:sub(1,4) == "info" then
			local radius_str = tostring(circle.radius)
			minetest.display_chat_message(("%s Radius: %s, Origin: %s, Axis: %s, Positions: %s."):format(
				prefix, circle.radius,
				circle.origin and minetest.pos_to_string(circle.origin) or "undefined",
				circle.axis, circles[radius_str] and #circles[radius_str] or 0))
		elseif param == "on" then
			circle.on = true; return true, format_msg("HUDs enabled.")
		elseif param == "off" then
			circle.on = false
			circle.origin = nil
			if circle.hud_ids then remove_huds() end
			return true, format_msg("HUDs disabled.")
		elseif param == "help" then
			minetest.display_chat_message(format_msg("Help: Show this help message."))
			minetest.display_chat_message(format_msg("On: Enable HUDs."))
			minetest.display_chat_message(format_msg("Off: Disable HUDs."))
			minetest.display_chat_message(format_msg("|toggle: Toggle HUDs."))
			minetest.display_chat_message(format_msg("Origin: Set the origin. Param: [<x>(,| |, )<y>(,| |, )<z>]."))
			minetest.display_chat_message(format_msg("Radius: Set the radius. Param: [<radius>]."))
			minetest.display_chat_message(format_msg("Axis: Set the axis. Param: [x|y|z] (default: y)."))
			minetest.display_chat_message(format_msg("Gen: Generate positions. Params: [[<radius>]|[filled]|[force]|[m1|m2]] (default: m1)."))
			minetest.display_chat_message(format_msg("Info: Get settings values and positions count."))
		else
			return false, format_msg("Invalid Arguments.")
		end
	end
})

local function set_hud_pos(name, pos, color)
	circle.hud_ids[#circle.hud_ids + 1] = minetest.localplayer:hud_add({
		hud_elem_type	= "waypoint",
		name			= name,
		text			= "m",
		number			= color,
		world_pos		= pos
	})
end

minetest.register_on_punchnode(function(pos, punchnode)
	if circle.on then
		pos = vector.round(pos)
		if minetest.localplayer:get_control().aux1 or circle.origin == nil then
			circle.origin = pos
			minetest.display_chat_message(("%s Origin set to %s."):format(
				prefix, minetest.pos_to_string(circle.origin)))
		end
		if circle.hud_ids then remove_huds() else circle.hud_ids = {} end
		local radius_str = tostring(circle.radius)
		if circles[radius_str] then
			if vector.distance(pos, circle.origin) > circle.radius + 2 then	return end
			local axis = circle.axis
			for i, v in ipairs(circles[radius_str]) do
				if axis == "z" then
					v = {x = v.x, y = v.z, z = 0}
				elseif axis == "x" then
					v = {x = 0, y = v.x, z = v.z}
				end
				v = vector.add(circle.origin, v)
				if vector.distance(pos, v) < 16 then
					set_hud_pos(i, v, 0x0080FF)
				end
			end
		else
			minetest.display_chat_message(("%s No positions available (radius: %s)."):format(prefix, radius_str))
		end
	end
end)