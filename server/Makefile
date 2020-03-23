.PHONY: all run build build-debug check

SRC_ELEMENTS := $(shell find src) # include directory (no -type f) in case elements were deleted

all: run

run: build/server
	./build/server config.toml

build/server: ${SRC_ELEMENTS}
	cmake --build build --config Debug

check:
	clang-tidy -p build src/*