-- framebuffer update policy state:
DRCOUNT = 5
-- full refresh on every DRCOUNTMAX page turn
DRCOUNTMAX = 10

-- zoom state:
DGLOBALZOOM = 1.0
DGLOBALZOOM_ORIG = 1.0
DGLOBALZOOM_MODE = -1 -- ZOOM_FIT_TO_PAGE

DGLOBALROTATE = 0

-- gamma setting:
DGLOBALGAMMA = 1.0   -- GAMMA_NO_GAMMA

-- DjVu page rendering mode (used in djvu.c:drawPage())
-- See comments in djvureader.lua:DJVUReader:select_render_mode()
DRENDER_MODE = 0 -- COLOUR

-- set panning distance
DSHIFT_X = 100
DSHIFT_Y = 100
-- step to change zoom manually, default = 25%
DSTEP_MANUAL_ZOOM = 25
DPAN_BY_PAGE = false -- using shift_[xy] or width/height
DPAN_MARGIN = 5 -- horizontal margin for two-column zoom (in pixels)
DPAN_OVERLAP_VERTICAL = 30

-- tile cache configuration:
DCACHE_MAX_MEMSIZE = 1024*1024*5 -- 5MB tile cache
DCACHE_MAX_TTL = 20 -- time to live

-- renderer cache size
DCACHE_DOCUMENT_SIZE = 1024*1024*8 -- FIXME random, needs testing

-- default value for battery level logging
DBATTERY_LOGGING = false

-- force portrait mode on start and document close
DFORCE_PORTRAIT = true

-- prevent rotation to portrait upside-down
DPREVENT_UPSIDE_DOWN = true

-- if set to true, it will display "Bookmark added" and "Bookmark already exists"
-- on top of the screen, like KPV 2012.11.
DKPV_STYLE_BOOKMARKS = false

-- if set to true, it will display lists (Table of Contets, Bookmarks, Highlights, Menus)
-- with shortcut keys Q-P etc on the left, like on KPV 2012.11.
DKPV_STYLE_LISTS = false

-- background colour: 8 = gray, 0 = white, 15 = black
DBACKGROUND_COLOR = 8

-- Highlight colour: 8 = gray, 0 = white, 15 = black
-- values for DHIGHLIGHT_DRAWER can be "underscore" or "marker" - with quotes
DHIGHLIGHT_LINE_COLOR = 5
DHIGHLIGHT_LINE_WIDTH = 2
DHIGHLIGHT_DRAWER = "underscore"

-- BBox steps
DBBOX_STEP_SMALL = 1
DBBOX_STEP_NORMAL = 10
DBBOX_STEP_BIG = 30

-- delay for info messages in ms
DINFO_NODELAY = 0
DINFO_DELAY = 1500
DINFO_TOGGLES = 300

-- InfoMessage options
DINFO_OVERLAP_SHOW = true
DINFO_COMICS_MODE_SHOW = true
DINFO_RTL_MODE_SHOW = true
DINFO_PAGE_MODE_SHOW = true
DINFO_LINK_UNDERLINES_SHOW = true

-- toggle defaults
DUNIREADER_SHOW_OVERLAP_ENABLE = false
DUNIREADER_SHOW_LINKS_ENABLE = false
DUNIREADER_COMICS_MODE_ENABLE = true
DUNIREADER_RTL_MODE_ENABLE = false
DUNIREADER_PAGE_MODE_ENABLE = false

DDJVUREADER_SHOW_OVERLAP_ENABLE = false
DDJVUREADER_SHOW_LINKS_ENABLE = false
DDJVUREADER_COMICS_MODE_ENABLE = true
DDJVUREADER_RTL_MODE_ENABLE = false
DDJVUREADER_PAGE_MODE_ENABLE = false

DKOPTREADER_SHOW_OVERLAP_ENABLE = false
DKOPTREADER_SHOW_LINKS_ENABLE = false
DKOPTREADER_COMICS_MODE_ENABLE = false
DKOPTREADER_RTL_MODE_ENABLE = false
DKOPTREADER_PAGE_MODE_ENABLE = false

DPICVIEWER_SHOW_OVERLAP_ENABLE = false
DPICVIEWER_SHOW_LINKS_ENABLE = false
DPICVIEWER_COMICS_MODE_ENABLE = true
DPICVIEWER_RTL_MODE_ENABLE = false
DPICVIEWER_PAGE_MODE_ENABLE = false

-- SelectMenu defaults
DSM_FSIZE = 22	-- font for displaying item names
DSM_TFSIZE = 25 -- font for page title
DSM_FFSIZE = 16 -- font for paging display

DSM_TITLE_H = 40	-- title height
DSM_SPACING = 36	-- spacing between lines
DSM_FOOT_H = 27	-- foot height
DSM_MARGIN_H = 10	-- horizontal margin
DSM_SHORTCUT_WIDTH = 40 -- width used to draw shortcut key
DSM_SHIFT_UP_DOWN = 5 -- number of items to skip when holding Shift and pressing up/down

-- FileChooser defaults
DFC_TITLE_H = 40	-- title height
DFC_SPACING = 37	-- spacing between lines
DFC_ICON_DROP = 7	-- amount of pixels icon is placed bellow filename base line
DFC_FOOT_H = 28	-- foot height
DFC_MARGIN_H = 10	-- horizontal margin
DFC_SHIFT_UP_DOWN = 5 -- number of items to skip when holding Shift and pressing up/down

-- koptreader config defaults
DKOPTREADER_CONFIG_FONT_SIZE = 1.0		-- range from 0.1 to 3.0
DKOPTREADER_CONFIG_TEXT_WRAP = 1		-- 1 = on, 0 = off
DKOPTREADER_CONFIG_TRIM_PAGE = 1		-- 1 = auto, 0 = manual
DKOPTREADER_CONFIG_DETECT_INDENT = 1	-- 1 = enable, 0 = disable
DKOPTREADER_CONFIG_DEFECT_SIZE = 1.0	-- range from 0.0 to 3.0
DKOPTREADER_CONFIG_PAGE_MARGIN = 0.06	-- range from 0.0 to 1.0
DKOPTREADER_CONFIG_LINE_SPACING = 1.2	-- range from 0.5 to 2.0
DKOPTREADER_CONFIG_WORD_SAPCING = 0.15	-- range from 0.05 to 0.5
DKOPTREADER_CONFIG_MULTI_THREADS = 1	-- 1 = on, 0 = off
DKOPTREADER_CONFIG_RENDER_QUALITY = 1.0	-- range from 0.5 to 1.0
DKOPTREADER_CONFIG_AUTO_STRAIGHTEN = 0	-- range from 0 to 10
DKOPTREADER_CONFIG_JUSTIFICATION = -1	-- -1 = auto, 0 = left, 1 = center, 2 = right, 3 = full
DKOPTREADER_CONFIG_MAX_COLUMNS = 2		-- range from 1 to 4
DKOPTREADER_CONFIG_CONTRAST = 1.0		-- range from 0.2 to 2.0
DKOPTREADER_CONFIG_SCREEN_ROTATION = 0	-- 0, 90, 180, 270 degrees

-- supported extensions
DPDFREADER_EXT = ";pdf;xps;cbz;zip;"
DDJVUREADER_EXT = ";djvu;"
DPDFREFLOW_EXT = ";pdf;"
DDJVUREFLOW_EXT = ";djvu;"
DCREREADER_EXT = ";epub;txt;rtf;htm;html;mobi;prc;azw;fb2;chm;pdb;doc;tcr;zip;" 	-- seems to accept pdb-files for PalmDoc only
DPICVIEWER_EXT = ";jpg;jpeg;"
