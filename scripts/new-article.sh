#!/bin/bash
# Create a new article folder with a filled-in index.md template.
#
#   scripts/new-article.sh <category> "<Title>" [YYYY-MM-DD]
#
# category: architecture | photography | films | writing | other
# The folder is named with the category prefix (A-, P-, F-, W-, O-) + title.
# If the folder already contains images (e.g. after prep-images.sh), a media
# block is added for each image and the first image becomes the teaser/hero.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAT="${1:-}"; TITLE="${2:-}"; DATE="${3:-$(date +%Y-%m-%d)}"

case "$CAT" in
  architecture) P=A ;; photography) P=P ;; films) P=F ;; writing) P=W ;; other) P=O ;;
  *) echo "Usage: $0 <architecture|photography|films|writing|other> \"<Title>\" [YYYY-MM-DD]" >&2; exit 1 ;;
esac
[[ -z "$TITLE" ]] && { echo "Title is required" >&2; exit 1; }
if [[ "$TITLE" =~ [\?\#%/] ]]; then echo "Title must not contain ? # % or / (used in the URL)" >&2; exit 1; fi

DIR="$ROOT/_articles/$CAT/$P-$TITLE"
mkdir -p "$DIR"
if [[ -f "$DIR/index.md" ]]; then echo "index.md already exists in: $DIR" >&2; exit 1; fi

# media blocks from images already in the folder, sorted by name
shopt -s nullglob nocaseglob
imgs=(); for f in "$DIR"/*.{webp,jpg,jpeg,png,gif,avif}; do imgs+=("$(basename "$f")"); done
shopt -u nocaseglob
IFS=$'\n' imgs=($(printf '%s\n' "${imgs[@]}" | sort)); unset IFS
TEASER="${imgs[0]:-}"
HERO=1
if [[ -n "$TEASER" ]]; then
  w=$(sips -g pixelWidth "$DIR/$TEASER" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$DIR/$TEASER" | awk '/pixelHeight/{print $2}')
  (( h > w )) && HERO=3
fi

common_top="---
title: $TITLE
subtitle: 
date: $DATE
teaser: $TEASER
hero_layout: $HERO
landing: true
hidden: false"

case "$CAT" in
  architecture) fields="author: 
co_author: 
supervised_by: 
programme: 
typology: 
completed_as: 
completed_at: 
delivered_at: 
client: 
area: 
location: 
awards: 
collaborators: " ;;
  photography) fields="author: 
co_author: 
publication: 
location: 
client: 
delivered_at: 
medium: 
awards: 
collaborators: " ;;
  films) fields="author: 
co_author: 
publication: 
duration: 
type: 
client: 
supervised_by: 
completed_as: 
completed_at: 
delivered_at: 
awards: 
collaborators: " ;;
  writing) fields="author: 
co_author: 
publication: 
type: 
client: 
topic: 
awards: 
collaborators: " ;;
  other) fields="author: 
co_author: 
publication: 
programme: 
supervised_by: 
typology: 
completed_as: 
completed_at: 
delivered_at: 
client: 
area: 
awards: 
collaborators: 
location: 
medium: 
type: 
topic: 
duration: " ;;
esac

{
  echo "$common_top"
  echo "$fields"
  echo "---"
  echo
  if [[ "$CAT" == "photography" && ${#imgs[@]} -gt 1 ]]; then
    # photography default: all images in one slideshow
    echo "{% $(IFS=,; echo "${imgs[*]}" | sed 's/,/, /g') %}"
    echo
  else
    for img in "${imgs[@]}"; do
      echo "{% $img %}"
      echo
    done
  fi
  [[ ${#imgs[@]} -eq 0 ]] && echo "{% 1.webp %}" && echo
  echo "Write the article text here."
} > "$DIR/index.md"
xattr -c "$DIR/index.md" 2>/dev/null || true

echo "Created: $DIR"
echo "Images:  ${#imgs[@]}  teaser: ${TEASER:-none}  hero_layout: $HERO"
