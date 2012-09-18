require "unireader"

DJVUReader = UniReader:new{}

function DJVUReader:open(filename)
	local ok
	ok, self.doc = pcall(djvu.openDocument, filename)
	if not ok then
		return ok, self.doc -- this will be the error message instead
	end
	return ok
end

function DJVUReader:init()
	self:addAllCommands()
	self:adjustDjvuReaderCommand()
end

function DJVUReader:adjustDjvuReaderCommand()
	self.commands:del(KEY_J, MOD_SHIFT, "J")
	self.commands:del(KEY_K, MOD_SHIFT, "K")
	self.commands:add(KEY_R, nil, "R",
		"select djvu page rendering mode",
		function(self)
			self:select_render_mode()
	end) 
end

-- select the rendering mode from those supported by djvulibre.
-- Note that if the values in the definition of ddjvu_render_mode_t in djvulibre/libdjvu/ddjvuapi.h change,
-- then we should update our values here also. This is a bit risky, but these values never change, so it should be ok :)
function DJVUReader:select_render_mode()
	local mode_menu = SelectMenu:new{
		menu_title = "Select DjVu page rendering mode",
		item_array = {
			"COLOUR (works for both colour and b&w pages)",		--  0  (colour page or stencil)
			"BLACK & WHITE (for b&w pages only, much faster)",	--  1  (stencil or colour page)
			"COLOUR ONLY (slightly faster than COLOUR)",		--  2  (colour page or fail)
			"MASK ONLY (for b&w pages only)",					--  3  (stencil or fail)
			"COLOUR BACKGROUND (show only background)",			--  4  (colour background layer)
			"COLOUR FOREGROUND (show only foreground)"			--  5  (colour foreground layer)
			},
		current_entry = self.render_mode,
	}
	local mode = mode_menu:choose(0, fb.bb:getHeight()) 
	if mode then
		self.render_mode = mode - 1
		self:clearCache()
	end
	self:redrawCurrentPage()
end

----------------------------------------------------
-- highlight support 
----------------------------------------------------
function DJVUReader:getText(pageno)
	return self.doc:getPageText(pageno)
end

-- for incompatible API fixing
function DJVUReader:invertTextYAxel(pageno, text_table)
	local _, height = self.doc:getOriginalPageSize(pageno)
	for _,text in pairs(text_table) do
		for _,line in ipairs(text) do
			line.y0, line.y1 = (height - line.y1), (height - line.y0)
		end
	end
	return text_table
end

-- used in DJVUReader:showMenu()
function DJVUReader:_drawReadingInfo()
	local width, height = G_width, G_height
	local load_percent = (self.pageno / self.doc:getPages())
	-- changed to be the same font group as originaly intended
	local face = Font:getFace("rifont", 20)
	local page_width, page_height = self.doc:getOriginalPageSize(self.pageno)

	-- display memory on top of page
	fb.bb:paintRect(0, 0, width, 15+6*2, 0)
	renderUtf8Text(fb.bb, 10, 15+6, face,
		"M: "..
		math.ceil(self.cache_current_memsize/1024).."/"..
		math.ceil(self.cache_max_memsize/1024).."K "..
		tostring(page_width).."x"..tostring(page_height).." "..
		os.date("%a %d %b %Y %T").." ["..BatteryLevel().."]",
	true)

	-- display reading progress on bottom of page
	local ypos = height - 50
	fb.bb:paintRect(0, ypos, width, 50, 0)
	ypos = ypos + 15
	local cur_section = self:getTocTitleOfCurrentPage()
	if cur_section ~= "" then
		cur_section = "Sec: "..cur_section
	end
	renderUtf8Text(fb.bb, 10, ypos+6, face,
		"Page: "..self.pageno.."/"..self.doc:getPages()..
		"    "..cur_section, true)

	ypos = ypos + 15
	blitbuffer.progressBar(fb.bb, 10, ypos, width-20, 15,
							5, 4, load_percent, 8)
end

function DJVUReader:showMenu()
	self:_drawReadingInfo()

	fb:refresh(1)
	while 1 do
		local ev = input.saveWaitForEvent()
		ev.code = adjustKeyEvents(ev)
		if ev.type == EV_KEY and ev.value == EVENT_VALUE_KEY_PRESS then
			if ev.code == KEY_BACK or ev.code == KEY_MENU then
				return
			elseif ev.code == KEY_C then
				self:clearCache()
			end
		end
	end
end
