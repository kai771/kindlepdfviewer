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
require "keys"
require "commands"
require "dialog"
require "extentions"

function openFile(filename)
	local match = string.match(filename, ".+%.([^.]+)")

	if match then
		local file_type = string.lower(match)
		local reader = ext:getReader(file_type)
		if reader then
			InfoMessage:show("Opening document... ", 0)
			reader:preLoadSettings(filename)
			local ok, err = reader:open(filename)
			if ok then
				reader:loadSettings(filename)
				page_num = reader:getLastPageOrPos()
				reader:goto(tonumber(page_num), true)
				G_reader_settings:saveSetting("lastfile", filename)
				return reader:inputLoop()
			else
				InfoMessage:show(err or "Error opening document.", 0)
				util.sleep(2)
			end
		end -- if reader
	end -- if match
	return true -- on failed attempts, we signal to keep running
end

if ARGV[1] ~= "-d" then
	Debug = function() end
end

if util.isEmulated()==1 then
	input.open("")
	-- SDL key codes
	setEmuKeycodes()
else
	input.open("slider")
	input.open("/dev/input/event0")
	input.open("/dev/input/event1")

	-- check if we are running on Kindle 3 (additional volume input)
	local f=lfs.attributes("/dev/input/event2")
	if f then
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

-- set up reader's setting: font
G_reader_settings = DocSettings:open(".reader")
fontmap = G_reader_settings:readSetting("fontmap")
if fontmap ~= nil then
	-- we need to iterate over all fonts used in reader to support upgrade from older configuration
	for name,path in pairs(fontmap) do
		if Font.fontmap[name] then
			Font.fontmap[name] = path
		else
			Debug("missing "..name.." in user configuration, using default font "..path)
		end
	end
end

-- set up the mode to manage files
FileChooser.filemanager_expert_mode = G_reader_settings:readSetting("filemanager_expert_mode") or 1
-- initialize global settings shared among all readers
UniReader:initGlobalSettings(G_reader_settings)
-- initialize specific readers
PDFReader:init()
DJVUReader:init()

local running = true
FileChooser:setPath("/mnt/us/documents")
while running do
	local file, callback = FileChooser:choose(0, G_height)
	if callback then
		callback()
	else
		if file ~= nil then
			running = openFile(file)
			print(file)
		else
			running = false
		end
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
