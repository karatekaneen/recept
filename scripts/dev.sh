#!/usr/bin/env bash
# Lokal förhandsvisning: gör om recepten och startar Hugo.
#   ./scripts/dev.sh           förhandsvisning på http://localhost:1313/ (bygger om vid ändringar)
#   ./scripts/dev.sh --build   fullständigt bygge till public/ med sökindex
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "${1:-}" == "--build" ]]; then
  ./scripts/build-recipes.sh
  hugo --gc --minify
  npx --yes pagefind@1.4.0 --site public
  echo "Klart. Öppna public/ med en webbserver, t.ex.: npx serve public"
  exit 0
fi

./scripts/build-recipes.sh

# Bygg om receptsidorna när något i innehall/ ändras.
watch() {
  while sleep 1; do
    local now
    now="$(find innehall -type f -newer .build/content -print -quit 2>/dev/null || true)"
    if [[ -n "$now" ]]; then
      ./scripts/build-recipes.sh >/dev/null || true
      touch .build/content
    fi
  done
}
watch &
trap 'kill $! 2>/dev/null' EXIT

hugo server --disableFastRender
