#!/bin/bash
# Convert exported photos to web-ready webp files.
#
#   scripts/prep-images.sh <destination article folder> [source folder] [--archive] [--match "text"]
#
# - --match "text" only takes files whose name contains that text (e.g. "67 Southwark"),
#   so several shoots can sit in the export folder at the same time.
# - Source defaults to the Lightroom export folder (see LR_DIR below).
# - Takes jpg/jpeg/png/tif/tiff/heic (and webp without a jpg sibling),
#   skips "*_compressed.webp" files made by Mass Image Compressor.
# - Resizes to max 1920px on the long edge, encodes webp at quality 60.
# - Keeps the original file name (minus "_compressed"), changes extension to .webp.
# - With --archive, moves the processed originals into
#   "<source>/_published/<article folder name>/" so the export folder stays clean.
set -euo pipefail

LR_DIR="/Users/minsungson/Desktop/03 Personal/02 Photography/02 Lightroom"
MAX_EDGE=1920
QUALITY=60

DEST="${1:-}"
SRC="${2:-$LR_DIR}"
ARCHIVE=0; MATCH=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  [[ "${args[i]}" == "--archive" ]] && ARCHIVE=1
  [[ "${args[i]}" == "--match" ]] && MATCH="${args[i+1]:-}"
done
[[ "$SRC" == --* ]] && SRC="$LR_DIR"

if [[ -z "$DEST" ]]; then
  echo "Usage: $0 <destination folder> [source folder] [--archive]" >&2; exit 1
fi

CWEBP="$(command -v cwebp || true)"
[[ -z "$CWEBP" && -x /opt/homebrew/bin/cwebp ]] && CWEBP=/opt/homebrew/bin/cwebp
if [[ -z "$CWEBP" ]]; then
  echo "cwebp not found. Install with:  brew install webp" >&2; exit 2
fi

mkdir -p "$DEST"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

shopt -s nullglob nocaseglob
files=()
for f in "$SRC"/*.{jpg,jpeg,png,tif,tiff,heic,webp}; do
  base="$(basename "$f")"
  [[ "$base" == *_compressed.webp ]] && continue
  [[ -n "$MATCH" && "$base" != *"$MATCH"* ]] && continue
  if [[ "${base##*.}" =~ ^[Ww][Ee][Bb][Pp]$ ]]; then
    stem="${base%.*}"
    ls "$SRC/$stem".{jpg,jpeg,png,tif,tiff,heic} >/dev/null 2>&1 && continue
  fi
  files+=("$f")
done
shopt -u nocaseglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No images found in: $SRC" >&2; exit 3
fi

IFS=$'\n' files=($(printf '%s\n' "${files[@]}" | sort)); unset IFS

echo "Source:      $SRC"
echo "Destination: $DEST"
echo "Images:      ${#files[@]}"
echo

total_in=0; total_out=0
for f in "${files[@]}"; do
  base="$(basename "$f")"; stem="${base%.*}"; stem="${stem%_compressed}"
  out="$DEST/$stem.webp"
  w=$(sips -g pixelWidth  "$f" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')
  long=$(( w > h ? w : h ))
  png="$TMP/$stem.png"
  if (( long > MAX_EDGE )); then
    sips -s format png --resampleHeightWidthMax "$MAX_EDGE" "$f" --out "$png" >/dev/null
  else
    sips -s format png "$f" --out "$png" >/dev/null
  fi
  "$CWEBP" -quiet -q "$QUALITY" -m 6 -metadata none "$png" -o "$out"
  xattr -c "$out" 2>/dev/null || true
  in_kb=$(( $(stat -f%z "$f") / 1024 )); out_kb=$(( $(stat -f%z "$out") / 1024 ))
  total_in=$((total_in+in_kb)); total_out=$((total_out+out_kb))
  ow=$(sips -g pixelWidth "$out" | awk '/pixelWidth/{print $2}'); oh=$(sips -g pixelHeight "$out" | awk '/pixelHeight/{print $2}')
  flag=""; (( out_kb > 300 )) && flag="  <-- large"
  printf '  %-45s %5dKB -> %4dKB  %dx%d%s\n' "$stem.webp" "$in_kb" "$out_kb" "$ow" "$oh" "$flag"
  rm -f "$png"
done
echo
echo "Total: ${total_in}KB -> ${total_out}KB"

if (( ARCHIVE )); then
  arch="$SRC/_published/$(basename "$DEST")"
  mkdir -p "$arch"
  for f in "${files[@]}"; do mv "$f" "$arch/"; done
  # also tidy any Mass Image Compressor leftovers for these images
  for f in "${files[@]}"; do
    stem="$(basename "${f%.*}")"; [[ -f "$SRC/${stem}_compressed.webp" ]] && mv "$SRC/${stem}_compressed.webp" "$arch/"
  done
  echo "Originals moved to: $arch"
fi
