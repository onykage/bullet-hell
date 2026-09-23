BIN   := tools/bin
ROJO  := $(BIN)/rojo
LUA   := $(BIN)/stylua
LINT  := $(BIN)/selene
PLACE := build/BulletHell.rbxlx
SRC   := src tests

.PHONY: all setup build serve serve-lan check headless format lint contract sourcemap notify clean

all: check build

## Download the pinned toolchain (rojo, stylua, selene) into tools/bin.
setup:
	@./scripts/setup.sh

$(ROJO):
	@./scripts/setup.sh

## Produce a standalone place file. Open it in Roblox Studio and press Play.
build: $(ROJO)
	@mkdir -p build
	@$(ROJO) build default.project.json --output $(PLACE)
	@echo "Built $(PLACE)"

## Live-sync into a Studio session on THIS machine.
serve: $(ROJO)
	@$(ROJO) serve default.project.json

## Live-sync into Studio on another machine on the LAN.
## Roblox Studio has no Linux build, so the usual setup is: edit here, run this,
## and connect the Rojo plugin from a Windows or macOS box.
serve-lan: $(ROJO)
	@echo "Connect the Rojo Studio plugin to $$(hostname -I | awk '{print $$1}'):34872"
	@$(ROJO) serve default.project.json --address 0.0.0.0 --port 34872

## The CI gate: formatting, static analysis, headless boot, clean build.
check: $(ROJO) headless
	@$(LUA) --check $(SRC)
	@$(LINT) $(SRC)
	@mkdir -p build
	@$(ROJO) build default.project.json --output build/.check.rbxlx >/dev/null
	@rm -f build/.check.rbxlx
	@echo "check: OK"

## Boot the server on Lune and assert the world it builds.
## Catches the "nothing loads" class of failure without Roblox Studio.
## In-engine specs (tests/*.spec.luau) still run on every Studio play-test.
headless: $(BIN)/lune
	@$(BIN)/lune run tests/headless/smoke.luau

$(BIN)/lune:
	@./scripts/setup.sh

format:
	@$(LUA) $(SRC)

lint:
	@$(LINT) $(SRC)

## Regenerate docs/INTEGRATION_CONTRACT.md from Shared/Contract.luau.
contract:
	@python3 scripts/gen-contract.py

sourcemap: $(ROJO)
	@$(ROJO) sourcemap default.project.json --output sourcemap.json

## Post the latest build to the Studio workstream's Discord channel.
## Requires DISCORD_WEBHOOK_URL in the environment.
notify: build
	@./scripts/notify-discord.sh

clean:
	@rm -rf build sourcemap.json
