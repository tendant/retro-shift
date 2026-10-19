#!/usr/bin/env bash
# Runs the GUT suite headless. Usage: tools/run_tests.sh [extra GUT args]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import >/dev/null 2>&1 || true
exec "$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json "$@"
