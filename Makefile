BIN   := tools/bin
ROJO  := $(BIN)/rojo
LUA   := $(BIN)/stylua
LINT  := $(BIN)/selene
PLACE := build/BulletHell.rbxlx
SRC   := src tests

.PHONY: all setup build serve check format lint contract sourcemap notify clean

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

## Live-sync into an open Studio session via the Rojo plugin.
serve: $(ROJO)
	@$(ROJO) serve default.project.json

## The CI gate: formatting + static analysis + a clean build.
## Unit specs run in-engine on every Studio play-test (see TestRunner).
check: $(ROJO)
	@$(LUA) --check $(SRC)
	@$(LINT) $(SRC)
	@mkdir -p build
	@$(ROJO) build default.project.json --output build/.check.rbxlx >/dev/null
	@rm -f build/.check.rbxlx
	@echo "check: OK"

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
