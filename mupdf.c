/*
    KindlePDFViewer: FreeType font rastering for UI
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
*/
#include "pdf.h"
#include "mupdfimg.h"

int luaopen_mupdf(lua_State *L) {
	luaopen_pdf(L);
	luaopen_mupdfimg(L);
	return 0; // we don't return neither "pdf" nor "mupdf"
}
