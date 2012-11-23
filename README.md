Librerator
==========

This is a fork of KindlePDFViewer, a document viewer application, created for usage 
on the Kindle e-ink reader. It is currently restricted to 4bpp inverse grayscale 
displays. For PDF files it is using the muPDF library (see http://mupdf.com/), for 
DjVu files djvulibre library and for ebooks (fb2, mobi, ePub, etc) crengine. It can 
also read JPEG images using libjpeg library. The user interface is scripted using 
Lua (see http://www.lua.org/). For reflowing of PDF and DjVu files, it uses k2pdfopt 
library.

The application is licensed under the GPLv3 (see COPYING file).


Building
========


Follow these steps:

* automatically fetch thirdparty sources with Makefile:
		* make sure you have patch, wget, unzip, git and svn installed
		* run `make fetchthirdparty`.

* run `make thirdparty`. This will build MuPDF (plus the libraries it depends
  on), libDjvuLibre, CREngine and Lua.

* run `make`. This will build the kpdfview application


Running
=======

The user interface (or what's there yet) is scripted in Lua. See "reader.lua".
It uses the Linux feature to run scripts by using a corresponding line at its
start.

So you might just call that script. Note that the script and the kpdfview
binary currently must be in the same directory.

You would then just call reader.lua, giving the document file path, or any
directory path, as its first argument. Run reader.lua without arguments to see
usage notes.  The reader.lua script can also show a file chooser: it will do
this when you call it with a directory (instead of a file) as first argument.


Device emulation
================

The code also features a device emulation. You need SDL headers and library
for this. It allows to develop on a standard PC and saves precious development
time. It might also compose the most unfriendly desktop PDF reader, depending
on your view.

If you are using Fedora Core Linux, do `yum install SDL SDL-devel`.
If you are using Ubuntu, do `apt-get install libsdl-dev1.2` package.

To build in "emulation mode", you need to run make like this:
	make clean cleanthirdparty
	EMULATE_READER=1 make thirdparty kpdfview

And run the emulator like this:
```
./reader.lua /PATH/TO/PDF.pdf
```

or:
```
./reader.lua /ANY/PATH
```

To keep things simple, put your pdf files in directory `test`, and run
the emulator like this:
```
./reader.lua test
```

By default emulation will provide K3 resolution of 600*800. It can be
specified at compile time, this is example for Kindle DX:

```
EMULATE_READER_W=824 EMULATE_READER_H=1200 EMULATE_READER=1 make thirdparty kpdfview
```

At this time, you can not have both arm and x86 compiled libraries on your computer.
When compiling for the emulator after having compiled for the Kindle (and vice versa), 
be sure to run
```
make clean cleanthirdparty
```

You can compile and make launchpad installable package for Kindle using
```
make thirdparty kpdfview customupdate
```

Prefered toolchain for Kindle compiling is Code Sourcery/Mentor Graphics 2012.03-57.

