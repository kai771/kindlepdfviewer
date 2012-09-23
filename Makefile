# you can probably leave these settings alone:

LUADIR=luajit-2.0
MUPDFDIR=mupdf
MUPDFTARGET=build/debug
MUPDFLIBDIR=$(MUPDFDIR)/$(MUPDFTARGET)
DJVUDIR=djvulibre

FREETYPEDIR=$(MUPDFDIR)/thirdparty/freetype-2.4.10
LFSDIR=luafilesystem

# must point to directory with *.ttf fonts for crengine
TTF_FONTS_DIR=$(MUPDFDIR)/fonts

# set this to your ARM cross compiler:

HOST:=arm-none-linux-gnueabi
CC:=$(HOST)-gcc
CXX:=$(HOST)-g++
STRIP:=$(HOST)-strip
ifdef SBOX_UNAME_MACHINE
	CC:=gcc
	CXX:=g++
endif
HOSTCC:=gcc
HOSTCXX:=g++

CFLAGS:=-O3 $(SYSROOT)
CXXFLAGS:=-O3 $(SYSROOT)
LDFLAGS:= $(SYSROOT)
ARM_CFLAGS:=-march=armv6
# use this for debugging:
#CFLAGS:=-O0 -g

DYNAMICLIBSTDCPP:=-lstdc++
ifdef STATICLIBSTDCPP
	DYNAMICLIBSTDCPP:=
endif

# you can configure an emulation for the (eink) framebuffer here.
# the application won't use the framebuffer (and the special e-ink ioctls)
# in that case.

ifdef EMULATE_READER
	CC:=$(HOSTCC) -g
	CXX:=$(HOSTCXX)
	EMULATE_READER_W?=824
	EMULATE_READER_H?=1200
	EMU_CFLAGS?=$(shell sdl-config --cflags)
	EMU_CFLAGS+= -DEMULATE_READER \
		     -DEMULATE_READER_W=$(EMULATE_READER_W) \
		     -DEMULATE_READER_H=$(EMULATE_READER_H)
	EMU_LDFLAGS?=$(shell sdl-config --libs)
	ifeq "$(shell uname -s -m)" "Darwin x86_64"
		EMU_LDFLAGS += -pagezero_size 10000 -image_base 100000000
	endif
else
	CFLAGS+= $(ARM_CFLAGS)
endif

# standard includes
KPDFREADER_CFLAGS=$(CFLAGS) -I$(LUADIR)/src -I$(MUPDFDIR)/

# enable tracing output:

#KPDFREADER_CFLAGS+= -DMUPDF_TRACE

# for now, all dependencies except for the libc are compiled into the final binary:

MUPDFLIBS := $(MUPDFLIBDIR)/libfitz.a
DJVULIBS := $(DJVUDIR)/build/libdjvu/.libs/libdjvulibre.a
THIRDPARTYLIBS := $(MUPDFLIBDIR)/libfreetype.a \
			$(MUPDFLIBDIR)/libopenjpeg.a \
			$(MUPDFLIBDIR)/libjbig2dec.a \
			$(MUPDFLIBDIR)/libjpeg.a \
			$(MUPDFLIBDIR)/libz.a

LUALIB := $(LUADIR)/src/libluajit.a

all:kpdfdjview

kpdfdjview: kpdfdjview.o einkfb.o pdf.o blitbuffer.o drawcontext.o input.o util.o ft.o lfs.o mupdfimg.o $(MUPDFLIBS) $(THIRDPARTYLIBS) $(LUALIB) djvu.o $(DJVULIBS)
	$(CC) \
		kpdfdjview.o \
		einkfb.o \
		pdf.o \
		blitbuffer.o \
		drawcontext.o \
		input.o \
		util.o \
		ft.o \
		lfs.o \
		mupdfimg.o \
		$(MUPDFLIBS) \
		$(THIRDPARTYLIBS) \
		$(LUALIB) \
		djvu.o \
		$(DJVULIBS) \
		$(STATICLIBSTDCPP) \
		-o kpdfdjview -lm -ldl -lpthread $(EMU_LDFLAGS) $(DYNAMICLIBSTDCPP)

ft.o: %.o: %.c $(THIRDPARTYLIBS)
	$(CC) -c $(KPDFREADER_CFLAGS) -I$(FREETYPEDIR)/include -I$(MUPDFDIR)/fitz $< -o $@

kpdfdjview.o pdf.o blitbuffer.o util.o drawcontext.o einkfb.o input.o mupdfimg.o: %.o: %.c
	$(CC) -c $(KPDFREADER_CFLAGS) $(EMU_CFLAGS) -I$(LFSDIR)/src $< -o $@

djvu.o: %.o: %.c
	$(CC) -c $(KPDFREADER_CFLAGS) -I$(DJVUDIR)/ $< -o $@

lfs.o: $(LFSDIR)/src/lfs.c
	$(CC) -c $(CFLAGS) -I$(LUADIR)/src -I$(LFSDIR)/src $(LFSDIR)/src/lfs.c -o $@

fetchthirdparty:
	-rm -Rf mupdf/thirdparty
	test -d mupdf && (cd mupdf; git checkout .)  || echo warn: mupdf folder not found
	test -d $(LUADIR) && (cd $(LUADIR); git checkout .)  || echo warn: $(LUADIR) folder not found
	git submodule init
	git submodule update
	test -d fonts || ln -sf $(TTF_FONTS_DIR) fonts
	test -f mupdf-thirdparty.zip || wget http://www.mupdf.com/download/mupdf-thirdparty.zip
	unzip mupdf-thirdparty.zip -d mupdf
	cd mupdf && patch -N -p1 < ../mupdf.patch

clean:
	-rm -f *.o kpdfdjview

cleanthirdparty:
	-make -C $(LUADIR) clean
	-make -C $(MUPDFDIR) clean
	-rm -rf $(DJVUDIR)/build
	-rm -f $(MUPDFDIR)/fontdump.host
	-rm -f $(MUPDFDIR)/cmapdump.host

$(MUPDFDIR)/fontdump.host:
	make -C mupdf CC="$(HOSTCC)" $(MUPDFTARGET)/fontdump
	cp -a $(MUPDFLIBDIR)/fontdump $(MUPDFDIR)/fontdump.host
	make -C mupdf clean

$(MUPDFDIR)/cmapdump.host:
	make -C mupdf CC="$(HOSTCC)" $(MUPDFTARGET)/cmapdump
	cp -a $(MUPDFLIBDIR)/cmapdump $(MUPDFDIR)/cmapdump.host
	make -C mupdf clean

$(MUPDFLIBS) $(THIRDPARTYLIBS): $(MUPDFDIR)/cmapdump.host $(MUPDFDIR)/fontdump.host
	# build only thirdparty libs, libfitz and pdf utils, which will care for libmupdf.a being built
	CFLAGS="$(CFLAGS) -DNOBUILTINFONT" make -C mupdf CC="$(CC)" CMAPDUMP=cmapdump.host FONTDUMP=fontdump.host MUPDF= MU_APPS= BUSY_APP= XPS_APPS= verbose=1

$(DJVULIBS):
	-mkdir $(DJVUDIR)/build
ifdef EMULATE_READER
	cd $(DJVUDIR)/build && ../configure --disable-desktopfiles --disable-shared --enable-static --disable-xmltools --disable-largefile
else
	cd $(DJVUDIR)/build && ../configure --disable-desktopfiles --disable-shared --enable-static --host=$(HOST) --disable-xmltools --disable-largefile
endif
	make -C $(DJVUDIR)/build

$(LUALIB):
ifdef EMULATE_READER
	make -C $(LUADIR)
else
	make -C $(LUADIR) CC="$(HOSTCC)" HOST_CC="$(HOSTCC) -m32" CROSS="$(HOST)-" TARGET_FLAGS="$(SYSROOT) -DLUAJIT_NO_LOG2 -DLUAJIT_NO_EXP2"
endif

thirdparty: $(MUPDFLIBS) $(THIRDPARTYLIBS) $(LUALIB) $(DJVULIBS) $(CRENGINELIBS)

TMP_DIR=tmp

LUA_FILES=commands.lua dialog.lua djvureader.lua filechooser.lua filehistory.lua fileinfo.lua filesearcher.lua font.lua graphics.lua helppage.lua image.lua inputbox.lua keys.lua pdfreader.lua reader.lua rendertext.lua screen.lua selectmenu.lua settings.lua unireader.lua widget.lua

VERSION?=$(shell git rev-parse --short HEAD)
customupdate: all
	# ensure that build binary is for ARM
	file kpdfdjview | grep ARM || exit 1
	$(STRIP) --strip-unneeded kpdfdjview
	-rm kpdfdjview-$(VERSION).zip > /dev/null 2>&1
	rm -Rf $(TMP_DIR)
	mkdir -p $(TMP_DIR)/{history,screenshots,clipboard}
	cp -p README.md COPYING $(LUA_FILES) $(TMP_DIR)
	mv kpdfdjview $(TMP_DIR)
	cp -rpL fonts $(TMP_DIR)
	cp -r resources $(TMP_DIR)
	mv $(TMP_DIR) kpdfdjview
	zip -9 -r kpdfdjview-$(VERSION).zip kpdfdjview/ launchpad/ kite/
	rm -Rf kpdfdjview
	@echo "copy kpdfdjview-$(VERSION).zip to /mnt/us/customupdates and install with shift+shift+I"
