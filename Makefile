# CITYSSEMBLY build
#   make            -> Windows build (dist/cityssembly.exe, SDL2 linked statically)
#   make linux      -> native Linux build (./cityssembly, uses system libSDL2)

NASM     ?= nasm
MINGW    ?= x86_64-w64-mingw32-gcc
CC       ?= gcc
SDL_WIN  := third_party/SDL2-2.30.9/x86_64-w64-mingw32

SRC := $(wildcard src/*.asm src/*.inc)

all: windows

windows: dist/cityssembly.exe
linux: cityssembly

SDL_URL := https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-devel-2.30.9-mingw.tar.gz

deps: $(SDL_WIN)/lib/libSDL2.a

$(SDL_WIN)/lib/libSDL2.a:
	@mkdir -p third_party
	curl -sL $(SDL_URL) | tar xz -C third_party

dist/cityssembly.exe: build/main_win.obj $(SDL_WIN)/lib/libSDL2.a
	@mkdir -p dist
	$(MINGW) -o $@ $< -mwindows -static -static-libgcc \
		-L$(SDL_WIN)/lib -Wl,-Bstatic -lSDL2 -Wl,-Bdynamic \
		-lsetupapi -lwinmm -limm32 -lversion -lole32 -loleaut32 \
		-lgdi32 -luser32 -lkernel32 -lshell32 -luuid -lcfgmgr32 \
		-Wl,--image-base,0x400000 -Wl,--disable-dynamicbase \
		-Wl,--disable-high-entropy-va

build/main_win.obj: $(SRC)
	@mkdir -p build
	$(NASM) -f win64 -DWIN64 -I src/ -o $@ src/main.asm

cityssembly: build/main.o
	$(CC) -no-pie -o $@ $< -l:libSDL2-2.0.so.0 -lm

build/main.o: $(SRC)
	@mkdir -p build
	$(NASM) -f elf64 -g -F dwarf -I src/ -o $@ src/main.asm

clean:
	rm -rf build cityssembly dist/cityssembly.exe

.PHONY: all windows linux clean deps
