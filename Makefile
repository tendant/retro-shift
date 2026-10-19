# RetroShift developer commands. Run `make` or `make help` to list targets.

GODOT ?= godot
TRACK ?= basic

.DEFAULT_GOAL := help
.PHONY: help run autodrive debug import test clean

help: ## Show this help
	@echo "Usage: make <target> [TRACK=name] [GODOT=path]"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Tracks: basic straight s_curve hillcrest valley crest_into_curve"

run: ## Play the race on TRACK
	$(GODOT) --path . -- --track=$(TRACK)

autodrive: ## Watch the autopilot drive TRACK
	$(GODOT) --path . -- --track=$(TRACK) --autodrive

debug: ## Autopilot on TRACK with the debug overlay
	$(GODOT) --path . -- --track=$(TRACK) --autodrive --debug

import: ## Re-import assets and refresh the script class cache
	$(GODOT) --headless --import

test: ## Run the GUT test suite headless
	GODOT=$(GODOT) tools/run_tests.sh

clean: ## Delete the Godot import cache (.godot/)
	rm -rf .godot
