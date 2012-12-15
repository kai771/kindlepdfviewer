require "unireader"
require "lbrstrings"

DJVUReader = UniReader:new{}

function DJVUReader:setDefaults()
	self.show_overlap_enable = DDJVUREADER_SHOW_OVERLAP_ENABLE
	self.show_links_enable = DDJVUREADER_SHOW_LINKS_ENABLE
	self.comics_mode_enable = DDJVUREADER_COMICS_MODE_ENABLE
	self.rtl_mode_enable = DDJVUREADER_RTL_MODE_ENABLE
	self.page_mode_enable = DDJVUREADER_PAGE_MODE_ENABLE
end

-- check DjVu magic string to validate
function validDJVUFile(filename)
	f = io.open(filename, "r")
	if not f then return false end
	local magic = f:read(8)
	f:close()
	if not magic or magic ~= "AT&TFORM" then return false end
	return true
end

-- open a DJVU file and its settings store
-- DJVU does not support password yet
function DJVUReader:open(filename)
	if not validDJVUFile(filename) then
		return false, SNot_a_valid_DjVu_file
	end

	local ok
	ok, self.doc = pcall(djvu.openDocument, filename, self.cache_document_size)
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
		Sselect_djvu_page_rendering_mode,
		function(self)
			self:select_render_mode()
	end) 
end

-- select the rendering mode from those supported by djvulibre.
-- Note that if the values in the definition of ddjvu_render_mode_t in djvulibre/libdjvu/ddjvuapi.h change,
-- then we should update our values here also. This is a bit risky, but these values never change, so it should be ok :)
function DJVUReader:select_render_mode()
	local mode_menu = SelectMenu:new{
		menu_title = SSelect_DjVu_page_rendering_mode_,
		item_array = {
			SCOLOUR_works_for_both_colour_and_bw_pages_,		--  0  (colour page or stencil)
			SBLACK_N_WHITE_for_bw_pages_only_much_faster_,	--  1  (stencil or colour page)
			SCOLOUR_ONLY_slightly_faster_than_colour_,			--  2  (colour page or fail)
			SMASK_ONLY_for_bw_pages_only_,									--  3  (stencil or fail)
			SCOLOUR_BACKGROUND_show_only_background_,				--  4  (colour background layer)
			SCOLOUR_FOREGROUND_show_only_foreground_,				--  5  (colour foreground layer)
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

function render_mode_string(rm)
	if (rm == 0) then
		return "COLOUR"
	elseif (rm == 1) then
		return "B&W"
	elseif (rm == 2) then
		return "COLOUR ONLY"
	elseif (rm == 3) then
		return "MASK ONLY"
	elseif (rm == 4) then
		return "COLOUR BG"
	elseif (rm == 5) then
		return "COLOUR FG"
	else
		return "UNKNOWN"
	end
end

function DJVUReader:_drawReadingInfo()
	local width, height = G_width, G_height
	local numpages = self.doc:getPages()
	local load_percent = self.pageno/numpages
	local face = Font:getFace("rifont", 20)
	local rss, data, stack, lib, totalvm = memUsage()
	local page_width, page_height, page_dpi, page_gamma, page_type = self.doc:getPageInfo(self.pageno)

	-- display memory, time, battery and DjVu info on top of page
	fb.bb:paintRect(0, 0, width, 60+6*2, 0)
	renderUtf8Text(fb.bb, 10, 15+6, face,
		"M: "..
		math.ceil( self.cache_current_memsize / 1024 ).."/"..math.ceil( self.cache_max_memsize / 1024 ).."k "..
		math.ceil( self.doc:getCacheSize() / 1024 ).."/"..math.ceil( self.cache_document_size / 1024 ).."k", true)
	local txt = os.date("%a %d %b %Y %T").." ["..BatteryLevel().."]"
	local w = sizeUtf8Text(0, width, face, txt, true).x
	renderUtf8Text(fb.bb, width - w - 10, 15+6, face, txt, true)
	renderUtf8Text(fb.bb, 10, 15+6+22, face,
	"RSS:"..rss.." DAT:"..data.." STK:"..stack.." LIB:"..lib.." TOT:"..totalvm.."k", true)
	renderUtf8Text(fb.bb, 10, 15+6+44, face,
		"Gm:"..string.format("%.1f",self.globalgamma).." ["..tostring(page_gamma).."], "..
		tostring(page_width).."x"..tostring(page_height)..", "..
		string.format("%.1fx, ", self.globalzoom)..
		tostring(page_dpi).."dpi, "..page_type..", "..
		render_mode_string(self.render_mode), true)

	-- display reading progress on bottom of page
	local ypos = height - 50
	fb.bb:paintRect(0, ypos, width, 50, 0)
	ypos = ypos + 15
	local cur_section = self:getTocTitleOfCurrentPage()
	if cur_section ~= "" then
		cur_section = "Sec: "..cur_section
	end
	renderUtf8Text(fb.bb, 10, ypos+6, face,
		"p."..self.pageno.."/"..numpages.."   "..cur_section, true)

	ypos = ypos + 15
	blitbuffer.progressBar(fb.bb, 10, ypos, width-20, 15,
							5, 4, load_percent, 8)
end
