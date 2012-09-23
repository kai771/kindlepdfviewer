#!./kpdfdjview
--[[
    Kindle PDF and DjVu Viewer, based on:
    KindlePDFViewer: a reader implementation
    Copyright (C) 2011 Hans-Werner Hilse <hilse@web.de>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--
require "pdfreader"
require "djvureader"
require "filechooser"
require "settings"
require "screen"
require "dialog"

function openFile(filename)
	local ext = string.match(filename, ".+%.([^.]+)")

	if ext then
		ext = string.lower(ext)
		local reader
		if ext == "djvu" then
			reader = DJVUReader
		elseif string.find(";pdf;xps;cbz;", ";"..ext..";") then	
			reader = PDFReader
		end
		if reader then
			InfoMessage:show("Opening "..ext.." document ")
			reader:preLoadSettings(filename)
			local ok, err = reader:open(filename)
			if ok then
				reader:loadSettings(filename)
				page_num = reader:getLastPage()
				reader:goto(tonumber(page_num), true)
				return reader:inputLoop()
			else
				Debug("openFile(): Error opening document: "..err)
				showInfoMsgWithDelay("Error opening document ")
			end
		else
			showInfoMsgWithDelay(ext.." format not supported ")
		end -- if reader
	else
		showInfoMsgWithDelay("Unknown format ")
	end -- if ext
	return true -- on failed attempts, we signal to keep running
end

if ARGV[1] ~= "-d" then
	dump = function() end
	Debug = function() end
end

if util.isEmulated()==1 then
	input.open("")
	setEmuKeycodes()
else
	input.open("slider")
	input.open("/dev/input/event0")
	input.open("/dev/input/event1")

	-- check if we are running on Kindle 3 (additional volume input)
	if FileExists("/dev/input/event2") then
		input.open("/dev/input/event2")
		setK3Keycodes()
	end
end

G_screen_saver_mode = false
G_charging_mode = false
fb = einkfb.open("/dev/fb0")
G_width, G_height = fb:getSize()
-- read current rotation mode
Screen:updateRotationMode()
Screen.native_rotation_mode = Screen.cur_rotation_mode

G_reader_settings = DocSettings:open(".reader")
fontmap = G_reader_settings:readSetting("fontmap")
UniReader:initGlobalSettings(G_reader_settings)
PDFReader:init()
DJVUReader:init()

local running = true
FileChooser:setPath("/mnt/us/documents")
while running do
	local file = FileChooser:choose(0, G_height)
	if file then
		running = openFile(file)
	else
		running = false
	end
end

-- save reader settings
G_reader_settings:saveSetting("fontmap", Font.fontmap)
G_reader_settings:close()

-- @TODO dirty workaround, find a way to force native system poll
-- screen orientation and upside down mode 09.03 2012
fb:setOrientation(Screen.native_rotation_mode)

input.closeAll()
if util.isEmulated()==0 then
	os.execute("killall -cont cvm")
	os.execute('echo "send '..KEY_MENU..'" > /proc/keypad;echo "send '..KEY_MENU..'" > /proc/keypad')
end
