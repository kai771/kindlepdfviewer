require "rendertext"
require "keys"
require "graphics"
require "font"
require "inputbox"
require "dialog"
require "settings"

FileInfo = {
	title_H = 40,	-- title height
	spacing = 36,	-- spacing between lines
	foot_H = 28,	-- foot height
	margin_H = 10,	-- horisontal margin
	-- state buffer
	pagedirty = true,
	result = {},
	commands = nil,
	items = 0,
	pathfile = "",
}

function FileInfo:FileCreated(fname, attr)
	return os.date("%d %b %Y, %H:%M:%S", lfs.attributes(fname,attr))
end

function FileInfo:FormatSize(size)
	if size < 1024 then
		return size.." Bytes"
	elseif size < 2^20 then
		return string.format("%.2f", size/2^10).."KB ("..size.." Bytes)"
	elseif size < 2^30 then
		return string.format("%.2f", size/2^20).."MB ("..size.." Bytes)"
	else
		return string.format("%.2f", size/2^30).."GB ("..size.." Bytes)"
	end
end

function getUnpackedZipSize(zipfile)
	local cmd='unzip -l '..zipfile..' | tail -1 | sed -e "s/^ *\\([0-9][0-9]*\\) *.*/\\1/"'
	local p = io.popen(cmd, "r")
	local res = p:read("*a")
	p:close()
	res = string.gsub(res, "[\n\r]+", "")
	return tonumber(res)
end

function FileExists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	else
		return false
	end
end

function FileInfo:init(path, fname)
	self.pathfile = path.."/"..fname
	self.result = {}
	-- add commands only once
	if not self.commands then
		self:addAllCommands()
	end

	local info_entry = {dir = "Name", name = fname}
	table.insert(self.result, info_entry)
	info_entry = {dir = "Path", name = path}
	table.insert(self.result, info_entry)

	info_entry = {dir = "Size", name = FileInfo:FormatSize(lfs.attributes(self.pathfile, "size"))}
	table.insert(self.result, info_entry)
	-- total size of all unzipped entries for zips 
	local match = string.match(fname, ".+%.([^.]+)")
	if match and string.lower(match) == "zip" then
		info_entry = {dir = "Unpacked", name = FileInfo:FormatSize(getUnpackedZipSize(self.pathfile))}
		table.insert(self.result, info_entry)
		--[[ TODO: When the fileentry inside zips is encoded as ANSI (codes 128-255)
		any attempt to print such fileentry causes crash by drawing!!! When fileentries
		are encoded as UTF8, everything seems fine
		info_entry = { dir = "Content", name = string.sub(s,29,-1) }
		table.insert(self.result, info_entry) ]]
	end

	info_entry = {dir = "Free space", name = FileInfo:FormatSize(util.df("."))}
	table.insert(self.result, info_entry)
	info_entry = {dir = "Status changed", name = FileInfo:FileCreated(self.pathfile, "change")}
	table.insert(self.result, info_entry)
	info_entry = {dir = "Modified", name = FileInfo:FileCreated(self.pathfile, "modification")}
	table.insert(self.result, info_entry)
	info_entry = {dir = "Accessed", name = FileInfo:FileCreated(self.pathfile, "access")}
	table.insert(self.result, info_entry)

	local history = DocToHistory(self.pathfile)
	if not FileExists(history) then
		info_entry = {dir = "Last read", name = "Never"}
		table.insert(self.result, info_entry)
	else
		info_entry = {dir = "Last read", name = FileInfo:FileCreated(history, "change")}
		table.insert(self.result, info_entry)
		for line in io.lines(history) do
			if string.match(line, "%b[]") == "[\"last_page\"]" then
				local cdc = tonumber(string.match(line, "%d+"))
				info_entry = {dir = "Completed", name = string.format("%d", cdc).." pages" }
				table.insert(self.result, info_entry)
			end
		end
	end
	self.items = #self.result
end

function FileInfo:show(path, name)
	-- at first, one has to test whether the file still exists or not: necessary for last documents
	if not FileExists(path.."/"..name) then return nil end

	FileInfo:init(path,name)
	local cface, lface, tface, fface, width, xrcol, c, dy, ev, keydef, ret_code
	while true do
		if self.pagedirty then
			-- refresh the fonts, if not yet defined or updated via 'F'
			cface = Font:getFace("cfont", 22)
			lface = Font:getFace("tfont", 22)
			tface = Font:getFace("tfont", 25)
			fface = Font:getFace("ffont", 16)
			fb.bb:paintRect(0, 0, G_width, G_height, 0)
			DrawTitle("File Information", self.margin_H, 0, self.title_H, 3, tface)
			-- now calculating xrcol-position for the right column
			width = 0
			for c = 1, self.items do
				width = math.max(sizeUtf8Text(0, G_width, lface, self.result[c].dir, true).x, width)
			end
			xrcol = self.margin_H + width + 25
			dy = 5 -- to store the y-position correction 'cause of the multiline drawing
			for c = 1, self.items do
				y = self.title_H + self.spacing * c + dy
				renderUtf8Text(fb.bb, self.margin_H, y, lface, self.result[c].dir, true)
				dy = dy + renderUtf8Multiline(fb.bb, xrcol, y, cface, self.result[c].name, true,
						G_width - self.margin_H - xrcol, 1.65).y - y
			end
			fb:refresh(0)
			self.pagedirty = false
		end
		ev = input.saveWaitForEvent()
		ev.code = adjustKeyEvents(ev)
		if ev.type == EV_KEY and ev.value ~= EVENT_VALUE_KEY_RELEASE then
			keydef = Keydef:new(ev.code, getKeyModifier())
			--Debug("key pressed: "..tostring(keydef))
			command = self.commands:getByKeydef(keydef)
			if command ~= nil then
				--Debug("command to execute: "..tostring(command))
				ret_code = command.func(self, keydef)
			else
				--Debug("command not found: "..tostring(command))
			end
			if ret_code == "break" then break end
		end -- if ev.type
	end -- while true
	-- clear results
	self.pagedirty = true
	result = {}
	return nil
end

function FileInfo:addAllCommands()
	self.commands = Commands:new{}
	self.commands:add({KEY_SPACE}, nil, "Space",
		"refresh page manually",
		function(self)
			self.pagedirty = true
		end
	)
	self.commands:add(KEY_H,nil,"H",
		"show help page",
		function(self)
			HelpPage:show(0, G_height, self.commands)
			self.pagedirty = true
		end
	)
	self.commands:add({KEY_F, KEY_AA}, nil, "F",
		"change font faces",
		function(self)
			Font:chooseFonts()
			self.pagedirty = true
		end
	)
	self.commands:add(KEY_L, nil, "L",
		"last documents",
		function(self)
			FileHistory:init()
			FileHistory:choose("")
			self.pagedirty = true
		end
	) 
	self.commands:add({KEY_ENTER, KEY_FW_PRESS}, nil, "Enter",
		"open document",
		function(self)
			openFile(self.pathfile)
			self.pagedirty = true
		end
	)
	self.commands:add({KEY_BACK, KEY_FW_LEFT}, nil, "Back",
		"back",
		function(self)
			return "break"
		end
	)
end
