#!/bin/bash
# Make small grid thumbnails for article images.
#
#   scripts/make-thumbs.sh [article folder ...]
#
# - With no arguments, walks every article folder under _articles/.
# - For each image in the folder's top level (jpg/jpeg/png/gif/webp/avif), writes
#   thumbs/<same name>.webp, resized to THUMB_EDGE px on the long edge.
# - Skips thumbs that are already newer than their source image.
# - The Work grid (category.html) shows these thumbs instead of the full images, so the
#   grid loads and animates smoothly; the article pages still use the full images.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THUMB_EDGE="${THUMB_EDGE:-720}"
THUMB_Q="${THUMB_Q:-80}"

CWEBP="$(command -v cwebp || true)"
[[ -z "$CWEBP" && -x /opt/homebrew/bin/cwebp ]] && CWEBP=/opt/homebrew/bin/cwebp
if [[ -z "$CWEBP" ]]; then
  echo "cwebp not found. Install with:  brew install webp" >&2; exit 2
fi

if [[ $# -gt 0 ]]; then
  dirs=("$@")
else
  dirs=()
  for d in "$ROOT"/_articles/*/*/; do [[ -f "$d/index.md" ]] && dirs+=("${d%/}"); done
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
made=0; kept=0; total_kb=0
shopt -s nullglob nocaseglob
for d in "${dirs[@]}"; do
  d="${d%/}"
  [[ -d "$d" ]] || { echo "Not a folder: $d" >&2; continue; }
  for f in "$d"/*.{jpg,jpeg,png,gif,webp,avif}; do
    base="$(basename "$f")"; stem="${base%.*}"
    out="$d/thumbs/$stem.webp"
    if [[ -f "$out" && "$out" -nt "$f" ]]; then kept=$((kept+1)); continue; fi
    mkdir -p "$d/thumbs"
    png="$TMP/$stem.png"
    sips -s format png --resampleHeightWidthMax "$THUMB_EDGE" "$f" --out "$png" >/dev/null
    "$CWEBP" -quiet -q "$THUMB_Q" -m 6 -metadata none "$png" -o "$out"
    xattr -c "$out" 2>/dev/null || true
    rm -f "$png"
    kb=$(( $(stat -f%z "$out") / 1024 )); total_kb=$((total_kb+kb))
    printf '  %-60s %4dKB\n' "${d#"$ROOT"/}/thumbs/$stem.webp" "$kb"
    made=$((made+1))
  done
done
shopt -u nocaseglob
echo "Thumbnails made: $made (${total_kb}KB), already up to date: $kept"
