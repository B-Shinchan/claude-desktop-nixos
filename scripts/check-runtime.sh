#!/usr/bin/env bash
set -euo pipefail
# The bundled Codex CLI refuses helper aliases under /tmp. Keep all test
# profiles and workspaces in the ignored repository cache instead.
repo=$(pwd)
result=$(realpath "${1:-./result}")
mkdir -p "$repo/.cache"
check_home=$(mktemp -d "$repo/.cache/runtime-home.XXXXXX")
trap 'rm -rf "$check_home"' EXIT
# This exercises the packaged launcher under a real (headless) X11 display.
expected=$(nix eval --raw .#packages.x86_64-linux.default.version)
actual=$(env -u CODEX_HOME HOME="$check_home" XDG_CONFIG_HOME="$check_home/config" XDG_CACHE_HOME="$check_home/cache" XDG_DATA_HOME="$check_home/data" timeout 60s xvfb-run -a dbus-run-session --config-file="$repo/tests/dbus-session.conf" -- "$result/bin/claude-desktop" --version)
printf 'Packaged version: %s\n' "$actual"
test "$actual" = "$expected"
