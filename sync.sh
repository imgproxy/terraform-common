#!/usr/bin/env bash
# Copies shared modules from this repo into the platform modules that vendor them.
#
# Usage: ./sync.sh [target...]
#   With no arguments every target below is synced; otherwise only the named ones.
#
# The copies are overwritten on every run. Do not edit them in the target repos:
# edit the module here and re-run this script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# target repo (relative to ROOT) -> space-separated common modules to copy
declare -a TARGETS=(
  "../terraform-google-imgproxy:imgproxy-common"
)

wanted() {
  [ "$#" -eq 1 ] && return 0
  local name="$1"
  shift
  for arg in "$@"; do
    [ "$arg" = "$name" ] && return 0
  done
  return 1
}

for entry in "${TARGETS[@]}"; do
  target="${entry%%:*}"
  modules="${entry#*:}"
  name="$(basename "$target")"

  wanted "$name" "$@" || continue

  if [ ! -d "$ROOT/$target" ]; then
    echo "error: target directory $ROOT/$target does not exist" >&2
    exit 1
  fi

  for module in $modules; do
    src="$ROOT/$module"
    dest="$ROOT/$target/modules/$module"

    rm -rf "$dest"
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
    rm -rf "$dest/.terraform" "$dest/.terraform.lock.hcl" "$dest/tests" "$dest/README.md"

    echo "synced $module -> $target/modules/$module"
  done
done

echo "Copies are generated: edit the modules in terraform-common and re-run sync.sh."
