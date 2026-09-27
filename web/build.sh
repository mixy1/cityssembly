#!/bin/bash
# web/build.sh - build the browser version into site/
#   assemble (NASM, same source) -> translate to C -> WebAssembly (Emscripten)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web site
nasm -f elf64 -DWEB -I src/ -o build/web.o src/main.asm
python3 tools/asm2c/translate.py build/web.o build/web/game.c
emcc -O2 ${EMCC_EXTRA:-} -w -Iweb web/runtime.c build/web/game.c \
  -sUSE_SDL=2 -pthread -sPTHREAD_POOL_SIZE=8 -sASYNCIFY -sASYNCIFY_IGNORE_INDIRECT=1 \
  -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=268435456 -sSTACK_SIZE=1048576 \
  -sEXPORTED_RUNTIME_METHODS=ccall -sEXIT_RUNTIME=0 -lidbfs.js \
  --shell-file web/shell.html -o site/index.html
cp web/_headers site/ 2>/dev/null || true
ls -la site
