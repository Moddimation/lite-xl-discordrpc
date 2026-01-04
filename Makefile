all: build

build: main.c include/*
	@echo building...
	@mkdir -p build
	@gcc -Wall -Iinclude main.c -o build/discord_socket.so -shared -fPIE -fPIC -lm
	@echo done

clean:
	@echo cleaning up...
	@rm -rf build
	@echo done

install: build
	@echo installing...
	@mkdir -p ~/.config/lite-xl/plugins/discord-presence
	@cp *.lua build/*.so ~/.config/lite-xl/plugins/discord-presence/
	@echo done

.PHONY: all clean

