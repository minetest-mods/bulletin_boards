-- TODO:
-- local bulletin boards? May not care about this
-- forward/back buttons to page through the bulletins on a board
-- "Bulletin X/Y" indicator on bulletin page
-- Timeout/teardown option for old posts if there's no space left.
--		Sort posts by number of posts per player, then tear down the oldest post from that group.
--		eg, if a player has 8 posts and another player has 7, tear down the oldest of the first player,
--			then the oldest of their combined posts
-- Admin override to tear down and edit bulletins
-- Protection?

local S = minetest.get_translator(minetest.get_current_modname())

local bulletin_boards = {}
bulletin_boards.player_state = {}
bulletin_boards.board_def = {}

local path = minetest.get_worldpath() .. "/bulletin_boards.lua"
local f, e = loadfile(path);
if f then
	bulletin_boards.global_boards = f()
else
	bulletin_boards.global_boards = {}
end

local function save_boards()
	file, e = io.open(path, "w");
	if not file then
		return error(e);
	end
	file:write(minetest.serialize(bulletin_boards.global_boards))
	file:close()
end

local max_text_size = 5000 -- half a book
local max_title_size = 80
local short_title_size = 12

local function get_board(name)
	local board = bulletin_boards.global_boards[name]
	if board then
		return board
	end
	board = {}
	bulletin_boards.global_boards[name] = board
	return board
end

local function get_item_desc(stack)
	local stack_def = stack:get_definition()
	if stack_def then
		return stack_def.description
	end
	return stack:get_name()
end


local function show_board(player_name, board_name)
	local formspec = {}
	local board = get_board(board_name)
	local current_time = minetest.get_gametime()
	local def = bulletin_boards.board_def[board_name]
	local desc = def.desc
	local tip
	if def.cost then
		local stack = ItemStack(def.cost)
		tip = S("Post your bulletin here for the cost of @1 @2", stack:get_count(), get_item_desc(stack))
	else
		tip = S("Post your bulletin here")
	end
	
	formspec[#formspec+1] = "size[8,8.5]"
	.. "container[0,0]"
	.. "label[3.25,-0.25;"..minetest.formspec_escape(desc).."]"
	.. "container_end[]"
	.. "container[0,0.5]"
	local i = 0
	for y = 0, 6 do
		for x = 0, 7 do
			i = i + 1
			local bulletin = board[i] or {}
			local short_title = bulletin.title or ""
			--Don't bother triming the title if the trailing dots would make it longer
			if #short_title > short_title_size + 3 then
				short_title = short_title:sub(1, short_title_size) .. "..."
			end
			local img = bulletin.icon or ""
	
			formspec[#formspec+1] =
				"image_button["..x..",".. y*1.2 ..";1,1;"..img..";button_"..i..";]"
				.."label["..x..","..y*1.2-0.35 ..";"..minetest.formspec_escape(short_title).."]"
			if bulletin.title and bulletin.owner and bulletin.timestamp then
				local days_ago = math.floor((current_time-bulletin.timestamp)/86400)
				formspec[#formspec+1] = "tooltip[button_"..i..";"
					..S("@1\nPosted by @2\n@3 days ago", minetest.formspec_escape(bulletin.title), bulletin.owner, days_ago).."]"
			else
				formspec[#formspec+1] = "tooltip[button_"..i..";"..tip.."]"
			end
		end
	end
	formspec[#formspec+1] = "container_end[]"

	bulletin_boards.player_state[player_name] = {board=board_name}
	minetest.show_formspec(player_name, "bulletin_boards:board", table.concat(formspec))
end

local icons = {
	"bulletin_boards_document_comment_above.png",
	"bulletin_boards_document_back.png",
	"bulletin_boards_document_next.png",
	"bulletin_boards_document_image.png",
	"bulletin_boards_document_signature.png",
	"bulletin_boards_to_do_list.png",
	"bulletin_boards_documents_email.png",
	"bulletin_boards_receipt_invoice.png",
}


local function show_bulletin(player, board_name, index)
	local board = get_board(board_name)
	local def = bulletin_boards.board_def[board_name]
	local bulletin = board[index] or {}
	local player_name = player:get_player_name()
	bulletin_boards.player_state[player_name] = {board=board_name, index=index}
	
	local tip
	if def.cost then
		local stack = ItemStack(def.cost)
		tip = S("Post bulletin with this icon at the cost of @1 @2", stack:get_count(), get_item_desc(stack))
	else
		tip = S("Post bulletin with this icon")
	end

	
	local player_inventory = minetest.get_inventory({type="player", name=player_name})
	local has_paper = player_inventory:contains_item("main", "default:paper")
	
	local formspec
	local esc = minetest.formspec_escape
	if (bulletin.owner == nil or bulletin.owner == player_name) and has_paper then
		formspec = {"size[8,8]"
			.."field[0.5,0.75;7.5,0;title;"..S("Title:")..";"..esc(bulletin.title or "").."]"
			.."textarea[0.5,1.15;7.5,7;text;"..S("Contents:")..";"..esc(bulletin.text or "").."]"
			.."label[0.3,7;"..S("Post:").."]"}
		for i, icon in ipairs(icons) do
			formspec[#formspec+1] = "image_button[".. i*0.75-0.5 ..",7.35;1,1;"..icon..";save_"..i..";]"
			.."tooltip[save_"..i..";"..tip.."]"
		end
		formspec[#formspec+1] = "image_button[".. (#icons+1)*0.75-0.25 ..",7.35;1,1;bulletin_boards_delete.png;delete;]"
			.."tooltip[delete;"..S("Delete this bulletin").."]"
			.."label["..(#icons+1)*0.75-0.25 ..",7;"..S("Delete:").."]"
		formspec = table.concat(formspec)
	elseif bulletin.owner then
		formspec = "size[8,8]"
			.."label[0.5,0.5;"..S("by @1", bulletin.owner).."]"
			.."tablecolumns[color;text]"
			.."tableoptions[background=#00000000;highlight=#00000000;border=false]"
			.."table[0.4,0;7,0.5;title;#FFFF00,"..esc(bulletin.title or "").."]"
			.."textarea[0.5,1.5;7.5,7;;"..esc(bulletin.text or "")..";]"
			.."button[2.5,7.5;3,1;back;" .. esc(S("Back")) .. "]"
	else
		return
	end

	minetest.show_formspec(player_name, "bulletin_boards:bulletin", formspec)
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "bulletin_boards:board" then return end
	local player_name = player:get_player_name()
	for field, state in pairs(fields) do
		if field:sub(1, #"button_") == "button_" then
			local i = tonumber(field:sub(#"button_"+1))
			local state = bulletin_boards.player_state[player_name]
			if state then
				show_bulletin(player, state.board, i)
			end
			return
		end		
	end	
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "bulletin_boards:bulletin" then return end
	local player_name = player:get_player_name()
	local state = bulletin_boards.player_state[player_name]
	if not state then return end	
	local board = get_board(state.board)
	if not board then return end
	
	if fields.back then
		bulletin_boards.player_state[player_name] = nil
		show_board(player_name, state.board)
	end
	
	if fields.delete then
		board[state.index] = nil
		fields.title = ""
		save_boards()
	end
	
	local player_inventory = minetest.get_inventory({type="player", name=player_name})
	local has_paper = player_inventory:contains_item("main", "default:paper")
	
	if fields.text ~= "" and has_paper then
		for field, _ in pairs(fields) do
			if field:sub(1, #"save_") == "save_" then
				local i = tonumber(field:sub(#"save_"+1))
				local bulletin = {}
				bulletin.owner = player_name
				bulletin.title = fields.title:sub(1, max_title_size)
				bulletin.text = fields.text:sub(1, max_text_size)
				bulletin.icon = icons[i]
				bulletin.timestamp = minetest.get_gametime()
				board[state.index] = bulletin
				player_inventory:remove_item("main", "default:paper")
				save_boards()
				break
			end
		end
	end
	
	if fields.quit then
		minetest.after(0.1, show_board, player_name, state.board)
	end
	
	bulletin_boards.player_state[player_name] = nil
	show_board(player_name, state.board)
end)


local function generate_random_board(rez, count)
	local tex = {"([combine:"..rez.."x"..rez}
	for i = 1, count do
		tex[#tex+1] = ":"..math.random(1,rez-32)..","..math.random(1,rez-32)
			.."="..icons[math.random(1,#icons)]
	end
	tex[#tex+1] = "^[resize:16x16)"
	return table.concat(tex)
end

local function register_board(board_name, board_def)
	bulletin_boards.board_def[board_name] = board_def
	local tile = "bulletin_boards_corkboard.png^"..generate_random_board(98, 7).."^bulletin_boards_frame.png"
	local bulletin_board_def = {
		description = board_def.desc,
		groups = {choppy=1},
		tiles = {tile},
		inventory_image = tile,
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		drawtype = "nodebox",
		node_box = {
			type = "wallmounted",
			wall_top    = {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5},
			wall_bottom = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
			wall_side   = {-0.5, -0.5, -0.5, -0.4375, 0.5, 0.5},
		},

		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			local player_name = clicker:get_player_name()
			show_board(player_name, board_name)
		end,
		
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", board_desc)
		end,
	}

	minetest.register_node("bulletin_boards:bulletin_board_"..board_name, bulletin_board_def)
end

register_board("test1", {desc = S("Test Board 1"), cost = "default:paper"})
register_board("test2", {desc = S("Test Board 2"), cost = "default:paper"})
register_board("test3", {desc = S("Test Board 3"), cost = "default:paper"})