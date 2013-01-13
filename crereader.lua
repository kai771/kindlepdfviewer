require "font"
require "unireader"
require "inputbox"
require "selectmenu"
require "dialog"
require "lbrstrings"

CREReader = UniReader:new{
	pos = nil,
	percent = 0,

	gamma_index = 15,
	font_face = nil,
	page_header_font = DCREREADER_PAGE_HEADER_FONT,
	default_font = DCREREADER_DEFAULT_FONT,
	font_zoom = 0,
	default_font_zoom = 0,
	fonts_menu_cur = 0,

	line_space_percent = 100,
	default_line_space_percent = 100,
	view_mode = DCREREADER_VIEW_MODE,
	view_pan_step = nil,
}

function CREReader:init()
	self:addAllCommands()
	self:adjustCreReaderCommands()

	-- initialize cache and hyphenation engine
	cre.initCache(1024*1024*64)
	-- we need to initialize the CRE font list
	local fonts = Font:getFontList()
	for _k, _v in ipairs(fonts) do
		if _v ~= "Dingbats.cff" and _v ~= "StandardSymL.cff" then
			local ok, err = pcall(cre.registerFont, Font.fontdir..'/'.._v)
			if not ok then
				Debug(err)
			end
		end
	end

	local cre_header_enable = G_reader_settings:readSetting("cre_header_enable")
	if cre_header_enable ~= nil then self.cre_header_enable = cre_header_enable end

	local page_header_font = G_reader_settings:readSetting("page_header_font")
	if page_header_font then self.page_header_font = page_header_font end

	local default_font = G_reader_settings:readSetting("cre_font")
	if default_font then self.default_font = default_font end

	local default_font_zoom = G_reader_settings:readSetting("font_zoom")
	if default_font_zoom then self.default_font_zoom = default_font_zoom end

	local default_line_space_percent = G_reader_settings:readSetting("line_space_percent")
	if default_line_space_percent then self.default_line_space_percent = default_line_space_percent end
	
	if G_width > G_height then
		-- in landscape mode, crengine will render in two column mode
		self.view_pan_step = G_height * 2
	else
		self.view_pan_step = G_height
	end
end

-- inspect the zipfile content
function CREReader:ZipContentExt(fname)
	local i, s = 1
	local tmp = io.popen('unzip -l \"'..fname..'\"', "r")
	while true do
		s = tmp:read("*line")
		if i > 3 then tmp:close(); break; end
		i = i + 1
	end
	if s then
		local ext = string.match(s, ".+%.([^.]+)")
		if ext then
			ext = string.lower(ext)
			return ext
		end
	end
	return nil
end

-- open a CREngine supported file and its settings store
function CREReader:open(filename)
	local ok
	local file_type = string.lower(string.match(filename, ".+%.([^.]+)") or "")
	-- check zips for potential problems - wrong zip & wrong content
	if file_type == "zip" then
		file_type = self:ZipContentExt(filename)
	end
	if not file_type then
		return false, SError_unzipping_file_
	end
	-- if the zip entry is not cre-document
	if ReaderChooser:getReaderByType(file_type) ~= CREReader then
		return false, SZip_contains_improper_content_
	end
	-- these two format use the same css file
	if file_type == "html" then
		file_type = "htm"
	end
	-- if native css-file doesn't exist, one needs to use default cr3.css
	if not io.open("./data/"..file_type..".css") then
		file_type = "cr3"
	end
	local style_sheet = "./data/"..file_type..".css"
	-- default to scroll mode, which is 0
	-- this is defined in kpvcrlib/crengine/crengine/include/lvdocview.h
	local view_mode = self.view_mode
	
	ok, self.doc = pcall(cre.openDocument, filename, style_sheet, G_width, G_height, view_mode)
	if not ok then
		return false, SError_opening_cre_document_ -- self.doc, will contain error message
	end
--	self.doc:setDefaultInterlineSpace(self.line_space_percent)
	return true
end

----------------------------------------------------
-- setting related methods
----------------------------------------------------
function CREReader:preLoadSettings(filename)
	self.settings = DocSettings:open(filename)
	local view_mode = self.settings:readSetting("view_mode")
	if view_mode then self.view_mode = view_mode
	else self.view_mode = DCREREADER_VIEW_MODE end	
end

function CREReader:loadSpecialSettings()
	local font_face = self.settings:readSetting("font_face")
	if font_face then self.font_face = font_face
	else self.font_face = DCREREADER_DEFAULT_FONT end
	self.doc:setFontFace(self.font_face)
	
	self.doc:setCHFont(self.page_header_font)
	
	local info
	if self.cre_header_enable then info = DCREREADER_PAGE_HEADER
	else info = PGHDR_NONE end
	self.doc:setCHInfo(info)

	local gamma_index = self.settings:readSetting("gamma_index")
	self.gamma_index = gamma_index or self.gamma_index
	cre.setGammaIndex(self.gamma_index)

	local line_space_percent = self.settings:readSetting("line_space_percent")
	self.line_space_percent = line_space_percent or self.default_line_space_percent
	self.doc:setDefaultInterlineSpace(self.line_space_percent)

	local font_zoom = self.settings:readSetting("font_zoom")
	self.font_zoom = font_zoom or self.default_font_zoom
	if self.font_zoom ~= 0 then
		local i = math.abs(self.font_zoom)
		local step = self.font_zoom / i
		while i>0 do
			self.doc:zoomFont(step)
			i=i-1
		end
	end
end

function CREReader:getLastPageOrPos()
--[[ Old method doesn't give as "as you left it" feel
	local last_percent = self.settings:readSetting("last_percent")
	if last_percent then
		return math.floor((last_percent * self.doc:getFullHeight()) / 10000)
	else
		return 0
	end
--]]	
	local last_pos = self.settings:readSetting("last_pos")
	if last_pos then
		return last_pos
	else
		return 0
	end
end

function CREReader:saveSpecialSettings()
	self.settings:saveSetting("font_face", self.font_face)
	self.settings:saveSetting("gamma_index", self.gamma_index)
	self.settings:saveSetting("line_space_percent", self.line_space_percent)
	self.settings:saveSetting("font_zoom", self.font_zoom)
	self.settings:saveSetting("view_mode", self.view_mode)
end

function CREReader:saveLastPageOrPos()
	self.settings:saveSetting("last_percent", self.percent)
	self.settings:saveSetting("last_pos", self.pos)
end

----------------------------------------------------
-- render related methods
----------------------------------------------------
-- we don't need setzoom in CREReader
function CREReader:setzoom(page, preCache)
	return
end

function CREReader:redrawCurrentPage()
	self:goto(self.pos)
end

-- there is no zoom mode in CREReader
function CREReader:setGlobalZoomMode()
	return
end

----------------------------------------------------
-- goto related methods
----------------------------------------------------
function CREReader:goto(pos, is_ignore_jump, pos_type)
	local prev_xpointer = self.doc:getXPointer()
	local width, height = G_width, G_height
	local battery_level = BatteryLevel()
	battery_level = string.gsub(battery_level, "%%", "")	
	if battery_level and pcall(function () battery_level = battery_level + 0 end) then
		-- battery_level is a number. All is good.
	else
		-- battery_level is not a number. Set it to 0.
		battery_level = 0
	end		
	self.doc:setBatteryState(battery_level)
	
	if pos_type == "xpointer" then
		self.doc:gotoXPointer(pos)
	elseif pos_type == "link" then
		self.doc:gotoLink(pos)
	elseif pos_type == "page" and self.view_mode == CRE_VM_PAGE then
		self.doc:gotoPage(pos)	
	else -- pos_type is position within document
		pos = math.min(pos, self.doc:getFullHeight() - height)
		pos = math.max(pos, 0)
		self.doc:gotoPos(pos)
	end
	pos = self.doc:getCurrentPos() -- added by @Kai771
	-- add to jump history, distinguish jump from normal page turn
	-- NOTE:
	-- even though we have called gotoPos() or gotoXPointer() previously,
	-- self.pos hasn't been updated yet here, so we can still make use of it.
	if not is_ignore_jump then
		if self.pos and math.abs(self.pos - pos) > height then
			self:addJump(prev_xpointer)
		end
	end
	self.doc:drawCurrentPage(self.nulldc, fb.bb)

	Debug("## self.show_overlap "..self.show_overlap)
	if self.show_overlap < 0
	and self.show_overlap_enable
	and self.view_mode ~= "page" then
		fb.bb:dimRect(0,0, width, -self.show_overlap)
	elseif self.show_overlap > 0
	and self.show_overlap_enable 
	and self.view_mode ~= "page" then
		fb.bb:dimRect(0,height - self.show_overlap, width, self.show_overlap)
	end
	self.show_overlap = 0

	if self.rcount >= self.rcountmax then
		Debug("full refresh")
		self.rcount = 0
		fb:refresh(0)
	else
		Debug("partial refresh")
		self.rcount = self.rcount + 1
		fb:refresh(1)
	end

	self.pos = pos
	self.pageno = self.doc:getCurrentPage()
	self.percent = self.doc:getCurrentPercent()
end

function CREReader:gotoJump(pos, is_ignore_jump, pos_type)
	self:goto(pos, is_ignore_jump, pos_type)
end

function CREReader:gotoPercent(percent)
	self:goto(percent * self.doc:getFullHeight() / 10000)
end

function CREReader:gotoTocEntry(entry)
	self:goto(entry.xpointer, nil, "xpointer")
end

function CREReader:nextView()
	if self.view_mode == CRE_VM_SCROLL then
		self.show_overlap = -self.pan_overlap_vertical
		return self.pos + self.view_pan_step - self.pan_overlap_vertical
	else
		return self.pageno + 1
	end	
end

function CREReader:prevView()
	if self.view_mode == CRE_VM_SCROLL then
		self.show_overlap = self.pan_overlap_vertical
		return self.pos - self.view_pan_step + self.pan_overlap_vertical
	else
		return self.pageno - 1
	end	
end

----------------------------------------------------
-- jump history related methods
----------------------------------------------------
function CREReader:isSamePage(p1, p2)
	return self.doc:getPageFromXPointer(p1) == self.doc:getPageFromXPointer(p2)
end

function CREReader:showJumpHist()
	local menu_items = {}
	for k,v in ipairs(self.jump_history) do
		if k == self.jump_history.cur then
			cur_sign = "*(Cur) "
		else
			cur_sign = ""
		end
		table.insert(menu_items,
			cur_sign..v.datetime.." -> Page "
			..self.doc:getPageFromXPointer(v.page).." "..v.notes)
	end

	if #menu_items == 0 then
		InfoMessage:inform(SNo_jump_history_found_, DINFO_DELAY, 1, MSG_WARN)
	else
		-- if cur points to head, draw entry for current page
		if self.jump_history.cur > #self.jump_history then
			table.insert(menu_items,
				SCurrent_page_..self.pageno)
		end

		jump_menu = SelectMenu:new{
			menu_title = SJump_History,
			item_array = menu_items,
		}
		item_no = jump_menu:choose(0, G_height)
		if item_no and item_no <= #self.jump_history then
			local jump_item = self.jump_history[item_no]
			self.jump_history.cur = item_no
			self:goto(jump_item.page, true, "xpointer")
		else
			self:redrawCurrentPage()
		end
	end
end

----------------------------------------------------
-- bookmarks related methods
----------------------------------------------------
function CREReader:isBookmarkInSequence(a, b)
	return self.doc:getPosFromXPointer(a.page) < self.doc:getPosFromXPointer(b.page)
end

function CREReader:nextBookMarkedPage()
	for k,v in ipairs(self.bookmarks) do
		if self.pos < self.doc:getPosFromXPointer(v.page) then
			return v
		end
	end
	return nil
end

function CREReader:prevBookMarkedPage()
	local pre_item = nil
	for k,v in ipairs(self.bookmarks) do
		if self.pos <= self.doc:getPosFromXPointer(v.page) then
			if not pre_item then
				break
			elseif self.doc:getPosFromXPointer(pre_item.page) < self.pos then
				return pre_item
			end
		end
		pre_item = v
	end
	return pre_item
end

function CREReader:showBookMarks()
	local menu_items = {}
	local ret_code, item_no = -1, -1

	-- build menu items
	for k,v in ipairs(self.bookmarks) do
		table.insert(menu_items,
			SPage_..self.doc:getPageFromXPointer(v.page)
			.." "..v.notes.." @ "..v.datetime)
	end
	if #menu_items == 0 then
		return InfoMessage:inform(SNo_bookmarks_found_, DINFO_DELAY, 1, MSG_WARN)
	end
	while true do
		local bkmk_menu = SelectMenu:new{
			menu_title = SBookmarks.." ("..tostring(#menu_items)..S_items..")",
			item_array = menu_items,
			deletable = true,
		}
		ret_code, item_no = bkmk_menu:choose(0, G_height)
		if ret_code then -- normal item selection
			return self:goto(self.bookmarks[ret_code].page, nil, "xpointer")
		elseif item_no then -- delete item
			table.remove(menu_items, item_no)
			table.remove(self.bookmarks, item_no)
			if #menu_items == 0 then
				return self:redrawCurrentPage()
			end
		else -- return via Back
			return self:redrawCurrentPage()
		end
	end
end

----------------------------------------------------
-- TOC related methods
----------------------------------------------------
function CREReader:getTocTitleByPage(page_or_xpoint)
	local page = 1
	-- tranform xpointer to page
	if type(page_or_xpoint) == "string" then
		page = self.doc:getPageFromXPointer(page_or_xpoint)
	else
		page = page_or_xpoint
	end
	return self:_getTocTitleByPage(page)
end

function CREReader:getTocTitleOfCurrentPage()
	return self:getTocTitleByPage(self.doc:getXPointer())
end

--[[ function to scroll chapters without calling TOC-menu,
direction is either +1 (next chapter) or -1 (previous one).
Jump over several chapters is principally possible when direction > 1 ]]

function CREReader:gotoPrevNextTocEntry(direction)
	if not self.toc then
		self:fillToc()
	end
	if #self.toc == 0 then
		InfoMessage:inform(SNo_Table_of_Contents_, DINFO_DELAY, 1, MSG_WARN)
		return
	end
	-- search for current TOC-entry
	local item_no = 0
	for k,v in ipairs(self.toc) do
		if v.page <= self.pageno then
			item_no = item_no + 1
		else
			break
		end
	end
	-- minor correction when current page is not the page opening current chapter
	if self.pageno > self.toc[item_no].page and direction < 0 then
		direction = direction + 1
	end
	-- define the jump target
	item_no = item_no + direction
	if item_no > #self.toc then -- jump to last page
		self:goto(self.doc:getFullHeight()-G_height)
	elseif item_no > 0 then
		self:gotoTocEntry(self.toc[item_no])
	else
		self:goto(0) -- jump to first page
	end
end

----------------------------------------------------
-- menu related methods
----------------------------------------------------
-- used in CREReader:showInfo()
function CREReader:_drawReadingInfo()
	local width = G_width
	local load_percent = self.percent/100
	local rss, data, stack, lib, totalvm = memUsage()
	local face = Font:getFace("rifont", 20)

	-- display page number, date and memory stats at the top
	fb.bb:paintRect(0, 0, width, 40+6*2, 0)
	renderUtf8Text(fb.bb, 10, 15+6, face, "p."..self.pageno.."/"..self.doc:getPages(), true)
	local txt = os.date("%a %d %b %Y %T").." ["..BatteryLevel().."]"
	local w = sizeUtf8Text(0, width, face, txt, true).x
	renderUtf8Text(fb.bb, width - w - 10, 15+6, face, txt, true)
	renderUtf8Text(fb.bb, 10, 15+6+22, face,
		"RSS:"..rss.." DAT:"..data.." STK:"..stack.." LIB:"..lib.." TOT:"..totalvm.."k", true)

	-- display reading progress at the bottom
	local ypos = G_height - 50
	fb.bb:paintRect(0, ypos, width, 50, 0)

	ypos = ypos + 15

	local cur_section = self:getTocTitleOfCurrentPage()
	if cur_section ~= "" then
		cur_section = "  Sec: "..cur_section
	end
	local footer = load_percent.."%"..cur_section
	if sizeUtf8Text(10, fb.bb:getWidth(), face, footer, true).x < (fb.bb:getWidth() - 20) then
		renderUtf8Text(fb.bb, 10, ypos+6, face, footer, true)
	else
		local gapx = sizeUtf8Text(10, fb.bb:getWidth(), face, "...", true).x
		gapx = 10 + renderUtf8TextWidth(fb.bb, 10, ypos+6, face, footer, true, fb.bb:getWidth() - 30 - gapx).x
		renderUtf8Text(fb.bb, gapx, ypos+6, face, "...", true)
	end
	ypos = ypos + 15
	blitbuffer.progressBar(fb.bb, 10, ypos, width - 20, 15, 5, 4, load_percent/100, 8)
end

function CREReader:showInfo()
	if DCREREADER_HEADER_ON_HOME then
		self:toggleCREHeader()
		G_reader_settings:saveSetting("cre_header_enable", self.cre_header_enable)
	else	
		self:_drawReadingInfo()
		fb:refresh(1)
		while true do
			local ev = input.saveWaitForEvent()
			ev.code = adjustKeyEvents(ev)
			if ev.type == EV_KEY and ev.value == EVENT_VALUE_KEY_PRESS then
				if ev.code == KEY_BACK or ev.code == KEY_HOME then
					return
				end
			end
		end
	end	
end

function CREReader:toggleCREHeader()
	if self.view_mode == CRE_VM_PAGE then
		self.cre_header_enable = not self.cre_header_enable
		local info
		if self.cre_header_enable then info = DCREREADER_PAGE_HEADER
		else info = PGHDR_NONE end
	--	local prev_xpointer = self.doc:getXPointer()	
		self.doc:setCHInfo(info)
	--	self:goto(prev_xpointer, nil, "xpointer")
	else
		InfoMessage:inform(SView_mode_not_page_, DINFO_DELAY, 1, MSG_WARN)
	end	
end

function CREReader:toggleViewMode()
	local view_mode
	if self.view_mode == CRE_VM_PAGE then
		self.view_mode = CRE_VM_SCROLL
		view_mode = "scroll"
	else
		self.view_mode = CRE_VM_PAGE
		view_mode = "page"
	end
	local prev_xpointer = self.doc:getXPointer()
	InfoMessage:inform(SViewmode_..view_mode, DINFO_TOGGLES, 1, MSG_AUX)
	self.doc:setCREViewMode(self.view_mode)
	self:goto(prev_xpointer, nil, "xpointer")
end

function CREReader:startHighLightMode()
	self:redrawCurrentPage()
	InfoMessage:inform(SNot_supported_for_this_doc_type, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:showHighLight()
	self:redrawCurrentPage()
	InfoMessage:inform(SNot_supported_for_this_doc_type, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:showZoomModeMenu()
	self:redrawCurrentPage()
	InfoMessage:inform(SNot_supported_for_this_doc_type, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:fpOffsetInput()
	self:redrawCurrentPage()
	InfoMessage:inform(SNot_supported_for_this_doc_type, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:modBBox()
	self:redrawCurrentPage()
	InfoMessage:inform(SNot_supported_for_this_doc_type, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:removeBBox()
	self:redrawCurrentPage()
	InfoMessage:inform(SNot_supported_for_this_doc_type, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:doAdjustGamma()
	InfoMessage:inform(SPress_left_right_to_adjust_gamma, DINFO_NODELAY, 1, MSG_AUX)
	while true do
		local ev = input.saveWaitForEvent()
		ev.code = adjustKeyEvents(ev)
		if ev.type == EV_KEY and ev.value ~= EVENT_VALUE_KEY_RELEASE then
			Debug("key pressed: "..tostring(keydef))
			if ev.code == KEY_FW_LEFT then self:incDecGamma(-1)
			elseif ev.code == KEY_FW_RIGHT then self:incDecGamma(1)
			else 
				InfoMessage:inform(SGamma_adjusted, DINFO_DELAY, 1, MSG_AUX)
				return nil 
			end
		end	
	end	
end

function CREReader:incDecGamma(delta)
	Debug("incDecGamma, gamma=", self.gamma_index, " delta=", delta)
	if self.gamma_index + delta > 0 then self.gamma_index = self.gamma_index + delta end
	if DINFO_GAMMA_CHANGE_SHOW then
		InfoMessage:inform(SNew_gamma_is__..self.gamma_index, DINFO_NODELAY, 1, MSG_AUX)
	end	
	cre.setGammaIndex(self.gamma_index)
	self:redrawCurrentPage()
end

function CREReader:showFontsMenu()
	local fonts_menu_list = {
		SChange_document_font_,
		SFont_size_n_spacing_,
		SToggle_bold_normal,
		SSet_current_settings_as_default,
		SChange_page_header_font_,
		}
	local fonts_menu = SelectMenu:new{
		menu_title = SLibrerator_Fonts_Menu,
		item_array = fonts_menu_list,
		current_entry = self.fonts_menu_cur
		}
	local re = fonts_menu:choose(0, G_height)
	Debug("Fonts menu: selected item ", tostring(re))
	if re ~= nil then self.fonts_menu_cur = re - 1 end
	if re == 1 then 
		self:redrawCurrentPage()
		self:changeDocFont()
	elseif re == 2 then
		self:redrawCurrentPage()
		self:doIncDecFontSizeSpacing()
	elseif re == 3 then
		self:redrawCurrentPage()
		self:toggleBoldNormal()
	elseif re == 4 then
		self:redrawCurrentPage()
		self:setDocFontAsDefault()
	elseif re == 5 then
		self:redrawCurrentPage()
		self:changeHeaderFont()
	end
end

function CREReader:changeDocFont()
	local face_list = cre.getFontFaces()
	-- define the current font in face_list 
	local item_no = 0
	while face_list[item_no] ~= self.font_face and item_no < #face_list do 
		item_no = item_no + 1 
	end
	local fonts_menu = SelectMenu:new{
		menu_title = SFonts_Menu_,
		item_array = face_list, 
		current_entry = item_no - 1,
	}
	item_no = fonts_menu:choose(0, G_height)
	local prev_xpointer = self.doc:getXPointer()
	if item_no then
		Debug(face_list[item_no])
		InfoMessage:inform(SRedrawing_with_..face_list[item_no].." ", DINFO_NODELAY, 1, MSG_AUX)
		self.doc:setFontFace(face_list[item_no])
		self.font_face = face_list[item_no]
	end
	self:goto(prev_xpointer, nil, "xpointer")
end

function CREReader:changeHeaderFont()
	local face_list = cre.getFontFaces()
	-- define the current font in face_list 
	local item_no = 0
	while face_list[item_no] ~= self.font_face and item_no < #face_list do 
		item_no = item_no + 1 
	end
	local fonts_menu = SelectMenu:new{
		menu_title = SFonts_Menu_,
		item_array = face_list, 
		current_entry = item_no - 1,
	}
	item_no = fonts_menu:choose(0, G_height)
	local prev_xpointer = self.doc:getXPointer()
	if item_no then
		Debug(face_list[item_no])
		self.page_header_font = face_list[item_no]
		G_reader_settings:saveSetting("page_header_font", self.page_header_font)
		self.doc:setCHFont(self.page_header_font)
	end
	self:goto(prev_xpointer, nil, "xpointer")
end

function CREReader:setDocFontAsDefault()
	self.default_font = self.font_face
	G_reader_settings:saveSetting("cre_font", self.font_face)
	G_reader_settings:saveSetting("font_zoom", self.font_zoom)
	G_reader_settings:saveSetting("line_space_percent", self.line_space_percent)
	self.default_font = self.font_face
	self.default_font_zoom = self.font_zoom
	self.default_line_space_percent = self.line_space_percent
	InfoMessage:inform(SDefault_font_n_spacing_set_, DINFO_DELAY, 1, MSG_WARN)
end

function CREReader:toggleBoldNormal()
	InfoMessage:inform(SChanging_font_weight_, DINFO_NODELAY, 1, MSG_AUX)
	local prev_xpointer = self.doc:getXPointer()
	self.doc:toggleFontBolder()
	self:goto(prev_xpointer, nil, "xpointer")
end

function CREReader:doIncDecFontSizeSpacing()
	InfoMessage:inform(Sleft_right_spacing_up_down_size, DINFO_NODELAY, 1, MSG_AUX)
	while true do
		local ev = input.saveWaitForEvent()
		ev.code = adjustKeyEvents(ev)
		if ev.type == EV_KEY and ev.value ~= EVENT_VALUE_KEY_RELEASE then
			Debug("key pressed: "..tostring(keydef))
			if ev.code == KEY_FW_UP then self:incDecFontSize(1)
			elseif ev.code == KEY_FW_DOWN then self:incDecFontSize(-1)
			elseif ev.code == KEY_FW_LEFT then self:incDecFontSpacing(-10)
			elseif ev.code == KEY_FW_RIGHT then self:incDecFontSpacing(10)
			else 
				InfoMessage:inform(SFont_size_and_spacing_adjusted, DINFO_DELAY, 1, MSG_AUX)
				return nil 
			end
		end	
	end	
end

function CREReader:incDecFontSize(delta)
	local change
	if delta > 0 then change = SIncreasing
	else change = SDecreasing end
	
	self.font_zoom = self.font_zoom + delta
	self.font_zoom = math.max(self.font_zoom, -3)
	self.font_zoom = math.min(self.font_zoom, 4)

	if DINFO_FONT_SIZE_CHANGE_SHOW then
		InfoMessage:inform(change..S_font_size_to_..self.font_zoom..". ", DINFO_NODELAY, 1, MSG_AUX)
	end	
	Debug("font zoomed to", self.font_zoom)
	local prev_xpointer = self.doc:getXPointer()
	self.doc:zoomFont(delta)
	self:goto(prev_xpointer, nil, "xpointer")
end

function CREReader:incDecFontSpacing(factor)
	self.line_space_percent = self.line_space_percent + factor
	self.line_space_percent = math.max(self.line_space_percent, 80)
	self.line_space_percent = math.min(self.line_space_percent, 200)

	if DINFO_LINE_SPACING_CHANGE_SHOW then
		InfoMessage:inform(SChange_line_space_to_..self.line_space_percent.."% ", DINFO_NODELAY, 1, MSG_AUX)
	end	
	Debug("line spacing set to", self.line_space_percent)
	local prev_xpointer = self.doc:getXPointer()
	self.doc:setDefaultInterlineSpace(self.line_space_percent)
	self:goto(prev_xpointer, nil, "xpointer")
end

function CREReader:gotoInput()
	local height = self.doc:getFullHeight()
	local inputtext, cur_pos
	if self.view_mode == CRE_VM_SCROLL then 
		inputtext = SPosition_in_percent_
		cur_pos = math.floor((self.pos / height)*100)
	else
		inputtext = SPage_
		cur_pos = self.doc:getCurrentPage()
	end	
	local position = NumInputBox:input(G_height-100, 100,
		inputtext, Scurrent_..cur_pos, true)
	-- convert string to number
	if position and pcall(function () position = position + 0 end) then
		if self.view_mode == CRE_VM_SCROLL then
			if position >= 0 and position <= 100 then
				self:goto(math.floor(height * position / 100))
				return
			end
		else
			self:goto(position, true, "page")
			return
		end		
	end
	self:redrawCurrentPage()
end

function CREReader:gammaInput()
	local new_gamma = NumInputBox:input(G_height-100, 100,
		SGamma..":", self.gamma_index, true)
	-- convert string to number
		if pcall(function () new_gamma = math.floor(new_gamma) end) then
			if new_gamma < 0 then new_gamma = 0 end
			self.gamma_index = new_gamma
		end
		cre.setGammaIndex(self.gamma_index)
		self:redrawCurrentPage()
end

function CREReader:addBookmarkCommand()
	ok = self:addBookmark(self.doc:getXPointer())
	if DKPV_STYLE_BOOKMARKS then
		if not ok then
			InfoMessage:drawTopMsg(SBookmark_already_exists_)
		else
			InfoMessage:drawTopMsg(SBookmark_added_)
		end
	else	-- not DKPV_STYLE_BOOKMARKS
		if not ok then
			InfoMessage:inform(SBookmark_already_exists_, DINFO_DELAY, 1, MSG_WARN)
		else
			InfoMessage:inform(SBookmark_added_, DINFO_DELAY, 1, MSG_WARN)
		end
	end	
end

function CREReader:doZoomOrFont()
	self:showFontsMenu()
	self:redrawCurrentPage()
end

function CREReader:adjustCreReaderCommands()
	self.commands:delGroup("[joypad]")
	self.commands:delGroup(MOD_ALT.."H/J")
	self.commands:delGroup(SShift_left_right)
	self.commands:del(KEY_G, nil, "G")
	self.commands:del(KEY_J, MOD_SHIFT, "J")
	self.commands:del(KEY_K, MOD_SHIFT, "K")
	self.commands:del(KEY_Z, nil, "Z")
	self.commands:del(KEY_Z, MOD_SHIFT, "Z")
	self.commands:del(KEY_Z, MOD_ALT, "Z")
	self.commands:del(KEY_A, nil, "A")
	self.commands:del(KEY_A, MOD_SHIFT, "A")
	self.commands:del(KEY_A, MOD_ALT, "A")
	self.commands:del(KEY_S, nil, "S")
	self.commands:del(KEY_S, MOD_SHIFT, "S")
	self.commands:del(KEY_S, MOD_ALT, "S")
	self.commands:del(KEY_D, nil, "D")
	self.commands:del(KEY_D, MOD_SHIFT, "D")
	self.commands:del(KEY_D, MOD_ALT, "D")
	self.commands:del(KEY_X, nil, "X")
	self.commands:del(KEY_F, MOD_SHIFT, "F")
	self.commands:del(KEY_F, MOD_ALT, "F")
	self.commands:del(KEY_N, nil, "N")
	self.commands:del(KEY_N, MOD_SHIFT, "N")
	self.commands:del(KEY_X, MOD_SHIFT, "X")
	self.commands:del(KEY_L, MOD_SHIFT, "L")
	self.commands:del(KEY_M, nil, "M")
	self.commands:del(KEY_U, nil,"U")
	self.commands:del(KEY_C, nil, "C")
	self.commands:del(KEY_P, nil, "P")
	self.commands:del(KEY_P, MOD_SHIFT, "P")
	
	-- CCW-rotation
	self.commands:add(KEY_K, nil, "K",
		Srotate_screen_90_counterclockwise,
		function(self)
			local prev_xpointer = self.doc:getXPointer()
			Screen:screenRotate("anticlockwise")
			G_width, G_height = fb:getSize()
			self:goto(prev_xpointer, nil, "xpointer")
			self.pos = self.doc:getCurrentPos()
			if G_width > G_height then
				-- in landscape mode, crengine will render in two column mode
				self.view_pan_step = G_height * 2
			else
				self.view_pan_step = G_height
			end	
		end
	)
	-- CW-rotation
	self.commands:add(KEY_J, nil, "J",
		Srotate_screen_90_clockwise,
		function(self)
			local prev_xpointer = self.doc:getXPointer()
			Screen:screenRotate("clockwise")
			G_width, G_height = fb:getSize()
			self:goto(prev_xpointer, nil, "xpointer")
			self.pos = self.doc:getCurrentPos()
			if G_width > G_height then
				-- in landscape mode, crengine will render in two column mode
				self.view_pan_step = G_height * 2
			else
				self.view_pan_step = G_height
			end	
		end
	)
	-- navigate between chapters by Shift+Up & Shift-Down
	self.commands:addGroup(MOD_SHIFT..Sup_down,{
		Keydef:new(KEY_FW_UP, MOD_SHIFT), Keydef:new(KEY_FW_DOWN, MOD_SHIFT)},
		Sskip_to_previous_next_chapter,
		function(self)
			if keydef.keycode == KEY_FW_UP then
				self:gotoPrevNextTocEntry(-1)
			else
				self:gotoPrevNextTocEntry(1)
			end
		end
	)
	-- fast navigation by Left & Right
	local scrollpages = DCREREADER_FASTNAV_PAGES
	self.commands:addGroup(Sleft_right,
		{Keydef:new(KEY_FW_LEFT, nil),Keydef:new(KEY_FW_RIGHT, nil)},
		Smove_..scrollpages..S_pages_backwards_forward,
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				if keydef.keycode == KEY_FW_RIGHT then
					self:gotoInput()
				end	
				return
			end
			if self.view_mode == CRE_VM_SCROLL then
				if keydef.keycode == KEY_FW_LEFT then
					self:goto(math.max(0, self.pos - scrollpages*G_height))
				else
					self:goto(math.min(self.pos + scrollpages*G_height, self.doc:getFullHeight()-G_height))
				end
			else
				if keydef.keycode == KEY_FW_LEFT then
					self:goto(self.pageno-scrollpages, true, "page")
				else
					self:goto(self.pageno+scrollpages, true, "page")
				end
			end
		end
	)
	self.commands:addGroup(MOD_SHIFT.."< >",{
		Keydef:new(KEY_PGBCK,MOD_SHIFT),Keydef:new(KEY_PGFWD,MOD_SHIFT),
		Keydef:new(KEY_LPGBCK,MOD_SHIFT),Keydef:new(KEY_LPGFWD,MOD_SHIFT)},
		Sincrease_decrease_font_size,
		function(self)
			if keydef.keycode == KEY_PGBCK or keydef.keycode == KEY_LPGBCK then
				self:incDecFontSize(-1)
			else
				self:incDecFontSize(1)
			end	
		end
	)
	self.commands:addGroup(MOD_ALT.."< >",{
		Keydef:new(KEY_PGBCK,MOD_ALT),Keydef:new(KEY_PGFWD,MOD_ALT),
		Keydef:new(KEY_LPGBCK,MOD_ALT),Keydef:new(KEY_LPGFWD,MOD_ALT)},
		Sincrease_decrease_line_spacing,
		function(self)
			if keydef.keycode == KEY_PGBCK or keydef.keycode == KEY_LPGBCK then
				self:incDecFontSpacing(-10)
			else	
				self:incDecFontSpacing(10)
			end	
		end
	)
	local numeric_keydefs = {}
	for i=1,10 do
		numeric_keydefs[i]=Keydef:new(KEY_1+i-1, nil, tostring(i%10))
	end
	self.commands:addGroup("[1, 2 .. 9, 0]",numeric_keydefs,
		Sjump_to_0_10__90_100_of_document,
		function(self, keydef)
			Debug('jump to position: '..
				math.floor(self.doc:getFullHeight()*(keydef.keycode-KEY_1)/9)..
				'/'..self.doc:getFullHeight())
			self:goto(math.floor(self.doc:getFullHeight()*(keydef.keycode-KEY_1)/9))
		end
	)
	self.commands:add(KEY_G,nil,"G",
		Sopen_go_to_position_input_box,
		function(unireader)
			self:gotoInput()
		end
	)
	self.commands:add({KEY_F, KEY_AA}, nil, "F",
		Schange_document_font,
		function(self)
			self:changeDocFont()
		end
	)
	self.commands:add(KEY_F, MOD_SHIFT, "F",
		Suse_document_font_as_default_font,
		function(self)
			self:setDocFontAsDefault()
		end
	)
	self.commands:add(KEY_F, MOD_ALT, "F",
		Stoggle_font_weight_bold_normal,
		function(self)
			self:toggleBoldNormal()
		end
	)
	self.commands:add(KEY_B, MOD_ALT, "B",
		Sadd_bookmark_to_current_page,
		function(self)
			self:addBookmarkCommand()
		end -- function
	)
	self.commands:addGroup(MOD_ALT.."K/L",{
		Keydef:new(KEY_K,MOD_ALT), Keydef:new(KEY_L,MOD_ALT)},
		Sjump_between_bookmarks,
		function(unireader,keydef)
			local bm = nil
			if keydef.keycode == KEY_K then
				bm = self:prevBookMarkedPage()
			else
				bm = self:nextBookMarkedPage()
			end
			if bm then self:goto(bm.page, true, "xpointer") end
		end)
	self.commands:add(KEY_BACK, nil, "Back",
		Sgo_backward_in_jump_history,
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				local next_jump_no = self.jump_history.cur + 1
				if next_jump_no <= #self.jump_history then
					self.jump_history.cur = next_jump_no
					self:goto(self.jump_history[next_jump_no].page, true, "xpointer")
				else
					InfoMessage:inform(SAlready_last_jump_, DINFO_DELAY, 1, MSG_WARN)
				end
				return
			end

			local prev_jump_no = 0
			if self.jump_history.cur > #self.jump_history then
				-- if cur points to head, put current page in history
				self:addJump(self.doc:getXPointer())
				prev_jump_no = self.jump_history.cur - 2
			else
				prev_jump_no = self.jump_history.cur - 1
			end

			if prev_jump_no >= 1 then
				self.jump_history.cur = prev_jump_no
				self:goto(self.jump_history[prev_jump_no].page, true, "xpointer")
			else
				InfoMessage:inform(SAlready_first_jump_, DINFO_DELAY, 1, MSG_WARN)
			end
		end
	)
	self.commands:add(KEY_BACK, MOD_SHIFT, "Back",
		Sgo_forward_in_jump_history,
		function(self)
			local next_jump_no = self.jump_history.cur + 1
			if next_jump_no <= #self.jump_history then
				self.jump_history.cur = next_jump_no
				self:goto(self.jump_history[next_jump_no].page, true, "xpointer")
			else
				InfoMessage:inform(SAlready_last_jump_, DINFO_DELAY, 1, MSG_WARN)
			end
		end
	)
	self.commands:addGroup("vol-/+",
		{Keydef:new(KEY_VPLUS,nil), Keydef:new(KEY_VMINUS,nil)},
		Sdecrease_increase_gamma,
		function(self, keydef)
			local delta = 1
			if keydef.keycode == KEY_VMINUS then
				delta = -1
			end
			cre.setGammaIndex(self.gamma_index+delta)
			self.gamma_index = cre.getGammaIndex()
			InfoMessage:inform(SChanging_gamma_to_..self.gamma_index..". ", DINFO_NODELAY, 1, MSG_AUX)
			self:redrawCurrentPage()
		end
	)
	self.commands:add(KEY_FW_UP, nil, Sjoypad_up,
		Span_..self.shift_y..S_pixels_upwards,
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				self:addBookmarkCommand()
				return
			end
			if self.view_mode == CRE_VM_SCROLL then
				self:goto(self.pos - self.shift_y)
			end	
		end
	)
	self.commands:add(KEY_FW_DOWN, nil, Sjoypad_down,
		Span_..self.shift_y..S_pixels_downwards,
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				keep_running = true
				return "break"
			end
			if self.view_mode == CRE_VM_SCROLL then
				self:goto(self.pos + self.shift_y)
			end	
		end
	)
	self.commands:add(KEY_V, nil, "V",
		Stoggle_view_mode_,
		function(self)
			self:toggleViewMode()
		end
	)
	self.commands:add(KEY_HOME, MOD_SHIFT, "Home",
		Stoggle_crereader_header,
		function(self)
			local prev_xpointer = self.doc:getXPointer()
			self:toggleCREHeader()
			G_reader_settings:saveSetting("cre_header_enable", self.cre_header_enable)
			self:goto(prev_xpointer, nil, "xpointer")
		end
	)
	self.commands:add(KEY_FW_PRESS, nil, nil, nil, -- hiden from help screen - only usable on K4NT
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				self:doFollowLink()
				return
			end
		end
	)
	self.commands:add(KEY_LPGBCK, nil, nil, nil, -- hiden from help screen - only usable on K4NT
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				local bm = nil
				bm = self:prevBookMarkedPage()
				if bm then self:goto(bm.page, true, "xpointer") end
				return
			end
			self:goto(self:prevView(), true, "page")
		end
	)
	self.commands:add(KEY_LPGFWD, nil, nil, nil, -- hiden from help screen - only usable on K4NT
		function(self)
			if G_ScreenKB_pressed then
				G_ScreenKB_pressed = false
				local bm = nil
				bm = self:nextBookMarkedPage()
				if bm then self:goto(bm.page, true, "xpointer") end
				return
			end
			self:goto(self:nextView(), true, "page")
		end
	)
end

----------------------------------------------------
--- search
----------------------------------------------------
function CREReader:searchHighLight(search)
	Debug("FIXME CreReader::searchHighLight", search)

	if self.last_search == nil or self.last_search.search == nil then
		self.last_search = {
			search = "",
		}
	end

	local origin = 0 -- 0=current 1=next-last -1=first-current
	if self.last_search.search == search then
		origin = 1
	end

	local found, pos = self.doc:findText(
		search,
		origin,
		0, -- reverse: boolean
		1  -- caseInsensitive: boolean
	)

	if found then
		self.pos = pos -- first metch position
		self:redrawCurrentPage()
		InfoMessage:inform( found..S_hits_.."'"..search.."'"..S_pos_..pos, DINFO_DELAY, 1, MSG_WARN)
	else
		InfoMessage:inform( "'"..search.."'"..S_not_found_in_document_, DINFO_DELAY, 1, MSG_WARN)
	end

	self.last_search.search = search
end

----------------------------------------------------
--- page links
----------------------------------------------------
function CREReader:getPageLinks()
	local links = self.doc:getPageLinks()
	Debug("getPageLinks", links)
	return links
end

function CREReader:clearSelection()
	Debug("clearSelection")
	self.doc:clearSelection()
end
