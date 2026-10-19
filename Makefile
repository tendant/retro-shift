# RetroShift developer commands. Run `make` or `make help` to list targets.

GODOT ?= godot
TRACK ?= basic
OPPONENTS ?= 5
GAME_ARGS = --track=$(TRACK) --opponents=$(OPPONENTS)

.DEFAULT_GOAL := help
.PHONY: help run race autodrive debug assets import test clean

help: ## Show this help
	@echo "Usage: make <target> [TRACK=name] [OPPONENTS=0-5] [GODOT=path]"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Tracks: basic gentle hills straight s_curve hillcrest valley crest_into_curve"

run: ## Play from the garage (events, upgrades, saves)
	$(GODOT) --path .

race: ## Free race on TRACK (no rewards)
	$(GODOT) --path . -- $(GAME_ARGS)

autodrive: ## Watch the autopilot drive TRACK
	$(GODOT) --path . -- $(GAME_ARGS) --autodrive

debug: ## Autopilot on TRACK with the debug overlay
	$(GODOT) --path . -- $(GAME_ARGS) --autodrive --debug

assets: ## Regenerate font, sprites and audio from tools/assets/
	python3 tools/assets/gen_font.py
	python3 tools/assets/gen_sprites.py
	python3 tools/assets/gen_audio.py
	$(GODOT) --headless --import

import: ## Re-import assets and refresh the script class cache
	$(GODOT) --headless --import

test: ## Run the GUT test suite headless
	GODOT=$(GODOT) tools/run_tests.sh

clean: ## Delete the Godot import cache (.godot/)
	rm -rf .godot
