CC=gcc \
PLATFORM=osx64 \
LIBNAME=libcairo.dylib \
CFLAGS="-arch x86_64 -mmacosx-version-min=10.6 -Wno-enum-conversion -install_name @loader_path/libcairo.dylib -Wno-attributes -DCAIRO_HAS_PTHREAD=1 -DHAVE_INT128_T" \
IMAGE_SURFACE=1 \
PNG_FUNCTIONS=1 \
RECORDING_SURFACE=1 \
SVG_SURFACE=1 \
PS_SURFACE=1 \
PDF_SURFACE=1 \
FT_FONT=1 \
./build.sh
