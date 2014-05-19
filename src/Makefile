VALAC=valac
CC=cc
AR=ar
CFLAGS=`${COMMAND_PREFIX}pkg-config --cflags --libs MagickWand gobject-2.0 zlib` -I../../dmlib/include -L../../dmlib/lib

libdm_logger:
	#	Kompilieren der Library
	${VALAC} -g -X -I. -X -L. -C -H dm_logger.h --thread --pkg zlib --pkg gio-2.0 -X -O3 -g --save-temps --pkg posix --vapidir=../../dmlib/include --pkg dmlib --library dm_logger -X -ldmlib --target-glib=2.32 dm_logger.vala ../../dmlib/src/magick_wand.vapi
	${COMMAND_PREFIX}${CC} -g --shared -fPIC dm_logger.c -o libdm_logger.${LIB_EXT} ${CFLAGS} -ldmlib -lm -I.

	# Kompilieren des Log-Readers
	${VALAC} -g -X -I. -X -L. -C -X -O3 -g --save-temps --pkg posix --pkg zlib --pkg gio-2.0 --vapidir=../../dmlib/include --pkg dmlib -X -ldmlib -X -ldm_logger dm_logreader.vala dm_logger.vapi ../../dmlib/src/magick_wand.vapi
	${COMMAND_PREFIX}${CC} -g -c -o dm_logreader ${CFLAGS} -lm -I. dm_logreader.c
	
	cp *.so ../lib
	cp *.h ../include
	cp *.vapi ../include
	cp -p dm_logreader ../bin
	cp -p preprocess_logger.pl ../bin

