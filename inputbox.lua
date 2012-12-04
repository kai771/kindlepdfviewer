require "font"
require "rendertext"
require "keys"
require "graphics"
require "screen"

MODE_CALC = 1
MODE_TERM = 2

INTEXT = 3			-- what row is the text row of vk_cursor_y?
vk_cursor_x = 5 -- current position of virtual keyboard cursor
vk_cursor_y = 3 -- current position of virtual keyboard cursor

vk_pcursor_x = vk_cursor_x	-- previous position of virtual keyboard cursor
vk_pcursor_y = vk_cursor_y	-- previous position of virtual keyboard cursor

vk_kw = 32	-- virtual key width
vk_kh = 32	-- virtual key height
vk_gx = 19	-- horizontal gap between virtual keys 
vk_gy = 4		-- vertical gap between virtual keys
vk_ml = 11	-- margin on the left
vk_mb	= 7		-- margin on the bottom


vk_dx = 51	-- dx, dy = xy-distance between the button rows
vk_dy = 36
vk_lx = 20	-- lx - position of left button column
vk_r = 17		-- radius of circles around chars
vk_c = 6		-- colour of circles around chars
vk_t = 2		-- thickness of circles around chars

----------------------------------------------------
-- General inputbox
----------------------------------------------------
InputBox = {
	-- Class vars:
	h = 100,
	input_slot_w = nil,
	input_start_x = nil,
	input_start_y = nil,
	input_cur_x = nil, -- points to the start of next input pos

	input_bg = 0,
	input_string = "",
	cursor = nil,

	-- font for displaying input content
	-- we have to use mono here for better distance controlling
	face = Font:getFace("infont", 25),
	fheight = 25,
	fwidth = 15,
	commands = nil,

	vk_bg = 0,
	charlist = {}, -- table to store input string
	charpos = 1,
	charposl = 1,	-- position of the first displayed char
	pos_on_screen = 1, -- position of cursor in input line on screen, in num of characters
	max_input_chars = nil,
	INPUT_KEYS = {}, -- table to store layouts
	-- values to control layouts: min & max
	min_layout = 2,
	max_layout = 9,
	layout = 3,
	-- now bits to toggle the layout mode
	shiftmode = true,	-- toggle chars <-> capitals,	lowest bit in (layout-2)
	symbolmode = false,	-- toggle chars <-> symbols,	middle bit in (layout-2)
	utf8mode = false,	-- toggle english <-> national,	highest bit in (layout-2)
	inputmode,		-- define mode: input <> calculator <> terminal
	calcfunctions = nil, -- math functions for calculator helppage
}

function InputBox:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function InputBox:refreshText()
	local text = string.sub(self.input_string, self.charposl, self.charposl + self.max_input_chars - 1)
	-- clear previous painted text
	fb.bb:paintRect(self.input_start_x-5, self.input_start_y-19, self.input_slot_w, self.fheight, self.input_bg)
	-- paint new text
	renderUtf8Text(fb.bb, self.input_start_x, self.input_start_y, self.face, text, true)
end

function InputBox:addChar(char)
	self.cursor:clear()
	-- draw new text
	local cur_index = (self.cursor.x_pos + 3 - self.input_start_x) / self.fwidth
	table.insert(self.charlist, self.charpos, char)
	self.charpos = self.charpos + 1
	if self.pos_on_screen < self.max_input_chars then 
		self.pos_on_screen = self.pos_on_screen + 1
		self.input_string = self:CharlistToString()
		self:refreshText()
		self.input_cur_x = self.input_cur_x + self.fwidth
		self.cursor:moveHorizontal(self.fwidth)
	else
		self.charposl = self.charposl + 1	
		self.input_string = self:CharlistToString()
		self:refreshText()
	end 
	self.cursor:draw()
	fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
end

function InputBox:delChar()
	if self.input_start_x == self.input_cur_x then return end
	local cur_index = (self.cursor.x_pos + 3 - self.input_start_x) / self.fwidth
	if cur_index == 0 then return end
	self.cursor:clear()
	self.charpos = self.charpos - 1
	if self.charposl > 1 then 
		self.charposl = self.charposl - 1 
	else
		self.pos_on_screen = self.pos_on_screen - 1
		self.input_cur_x = self.input_cur_x - self.fwidth
		self.cursor:moveHorizontal(-self.fwidth)
	end	
	-- draw new text
	table.remove(self.charlist, self.charpos)
	self.input_string = self:CharlistToString()
	self:refreshText()
	-- draw new cursor
	self.cursor:draw()
	fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
end

function InputBox:resetCursorPos()
	self.charpos = 1
	self.charposl = 1
	self.pos_on_screen = 1
	self.cursor.x_pos = self.input_start_x - 3
end

function InputBox:resetCursorPosAndRedraw()
	self.cursor:clear()
	self:resetCursorPos()
	self:refreshText()
	self.cursor:draw()
	fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)	
end

function InputBox:clearText()
	self.cursor:clear()
	self.input_string = ""
	self.charlist = {}
	self.charpos = 1
	self.charposl = 1
	self.pos_on_screen = 1
	self:refreshText()
	self.cursor.x_pos = self.input_start_x - 3
	self.cursor:draw()
	fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
end

function InputBox:drawBox(ypos, w, h, title)
	-- draw input border
	local r = 6 -- round corners
	blitbuffer.paintBorder(fb.bb, 0, ypos, fb.bb:getWidth(), r, r, 15, r)
	fb.bb:paintRect(0, ypos+r, w, h - r, self.vk_bg)
	-- draw input title
	self.input_start_y = ypos + 37
	-- draw the box title > estimate the start point for future text & the text slot width
	self.input_start_x = 25 + renderUtf8Text(fb.bb, 15, self.input_start_y, self.face, title, true)
	self.input_slot_w = fb.bb:getWidth() - self.input_start_x - 5
	self.max_input_chars = math.floor(self.input_slot_w / self.fwidth)
	fb.bb:invertRect(0, ypos+r, fb.bb:getWidth(), 120)
	-- draw input slot
	fb.bb:paintRect(self.input_start_x - 5, ypos + 10, self.input_slot_w, h - 20, self.input_bg)
end

----------------------------------------------------------------------
-- InputBox:input()
--
-- @title: input prompt for the box
-- @d_text: default to nil (used to set default text in input slot)
-- @is_hint: if this arg is true, default text will be used as hint
-- message for input
----------------------------------------------------------------------
function InputBox:input(ypos, height, title, d_text, is_hint)
	-- To avoid confusion with old ypos & height parameters, I'd better define
	-- my own position, at the bottom screen edge
	ypos = fb.bb:getHeight() - 165
	-- some corrections for calculator mode
	if self.inputmode == MODE_CALC then
		self:setCalcMode()
	end

	-- at first, draw titled box and content
	local h, w = 55, fb.bb:getWidth() - 2
	self:drawBox(ypos, w, h, title)
	-- do some initilization
	self.ypos = ypos
	self.h = 100
	self.input_cur_x = self.input_start_x
	self:addAllCommands()
	self.cursor = Cursor:new {
		x_pos = self.input_start_x - 3,
		y_pos = ypos + 13,
		h = 30,
	}

	if d_text then
		if is_hint then
			-- print hint text
			fb.bb:paintRect(self.input_start_x-5, self.input_start_y-19, self.input_slot_w, self.fheight, self.input_bg)
			renderUtf8Text(fb.bb, self.input_start_x+5, self.input_start_y, self.face, d_text, 0)
			fb.bb:dimRect(self.input_start_x-5, self.input_start_y-19, self.input_slot_w, self.fheight, self.input_bg)
		else
			-- add text to input_string
			self:StringToCharlist(d_text)
			if self.charpos < self.max_input_chars then 
				self.pos_on_screen = self.charpos
				self.charposl = 1
			else
				self.pos_on_screen = self.max_input_chars
				self.charposl = self.charpos - self.max_input_chars + 1
			end
			self.input_cur_x = self.input_cur_x + (self.fwidth * (self.pos_on_screen - 1))
			self.cursor.x_pos = self.cursor.x_pos + (self.fwidth * (self.pos_on_screen - 1))
			self:refreshText()
		end
	end
	self.cursor:draw()
	fb:refresh(1, 1, ypos, w, h)

	local ev, keydef, command, ret_code
	while true do
		ev = input.saveWaitForEvent()
		ev.code = adjustKeyEvents(ev)
		if ev.type == EV_KEY and ev.value ~= EVENT_VALUE_KEY_RELEASE then
			keydef = Keydef:new(ev.code, getKeyModifier())
			Debug("key pressed: "..tostring(keydef))
			command = self.commands:getByKeydef(keydef)
			if command ~= nil then
				Debug("command to execute: "..tostring(command))
				ret_code = command.func(self, keydef)
			else
				Debug("command not found: "..tostring(command))
			end
			if ret_code == "break" then
				ret_code = nil
				break
			end
		end -- if
	end -- while

	local output = self.input_string
	self.input_string = ""
	self.charlist = {}
	self.charpos = 1
	self.charposl = 1
	self.pos_on_screen = 1
	return output
end

function InputBox:setLayoutsTable()
	-- trying to read the layout from the user-defined file
	local ok, stored = pcall(dofile, lfs.currentdir() .. "/mykeyboard.lua")
	if ok then
		self.INPUT_KEYS = stored
	else	-- if an error happens, we use the default layout
		self.INPUT_KEYS = {
			{ KEY_Q,	"Q",	"q",	"1",	"!",		"Я",	"я",	"1",	"!", },
			{ KEY_W,	"W",	"w",	"2",	"?",		"Ж",	"ж",	"2",	"?", },
			{ KEY_E,	"E",	"e",	"3",	"|",		"Е",	"е",	"3",	"«", },
			{ KEY_R,	"R",	"r",	"4",	"#",		"Р",	"р",	"4",	"»", },
			{ KEY_T,	"T",	"t",	"5",	"@",		"Т",	"т",	"5",	":", },
			{ KEY_Y,	"Y",	"y",	"6",	"‰",		"Ы",	"ы",	"6",	";", },
			{ KEY_U,	"U",	"u",	"7",	"'",		"У",	"у",	"7",	"~", },
			{ KEY_I,	"I",	"i",	"8",	"`",		"И",	"и",	"8",	"(",},
			{ KEY_O,	"O",	"o",	"9",	":",		"О",	"о",	"9",	")",},
			{ KEY_P,	"P",	"p",	"0",	";",		"П",	"п",	"0",	"=", },
			-- middle raw
			{ KEY_A,	"A",	"a",	"+",	"…",		"А",	"а",	"Ш",	"ш", },
			{ KEY_S,	"S",	"s",	"-",	"_",		"С",	"с",	"Ѕ",	"ѕ", },
			{ KEY_D,	"D",	"d",	"*",	"=",		"Д",	"д",	"Э",	"э", },
			{ KEY_F,	"F",	"f",	"/",	"\\",		"Ф",	"ф",	"Ю",	"ю", },
			{ KEY_G,	"G",	"g",	"%",	"„",		"Г",	"г",	"Ґ",	"ґ", },
			{ KEY_H,	"H",	"h",	"^",	"“",		"Ч",	"ч",	"Ј",	"ј", },
			{ KEY_J,	"J",	"j",	"<",	"”",		"Й",	"й",	"І",	"і", },
			{ KEY_K,	"K",	"k",	"=",	"\"",		"К",	"к",	"Ќ",	"ќ", },
			{ KEY_L,	"L",	"l",	">",	"~",		"Л",	"л",	"Љ",	"љ", },
			-- lowest raw
			{ KEY_Z,	"Z",	"z",	"(",	"$",		"З",	"з",	"Щ",	"щ", },
			{ KEY_X,	"X",	"x",	")",	"€",		"Х",	"х",	"№",	"@", },
			{ KEY_C,	"C",	"c",	"&",	"¥",		"Ц",	"ц",	"Џ",	"џ", },
			{ KEY_V,	"V",	"v",	":",	"£",		"В",	"в",	"Ў",	"ў", },
			{ KEY_B,	"B",	"b",	"π",	"‚",		"Б",	"б",	"Ћ",	"ћ", },
			{ KEY_N,	"N",	"n",	"е",	"‘",		"Н",	"н",	"Њ",	"њ", },
			{ KEY_M,	"M",	"m",	"~",	"’",		"М",	"м",	"Ї",	"ї", },
			{ KEY_DOT,	",",	".",	".",	",",		",",	".",	"Є",	"є", },
			-- Let us make key 'Space' the same for all layouts
			{ KEY_SPACE," ",	" ",	" ",	" ",		" ",	" ",	" ",	" ", },
			-- Simultaneous pressing Alt + Q..P should also work properly everywhere
			{ KEY_1,	"1",	"1",	"1",	"1",		"1",	"1",	"1",	"1", },
			{ KEY_2,	"2",	"2",	"2",	"2",		"2",	"2",	"2",	"2", },
			{ KEY_3,	"3",	"3",	"3",	"3",		"3",	"3",	"3",	"3", },
			{ KEY_4,	"4",	"4",	"4",	"4",		"4",	"4",	"4",	"4", },
			{ KEY_5,	"5",	"5",	"5",	"5",		"5",	"5",	"5",	"5", },
			{ KEY_6,	"6",	"6",	"6",	"6",		"6",	"6",	"6",	"6", },
			{ KEY_7,	"7",	"7",	"7",	"7",		"7",	"7",	"7",	"7", },
			{ KEY_8,	"8",	"8",	"8",	"8",		"8",	"8",	"8",	"8", },
			{ KEY_9,	"9",	"9",	"9",	"9",		"9",	"9",	"9",	"9", },
			{ KEY_0,	"0",	"0",	"0",	"0",		"0",	"0",	"0",	"0", },
			-- DXG keys
			{ KEY_SLASH,"/",	"\\",	"/",	"\\",		"/",	"\\",	"/",	"\\", },
		}
	end -- if ok
end

function InputBox:invertVKey(cx, cy)
	local vy = fb.bb:getHeight() - vk_kh
	local x = vk_ml + cx*vk_kw + cx*vk_gx
	local y = vy - (vk_mb + cy*vk_kh + cy*vk_gy)
--	fb.bb:invertRect(x, y, vk_kw, vk_kh)
	fb.bb:invertRect(x, y, vk_kw, 2)
	fb.bb:invertRect(x, y+vk_kh, vk_kw, 2)
	fb.bb:invertRect(x, y+2, 2, vk_kh-2)
	fb.bb:invertRect(x+vk_kw-2, y+2, 2, vk_kh-2)
end

function InputBox:updateVKCursor()
	if (vk_cursor_x ~= vk_pcursor_x) or (vk_cursor_y ~= vk_pcursor_y) then
		if vk_pcursor_y < INTEXT then
			self:invertVKey(vk_pcursor_x, vk_pcursor_y)
			if vk_cursor_y == INTEXT then vk_pcursor_y = INTEXT end
		end
		if vk_cursor_y < INTEXT then
			self:invertVKey(vk_cursor_x, vk_cursor_y)
			vk_pcursor_x = vk_cursor_x
			vk_pcursor_y = vk_cursor_y
		end
	fb:refresh(1, 1, fb.bb:getHeight()-120, fb.bb:getWidth()-2, 120)
	end		
end

function InputBox:DrawVKey(key,x,y,face,rx,ry,t,c)
--	blitbuffer.paintBorder(fb.bb, x-10, y-ry-8, rx*2, ry*2, t, c, 0)
	renderUtf8Text(fb.bb, x, y, face, key, true)
end

-- this function is designed for K3 keyboard, portrait mode
-- TODO: support for other Kindle models & orientations?

function InputBox:DrawVirtualKeyboard()
	local vy = fb.bb:getHeight()-15
	-- dx, dy = xy-distance between the button rows
	-- lx - position of left button column
	-- r, c, t = radius, color and thickness of circles around chars
	-- h = y-correction to adjust cicles & chars
	local dx, dy, lx, r, c, bg, t = vk_dx, vk_dy, vk_lx, vk_r, vk_c, self.vk_bg, vk_t

	fb.bb:paintRect(0, fb.bb:getHeight()-120, fb.bb:getWidth(), 120, bg)
	-- font to draw characters - MUST have UTF8-support
	local vkfont = Font:getFace("infont", 22)
	for k,v in ipairs(self.INPUT_KEYS) do
		if v[1] >= KEY_Q and v[1] <= KEY_P then	-- upper raw
			self:DrawVKey(v[self.layout], lx+(v[1]-KEY_Q)*dx, vy-2*dy, vkfont, r, r, t, c)
		elseif v[1] >= KEY_A and v[1] <= KEY_L then	-- middle raw
			self:DrawVKey(v[self.layout], lx+(v[1]-KEY_A)*dx, vy-dy, vkfont, r, r, t, c)
		elseif v[1] >= KEY_Z and v[1] <= KEY_M then	-- lower raw
			self:DrawVKey(v[self.layout], lx+(v[1]-KEY_Z)*dx, vy, vkfont, r, r, t, c)
		elseif v[1] == KEY_DOT then
			self:DrawVKey(v[self.layout], lx + 7*dx, vy, vkfont, r, r, t, c)
		end
	end
	-- the rest symbols (manually)
	local smfont = Font:getFace("infont", 14)
	-- Del
--	blitbuffer.paintBorder(fb.bb, lx+9*dx-10, vy-dy-r-8, r*2, r*2, t, c, 0)
	renderUtf8Text(fb.bb, lx-5+9*dx, vy-dy-3, smfont, "Del", true)
	-- Sym - now replaced with Space by Kai771
--	blitbuffer.paintBorder(fb.bb, lx+8*dx-10, vy-r-8, r*2, r*2, t, c, 0)
	renderUtf8Text(fb.bb, lx-5+8*dx, vy-3, smfont, "Spc", true)
	-- Enter
--	blitbuffer.paintBorder(fb.bb, lx+9*dx-10, vy-r-8, r*2, r*2, t, c, 0)
	renderUtf8Text(fb.bb, lx-5+9*dx, vy-2, smfont, "Ent", true)
	-- Menu
--	blitbuffer.paintBorder(fb.bb, lx+10*dx-8, vy-2*dy-r-8, r+50, r*2, t, c, 0)
	renderUtf8Text(fb.bb, lx+10*dx+11, vy-2*dy-3, smfont, "Menu", true)
	-- fiveway
	local h=dy+2*r-2
	blitbuffer.paintBorder(fb.bb, lx+10*dx-8, vy-dy-r-6, h, h, 9, c, r)
	renderUtf8Text(fb.bb, lx+10*dx+22, vy-20, smfont, (self.layout-1), true)
	-- added for black keyboard
	fb.bb:invertRect(0, fb.bb:getHeight()-120, fb.bb:getWidth(), 120)
	if vk_cursor_y < 3 then self:invertVKey(vk_cursor_x, vk_cursor_y) end
	fb:refresh(1, 1, fb.bb:getHeight()-120, fb.bb:getWidth()-2, 120)
end

function InputBox:num(bool)
	return bool and 1 or 0
end

function InputBox:VKLayout(b1, b2, b3)
	return 2 + self:num(b1) + 2 * self:num(b2) + 4 * self:num(b3)
end

function InputBox:showLayoutMenu()
	local layout_menu_list = {
		"English - upper case",
		"English - lower case",
		"English - numbers",
		"English - symbols",
		"National - upper case",
		"National - lower case",
		"National - numbers",
		"National - symbols",
		}
	local layout_menu = SelectMenu:new{
		menu_title = "Select keyboard layout",
		item_array = layout_menu_list,
		current_entry = self.layout - 2
		}
	Screen:saveCurrentBB()
	local re = layout_menu:choose(0, G_height)
	Screen:restoreFromSavedBB()
	if re ~= nil then
		self:addCharCommands(re+1)
	end	
	fb:refresh(1)
end

function InputBox:addCharCommands(layout)
	-- at first, let's define self.layout and extract separate bits as layout modes
	if layout then
		-- to be sure layout is selected properly
		layout = math.max(layout, self.min_layout)
		layout = math.min(layout, self.max_layout)
		self.layout = layout

		-- filll the layout modes - modified by Kai771
		local tmp = (layout - 1) % 4
		self.shiftmode = (layout % 2 == 1)
		self.symbolmode = (tmp == 0 or tmp == 3)
		self.utf8mode = (self.layout > 5)
		
	else	-- or, without input parameter, restore layout from current layout modes
		layout = self:VKLayout(self.shiftmode, self.symbolmode, self.utf8mode)
		self.layout = layout
	end

	-- calculate what is the layout to use when pressing shift
	if layout % 2 == 0 then shift_layout = layout + 1 
	else shift_layout = layout - 1 end

	-- adding the commands
	for k,v in ipairs(self.INPUT_KEYS) do
		-- just redefining existing
		self.commands:add(v[1], nil, "A..Z", "enter character from virtual keyboard (VK)",
			function(self)
				self:addChar(v[layout])
			end
		)
		-- and commands for chars pressed with Shift
		self.commands:add(v[1], MOD_SHIFT, "A..Z", "enter capitalized VK-character",
			function(self)
				self:addChar(v[shift_layout])
			end
		)
	end
	self:DrawVirtualKeyboard()
end

function InputBox:StringToCharlist(text)
	if text == nill then return end
	-- clear
	self.charlist = {}
	self.charpos = 1
	local prevcharcode, charcode = 0
	for uchar in string.gfind(text, "([%z\1-\127\194-\244][\128-\191]*)") do
		charcode = util.utf8charcode(uchar)
		if prevcharcode then -- utf8
			self.charlist[#self.charlist + 1] = uchar
		end
		prevcharcode = charcode
	end
	self.input_string = self:CharlistToString()
	self.charpos = #self.charlist + 1
end

function InputBox:CharlistToString()
	local s, i = ""
	for i=1, #self.charlist do
		s = s .. self.charlist[i]
	end
	return s
end

function InputBox:addAllCommands()
	-- if already initialized, we (re)define only inputmode-dependent commands
	if self.commands then
		self:ModeDependentCommands()
		self:DrawVirtualKeyboard()
		return
	end
	self:setLayoutsTable()
	self.commands = Commands:new{}
	-- adding character commands
	self:addCharCommands(self.layout)
	-- adding the rest commands (independent of the selected layout)
	self.commands:add(KEY_H, MOD_ALT, "H",
		"show help page",
		function(self)
			self:showHelpPage(self.commands)
		end
	)
	self.commands:add(KEY_FW_LEFT, nil, "joypad left",
		"move cursor left",
		function(self)
			if vk_cursor_y == INTEXT then
				if self.charpos > 1 then 
					self.cursor:clear()
					self.charpos = self.charpos - 1
					if self.pos_on_screen > 1 then
						self.pos_on_screen = self.pos_on_screen - 1
						self.cursor:moveHorizontalAndDraw(-self.fwidth)
						fb:refresh(1, self.input_start_x-5, self.ypos, self.input_slot_w, self.h)
					else
						self.charposl = self.charposl - 1
						self.input_string = self:CharlistToString()
						self:refreshText()
						self.cursor:draw()
						fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
					end	
				end	
			else
				if vk_cursor_x > 0 then vk_cursor_x = vk_cursor_x - 1 else vk_cursor_x = 9 end
				self:updateVKCursor()
			end	
		end
	)
	self.commands:add(KEY_FW_LEFT, MOD_SHIFT, "left",
		"move cursor to the first position",
		function(self)
			if self.charpos > 1 then
				self:resetCursorPosAndRedraw()
			end
		end
	)
	self.commands:add(KEY_FW_RIGHT, nil, "joypad right",
		"move cursor right",
		function(self)
			if vk_cursor_y == INTEXT then
				if self.charpos <= #self.charlist then
					self.cursor:clear()
					self.charpos = self.charpos + 1
					if self.pos_on_screen < self.max_input_chars then
						self.cursor:moveHorizontalAndDraw(self.fwidth)
						self.pos_on_screen = self.pos_on_screen + 1
						fb:refresh(1, self.input_start_x-5, self.ypos, self.input_slot_w, self.h)
					else
						self.charposl = self.charposl + 1
						self.input_string = self:CharlistToString()
						self:refreshText()
						self.cursor:draw()
						fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
					end	
				end
			else	
				if vk_cursor_x < 9 then vk_cursor_x = vk_cursor_x + 1 else vk_cursor_x = 0 end
				self:updateVKCursor()
			end	
		end
	)
	self.commands:add(KEY_FW_RIGHT, MOD_SHIFT, "right",
		"move cursor to the last position",
		function(self)
			if self.charpos < #self.charlist then
				self.cursor:clear()
				self.charpos = #self.charlist + 1
				if self.charpos < self.max_input_chars then 
					self.pos_on_screen = self.charpos
					self.charposl = 1
				else
					self.pos_on_screen = self.max_input_chars
					self.charposl = self.charpos - self.max_input_chars + 1
				end
				self.cursor.x_pos = self.input_start_x - 3 + (self.fwidth * (self.pos_on_screen - 1))
				self.input_string = self:CharlistToString()
				self:refreshText()
				self.cursor:draw()
				fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
			end
		end
	)
	self.commands:add(KEY_DEL, nil, "Del",
		"delete one character",
		function(self)
			self:delChar()
		end
	)
	self.commands:add(KEY_DEL, MOD_SHIFT, "Del",
		"delete all characters (empty inputbox)",
		function(self)
			self:clearText()
		end
	)
	self.commands:addGroup("up/down", { Keydef:new(KEY_FW_DOWN, nil), Keydef:new(KEY_FW_UP, nil) },
		"previous/next VK-layout",
		function(self, keydef)
			if keydef.keycode == KEY_FW_DOWN then
				if vk_cursor_y > 0 then 
					vk_cursor_y = vk_cursor_y - 1
					self:updateVKCursor()
				end
			else -- KEY_FW_UP
				if vk_cursor_y < INTEXT then 
					vk_cursor_y = vk_cursor_y + 1
					self:updateVKCursor()
				end
			end
		end
	)
	self.commands:add(KEY_FW_PRESS, nil, "fw_press",
		"press virtual key",
		function(self)
			local k
			if vk_cursor_y < INTEXT then
				if vk_cursor_y == 2 and vk_cursor_x < 10 then 
					k = 1 + vk_cursor_x
				elseif vk_cursor_y == 1 and vk_cursor_x < 9 then
					k = 11 + vk_cursor_x
				elseif vk_cursor_y == 0 and vk_cursor_x < 8 then
					k = 20 + vk_cursor_x
				elseif vk_cursor_y == 0 and vk_cursor_x == 8 then	-- virtual Spc key
					self:addChar(" ")
					Debug("Virtual Space key pressed")
				elseif vk_cursor_y == 1 and vk_cursor_x == 9 then	-- virtual Del key
					self:delChar()
					Debug("Virtual Del key pressed")
				elseif vk_cursor_y == 0 and vk_cursor_x == 9 then	-- virtual Enter key
					Debug("Virtual Enter key pressed")
					if self.inputmode == MODE_CALC then
						self:EnterCalculate()
					else
						return self:EnterSubmit()
					end		
				end
				if k then
					self:addChar(self.INPUT_KEYS[k][self.layout])
					Debug("Virtual key", self.INPUT_KEYS[k][self.layout], " pressed")
				end	
			else
				if self.inputmode == MODE_CALC then
					self:EnterCalculate()
				else
					return self:EnterSubmit()
				end		
			end
		end
	)
	self.commands:add(KEY_AA, nil, "Aa",
		"toggle VK-layout: english <> national",
		function(self)
			self.utf8mode = not self.utf8mode
			self:addCharCommands()
		end
	)
	self.commands:add(KEY_SYM, nil, "Sym",
		"toggle VK-layout: chars <> symbols",
		function(self)
			self.symbolmode = not self.symbolmode
			self:addCharCommands()
		end
	)

	self.commands:add(KEY_MENU, nil, "Menu",
		"show Layout Menu",
		function(self)
			self:showLayoutMenu()
		end		
	)	
	
	-- NuPogodi, 02.06.12: inputmode-dependent commands are collected
	self:ModeDependentCommands() -- here

	self.commands:add(KEY_BACK, nil, "Back",
		"back",
		function(self)
			self.input_string = nil
			return "break"
		end
	)
end
-----------------------------------------------------------------
-- NuPogodi, 02.06.12: Some Help- & Calculator-related functions
-----------------------------------------------------------------
function InputBox:defineCalcFunctions() -- for the calculator documentation
	-- to initialize only once
	if self.calcfunctions then return end

	self.calcfunctions = Commands:new{}
	-- remove initially added commands
	self.calcfunctions:del(KEY_INTO_SCREEN_SAVER, nil, "Slider") 
	self.calcfunctions:del(KEY_OUTOF_SCREEN_SAVER, nil, "Slider")
	self.calcfunctions:del(KEY_CHARGING, nil, "plugin/out usb")
	self.calcfunctions:del(KEY_NOT_CHARGING, nil, "plugin/out usb")
	self.calcfunctions:del(KEY_P, MOD_SHIFT, "P")

	local s = " " -- space for function groups
	local a = 100 -- arithmetic functions
	self.calcfunctions:add(a-1, nil,	s:rep(1),	string.upper("Ariphmetic operators"))
	self.calcfunctions:add(a,   nil,	"+ -",		"addition: 1+2=3; substraction: 3-2=1")
	self.calcfunctions:add(a+1, nil,	"* /",		"multiplication: 2*2=4; division: 4/2=2")
	self.calcfunctions:add(a+3, nil,	"%",		"modulo (remainder): 5.2%2=1.2, π-π%0.01=3.14")
	local r = 200 -- relations
	self.calcfunctions:add(r-1, nil,	s:rep(2),	string.upper("Relational operators"))
	self.calcfunctions:add(r,   nil,	"< >",		"less: (2<3)=true; more: (2>3)=false")
	self.calcfunctions:add(r+1, nil,	"<=",		"less or equal: (3≤3)=true, (2≤1)=false")
	self.calcfunctions:add(r+2, nil,	">=",		"more or equal: (3≥3)=true, (1≥2)=false")
	self.calcfunctions:add(r+3, nil,	"==",		"equal: (3==3)=true, (1==2)=false")
	self.calcfunctions:add(r+4, nil,	"~=",		"not equal: (6~=8)=true, (3~=3)=false")
	local l = 300 -- logical
	self.calcfunctions:add(l-1, nil,	s:rep(3),	string.upper("Logical operators"))
	self.calcfunctions:add(l+0, nil,	"and, &",	"= logical 'and': (4 and 5)=5, (nil & 5)=nil")
	self.calcfunctions:add(l+1, nil,	"or, |",	"= logical 'or': (4 or 5)=4, (false | 5)=5")
	local c = 400 -- constants
	self.calcfunctions:add(c-1, nil,	s:rep(4),	string.upper("Some constants"))
	self.calcfunctions:add(c,   nil,	"pi, π",	"= 3.14159…; sin(π/2)=1, cos(π/2)=0")
	self.calcfunctions:add(c+1, nil,	"е, exp(1)",	"= 2.71828…; log(е)=1")
	local m = 500 -- mathematical
	self.calcfunctions:add(m-1, nil,	s:rep(5),	string.upper("Mathematic functions"))
	self.calcfunctions:add(m,   nil,	"abs(x)",	"absolute value of x: abs(1)=1, abs(-2)=2")
	self.calcfunctions:add(m+1, nil,	"ceil(x)",	"round to integer no less than x: ceil(0.4)=1")
	self.calcfunctions:add(m+2, nil,	"floor(x)",	"round to integer no greater than x: floor(0.4)=0")
	self.calcfunctions:add(m+3, nil,	"^, pow(x,y)","= power: 2^10=1024, pow(4,0.5)=2")
	self.calcfunctions:add(m+4, nil,	"exp(x), e^x","= exponent: exp(1)=2.71828…")
	self.calcfunctions:add(m+5, nil,	"log(x)",	"the natural logarithm: log(e)=1")
	self.calcfunctions:add(m+6, nil,	"log10(x)",	"the base 10 logarithm: log10(10)=1")
	self.calcfunctions:add(m+7, nil,	"max(x,…)",	"return maximal value: max(0,-1,2,1)=2")
	self.calcfunctions:add(m+8, nil,	"min(x,…)",	"return minimal value: min(0,-1,2,1)=-1")
	self.calcfunctions:add(m+9, nil,	"sqrt(x)",	"return square root: sqrt(4)=2")
	local t = 600 -- trigonometrical
	self.calcfunctions:add(t,   nil,	s:rep(6),	string.upper("Trigonometric functions"))
	self.calcfunctions:add(t+1, nil,	"deg(x)",	"convert radians to degrees: deg(π/2)=90")
	self.calcfunctions:add(t+2, nil,	"rad(x)",	"convert degrees to radians: rad(180)=3.14159…")
	self.calcfunctions:add(t+3, nil,	"sin(x)",	"sine for x given in radians: sin(π/2)=1")
	self.calcfunctions:add(t+4, nil,	"cos(x)",	"cosine for x given in radians: cos(π)=-1")
	self.calcfunctions:add(t+5, nil,	"tan(x)",	"tangent for x given in radians: tan(π/4)=1")
	self.calcfunctions:add(t+6, nil,	"asin(x)",	"inverse sine (in radians): asin(1)/π=0.5")
	self.calcfunctions:add(t+7, nil,	"acos(x)",	"inverse cosine (in radians): acos(0)/π=0.5")
	self.calcfunctions:add(t+8, nil,	"atan(x)",	"inverse tangent (in radians): atan(1)/π=0.25")
	self.calcfunctions:add(t+9, nil,	"atan2(x,y)",	"inverse tangent of two args: = atan(x/y)")
	local h = 700 -- hyperbolical
	self.calcfunctions:add(h,   nil,	s:rep(7),	string.upper("Hyperbolic functions"))
	self.calcfunctions:add(h+1, nil,	"sinh(x)",	"hyperbolic sine, (exp(x)-exp(-x))/2")
	self.calcfunctions:add(h+2, nil,	"cosh(x)",	"hyperbolic cosine, (exp(x)+exp(-x))/2")
	self.calcfunctions:add(h+3, nil,	"tanh(x)",	"hyperbolic tangent, sinh(x)/cosh(x)")
-- not yet documented > "fmod", "frexp", "huge", "ldexp", "modf", "randomseed", "random"
end

function InputBox:showHelpPage(list, title)
	-- make inactive input slot
	self.cursor:clear() -- hide cursor
	fb.bb:dimRect(self.input_start_x-5, self.input_start_y-19, self.input_slot_w, self.fheight, self.input_bg)
	fb:refresh(1, self.input_start_x-5, self.ypos, self.input_slot_w, self.h)
	HelpPage:show(0, fb.bb:getHeight()-165, list, title)
	-- on the help page-exit, making inactive helpage
	fb.bb:dimRect(0, 40, fb.bb:getWidth(), fb.bb:getHeight()-205, self.input_bg)
	-- and active input slot
	self:refreshText()
	self.cursor:draw() -- show cursor = ready to input
	fb:refresh(1)
end

function InputBox:setCalcMode()
	--clear previous input
	self.input_string = ""
	self.charlist = {}
	self.charpos = 1
	self.charposl = 1
	self.pos_on_screen = 1
	-- set proper layouts
	self.layout = 4 -- digits
	self.min_layout = 3
	self.max_layout = 4
end

function InputBox:PrepareStringToCalc()
	local s = string.lower(self.input_string)
	-- continue interpreting the input
	local mathe = {	"abs", "acos", "asin", "atan2", "atan", "ceil", "cosh", "cos",
				"deg", "exp", "floor", "fmod", "frexp", "huge", "ldexp", "log10", "log",
				"max", "min", "modf", "pi", "pow", "rad", "randomseed", "random",
				"sinh", "sin", "sqrt", "tanh", "tan", }
	-- to avoid any ambiguities (like sin & sinh), one has to replace by capitals
	for i=1, #mathe do
		s = string.gsub(s, mathe[i], string.upper("math."..mathe[i]))
	end
	-- some acronyms for constants & functions
	s = string.gsub(s, "π", " math.pi ")
	s = string.gsub(s, "е", " math.exp(1) ")
	s = string.gsub(s, "&", " and ")
	s = string.gsub(s, "|", " or ")
	-- return the whole string in lowercase and eventually replace double "math."
	return string.gsub(string.lower(s), "math.math.", "math.")
end

function InputBox:EnterSubmit()
	if self.input_string == "" then
		self.input_string = nil
	end
	return "break"
end

function InputBox:EnterCalculate()
	if #self.input_string == 0 then
		InfoMessage:inform("No user input ", DINFO_DELAY, 1, MSG_WARN)
	else
		local s = self:PrepareStringToCalc()
		if pcall(function () f = assert(loadstring("r = tostring("..s..")")) end) and pcall(f) then
			self:clearText()
			self.cursor:clear()
			for i=1, string.len(r) do
				table.insert(self.charlist, string.sub(r,i,i))
			end
			self.charpos = #self.charlist + 1
			self.input_cur_x = self.input_start_x + #self.charlist * self.fwidth
			self.input_string = r
			self:refreshText()
			self.cursor:moveHorizontal(#self.charlist*self.fwidth)
			self.cursor:draw()
			fb:refresh(1, self.input_start_x-5, self.input_start_y-25, self.input_slot_w, self.h-25)
		else
			InfoMessage:inform("Invalid user input ", DINFO_DELAY, 1, MSG_WARN)
		end -- if pcall
	end
end

-- define whether we need to calculate the result or to return 'self.input_string'
function InputBox:ModeDependentCommands()
	if self.inputmode == MODE_CALC then
		-- define what to do with the input_string
		self.commands:add(KEY_ENTER, nil, "Enter",
			"calculate the result",
			function(self)
				self:EnterCalculate()
			end -- function
			)
		-- add the calculator help (short list of available functions)
		-- or, might be better, to make some help document and open it in reader ??
		self.commands:add(KEY_M, MOD_ALT, "M",
			"math functions available in calculator",
			function(self)
				self:defineCalcFunctions()
				self:showHelpPage(self.calcfunctions, "Math Functions for Calculator")
			end
			)
	else 	-- return input_string & close input box
		self.commands:add(KEY_ENTER, nil, "Enter",
			"submit input content",
			function(self)
				return self:EnterSubmit()
			end
			)
		-- delete calculator-specific help
		self.commands:del(KEY_M, MOD_ALT, "M")
	end -- if self.inputmode
end

----------------------------------------------------
-- Inputbox for numbers only
-- Designed by eLiNK
----------------------------------------------------

NumInputBox = InputBox:new{
	layout = 4,
	charlist = {},
}
