#!/usr/bin/env python3
"""Static checks for article folders, mirroring the rules in ARTICLE_MANUAL.md.

    scripts/check-article.py "_articles/photography/P-Barbican"   # one article
    scripts/check-article.py                                       # every article

Exit code 1 if any ERROR was found. WARNINGs never block publishing.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTICLES = os.path.join(ROOT, "_articles")
IMAGE_EXT = (".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif")
VIDEO_EXT = (".mp4", ".mov", ".webm", ".m4v")
CATEGORY_FIELD = {"architecture": "typology", "photography": "location",
                  "films": "type", "writing": "publication", "other": None}
KNOWN_FIELDS = {"title", "subtitle", "date", "teaser", "hero_layout", "landing", "hidden",
                "category", "author", "co_author", "supervised_by", "publication", "programme",
                "typology", "completed_as", "completed_at", "delivered_at", "client", "area",
                "location", "medium", "type", "topic", "duration", "awards", "collaborators"}
BIG_IMAGE_KB = 400


def parse_front_matter(text):
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        return None, text
    fm = {}
    for line in m.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#") or line.startswith((" ", "-")):
            continue
        if ":" not in line:
            fm.setdefault("__bad_lines__", []).append(line)
            continue
        k, v = line.split(":", 1)
        v = v.split("#", 1)[0] if not v.strip().startswith(("'", '"')) else v
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm, m.group(2)


def check(folder):
    errors, warns = [], []
    name = os.path.basename(folder.rstrip("/"))
    category = os.path.basename(os.path.dirname(folder.rstrip("/")))
    if category not in CATEGORY_FIELD:
        errors.append(f"folder is not inside one of the category folders: {category}")
    for ch in "?#%/":
        if ch in name:
            errors.append(f"folder name contains '{ch}' which breaks URLs")
    index = os.path.join(folder, "index.md")
    if not os.path.isfile(index):
        errors.append("index.md is missing")
        return errors, warns
    files = [f for f in os.listdir(folder) if not f.startswith(".") and f != "index.md"]
    for f in files:
        p = os.path.join(folder, f)
        if os.path.isdir(p):
            errors.append(f"nested folder '{f}' (media must sit directly next to index.md)")
        elif not f.lower().endswith(IMAGE_EXT + VIDEO_EXT):
            warns.append(f"unexpected file '{f}' (not an image/video)")
        elif re.search(r"[^\w .\-()&',]", f):
            warns.append(f"filename '{f}' has special characters; prefer plain letters/numbers")
        if f.lower().endswith(IMAGE_EXT):
            kb = os.path.getsize(p) // 1024
            if kb > BIG_IMAGE_KB:
                warns.append(f"'{f}' is {kb}KB (target 50-200KB; re-run prep-images)")
            if kb > 10 * 1024:
                errors.append(f"'{f}' is {kb // 1024}MB (NEVER upload raw camera files)")
        if f.lower().endswith(VIDEO_EXT) and os.path.getsize(p) > 10 * 1024 * 1024:
            warns.append(f"video '{f}' is over 10MB; consider Vimeo instead")
    images = sorted(f for f in files if f.lower().endswith(IMAGE_EXT))
    lower_files = {f.lower(): f for f in files}
    stems = {os.path.splitext(f.lower())[0]: f for f in files}

    text = open(index, encoding="utf-8").read()
    fm, body = parse_front_matter(text)
    if fm is None:
        errors.append("front matter block (--- ... ---) not found at top of index.md")
        return errors, warns
    for bad in fm.get("__bad_lines__", []):
        errors.append(f"front matter line without a colon: {bad!r}")
    if not fm.get("title"):
        errors.append("title is missing (FATAL on build)")
    date = fm.get("date", "")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        errors.append(f"date must be YYYY-MM-DD, got: {date!r} (FATAL on build)")
    teaser = fm.get("teaser", "")
    if teaser:
        if teaser.lower() not in lower_files and os.path.splitext(teaser.lower())[0] not in stems:
            errors.append(f"teaser '{teaser}' not found in folder")
    elif not images:
        errors.append("no teaser and no images in folder (FATAL on build)")
    elif fm.get("landing", "").lower() == "true":
        warns.append("landing: true but no teaser set; first image will be used")
    if fm.get("hero_layout", "1") not in ("1", "2", "3", ""):
        errors.append(f"hero_layout must be 1, 2 or 3, got {fm['hero_layout']!r}")
    for k in ("landing", "hidden"):
        if fm.get(k, "") not in ("", "true", "false"):
            errors.append(f"{k} must be true or false, got {fm[k]!r}")
    for k in fm:
        if k not in KNOWN_FIELDS and not k.startswith("__"):
            warns.append(f"unknown front matter field '{k}' (will be ignored)")
    for k, v in fm.items():
        if v and not v.startswith(("[", '"')) and ": " in v:
            warns.append(f"'{k}' value contains ': ' — wrap it in double quotes to be safe")
    col = CATEGORY_FIELD.get(category)
    if col and not fm.get(col):
        warns.append(f"'{col}' is empty; it is the 4th column in the {category} list view")

    # body: media blocks
    blocks = re.findall(r"\{[%{]\s*(.*?)\s*[%}]\}", body, re.S)
    if not blocks:
        warns.append("body has no media block, so the article has no hero image")
    referenced = set()
    for raw in blocks:
        media = raw.split("|", 1)[0].strip()
        if media.startswith(("http", "vimeo:")):
            if "vimeo" not in media:
                errors.append(f"only Vimeo URLs are allowed in media blocks: {media}")
            continue
        items = [i.strip() for i in media.split(",") if i.strip()]
        vids = [i for i in items if i.lower().endswith(VIDEO_EXT)]
        if len(items) > 1 and vids:
            errors.append(f"a video can never be inside a slideshow: {media}")
        for it in items:
            it_l = it.lower()
            if it_l in lower_files:
                referenced.add(lower_files[it_l])
            elif os.path.splitext(it_l)[0] in stems:
                referenced.add(stems[os.path.splitext(it_l)[0]])
                warns.append(f"'{it}' referenced with a different extension than the file on disk")
            else:
                errors.append(f"media block references '{it}' but no such file in folder")
    for line in body.splitlines():
        s = line.strip()
        if re.search(r"\{%|%\}|\{\{|\}\}", s) and not re.fullmatch(r"\{[%{].*[%}]\}", s):
            errors.append(f"media block must be alone on its line: {s[:60]!r}")
    unref = [f for f in images if f not in referenced and f.lower() != teaser.lower()]
    if unref:
        warns.append("images in folder not used in any media block (still shown in the full-screen set): "
                     + ", ".join(unref))
    return errors, warns


def main():
    if len(sys.argv) > 1:
        folders = [os.path.abspath(a) for a in sys.argv[1:]]
    else:
        folders = sorted(os.path.join(ARTICLES, c, a) for c in os.listdir(ARTICLES)
                         if os.path.isdir(os.path.join(ARTICLES, c))
                         for a in os.listdir(os.path.join(ARTICLES, c))
                         if os.path.isdir(os.path.join(ARTICLES, c, a)))
    failed = False
    for folder in folders:
        errors, warns = check(folder)
        rel = os.path.relpath(folder, ROOT)
        status = "ERROR" if errors else ("WARN" if warns else "OK")
        print(f"[{status}] {rel}")
        for e in errors:
            print(f"    ERROR: {e}")
        for w in warns:
            print(f"    warn:  {w}")
        failed |= bool(errors)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
