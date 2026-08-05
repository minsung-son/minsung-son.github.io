# Article Manual
## 1. Overall

Every article is **one folder** containing:
- `index.md`: the article's text file (metadata + body), and
- all of the article's **media files** (images and videos), sitting directly next to `index.md`.

The folder location decides the category. The folder lives inside one of the five category folders (the about page lives separately):
```
_articles/
  architecture/
  films/
  other/
  photography/
  writing/
      My New Article/
          index.md
          1.webp
          2.webp
          clip.mp4
about/
  index.md
```

Once in place and pushed to GitHub, it should be applied automatically in a couple minutes.

## 2. Naming the folder
- The folder name becomes part of the article's **URL**.
- Spaces are fine: `A shell and a society of stairs`.
- An optional `X-` prefix (e.g. `A-`, `P-`, `W-`) is fine for your own sorting; it is stripped from the fallback title.

**No-gos:**
- Never use `?`, `#`, `%`, or `/` in the folder name. These have special meaning in URLs and will break links (I already had to rename a folder to remove a `?`).
- Don't nest folders. Media must sit **directly** inside the article folder, not in a `photos/` subfolder.
- The text file must be named exactly `index.md`.

## 3. Metadata (the block between `---` lines)

The top of `index.md` looks like this:
```yaml
---
title: The House of Stories
subtitle: A public children's library for a Cambridge college
date: 2025-03-14
teaser: 2.webp
hero_layout: 1
landing: true
hidden: false
author: Minsung Son
typology: Library
location: Cambridge, UK
---
```

### Important fields
| Field         | What it does                                                 | If missing                                                   |
|---------------|--------------------------------------------------------------|--------------------------------------------------------------|
| `title`       | Article title                                                | FATAL                                                        |
| `subtitle`    | Shown under the title                                        | Simply omitted                                               |
| `date`        | Full date (`YYYY-MM-DD`) used for sorting and project IDs. Only the year is displayed. | FATAL                                      |
| `teaser`      | The image representing the article in the grid view and on the landing page | Falls back to the first image in the folder<br>If no images at all, FATAL |
| `hero_layout` | `1`, `2`, or `3` (as per draft)                              | Defaults to `1`                                              |
| `landing`     | `true` = article appears in the home-page teaser rotation (needs a teaser image!) | Treated as `false`                                           |
| `hidden`      | `true` = article does not appear in the grid, list, or landing page (still occupies a project ID) | Treated as `false`                                           |

### Metadata fields (the table at the top of the article)
Any of these you fill in appear as a labelled row; **empty fields are simply not shown**, so leaving lines blank is completely safe (the templates list them all as a reminder):

`author`, `co_author`, `supervised_by`, `publication`, `programme`, `typology`, `completed_as`, `completed_at`, `delivered_at`, `client`, `area`, `location`, `medium`, `type`, `topic`, `duration`, `awards`, `collaborators`

Values can contain **links** in Markdown form. Put them in **quotes**:
  `completed_at: "[University of Cambridge](https://arct.cam.ac.uk)"`

### The fourth list-view column
The list view shows *Number · Title · Year · [category-specific field]*. Fill in the right one!!
| Category     | Fill in                                       |
|--------------|-----------------------------------------------|
| architecture | typology (e.g. *Library*)                     |
| photography  | location (e.g. *Seoul, Korea*)                |
| films        | type (e.g. *Stop-motion short*)               |
| writing      | publication (e.g. *New Architecture Writers*) |
| other        | N/A (shows the category name)                 |

### Metadata no-gos
Watch out for stray colons or unquoted special characters in metadata values. If a value contains special characters or quotes, wrap the whole value in double quotes: `subtitle: "Building study: V&A East"`. If unsure, wrap in double quotes.

## 4. The body: text and media blocks

Below the second `---` comes the article itself: plain paragraphs of text, optional `##` headings, and **media blocks**.

```markdown
## An optional heading text

A normal paragraph of text. Blank lines separate paragraphs.

{% 1.webp %}

Another paragraph.

{% 2.webp, 3.webp, 4.webp | A shared caption for this slideshow. %}

{% clip.mp4 | A caption for the video. %}

{% https://vimeo.com/446179582 | A Vimeo embed. %}
```

### Media block reference

| You write                                  | You get                                                      |
|--------------------------------------------|--------------------------------------------------------------|
| `{% 1.webp %}`                             | A single image                                               |
| `{% 1.webp, 2.webp, 3.webp \\| Caption %}` | A single image with a caption                                |
| `{% 1.webp, 2.webp, 3.webp \| Caption %}`  | A click-through **slideshow** with one shared caption and a counter (1/3) |
| `{% clip.mp4 \| Caption %}`                | A **video** player                                           |
| `{% vimeo:446179582 \| Caption %}`         | A **Vimeo embed** (a full URL like `https://vimeo.com/446179582` also works, including unlisted links) |
| `{% vimeo:446179582 9:16 \| Caption %}`    | Vimeo embed with an explicit aspect ratio (default is 16:9). The site **cannot automatically fetch the aspect ratio**, so for any video that is not 16:9, set this value! |

Accepted image formats: `jpg / jpeg / png / gif / webp / avif`. Accepted video formats: `mp4 / mov / webm / m4v`.

### The website is forgiving…
These mistakes are tolerated and quietly fixed: wrong upper/lower case in a filename, a wrong or missing file extension, `{{ … }}` instead of `{% … %}`.

If a file genuinely can't be found, a red warning box appears in its place (and in the GitHub build log) so the mistake is visible instead of breaking the site.

### But these are hard no-gos
- **A video can never be inside a slideshow.**
- **Never type `{%`, `%}`, `{{`, or `}}` inside normal text**. Anything between those braces is treated as a media block and will turn into a warning box.
- Media blocks reference files **in the same folder only**. You can't point at another article's images or an outside URL (except Vimeo).
- Put each media block **on its own line**, with blank lines around it.

## 5. The hero (the first media block)
The **first media block in the body becomes the article's hero**: the large image at the top. Choose its layout with `hero_layout`:

| Value | Layout | Best for |
|---|---|---|
| `1` | Flush with the sheet's left edge | **Landscape** first image (default) |
| `2` | Flush with the text column's left edge | **Landscape** first image, quieter |
| `3` | Centred | **Portrait** first image |

On mobile the hero is always centred and this setting only affects desktop.

## 6. Good practices for prepping images
- **Format:** prefer `.webp` (much smaller than jpg/png at the same quality). Existing articles use webp almost everywhere. Use **Mass Image Compressor** at quality medium (60), max long-side size 1920, and format webp. Target 50-200KB for a single image.
- **Size:** export around 1920px on the long edge. Big enough for the full-screen enlarged view, small enough to load fast. NEVER upload straight-from-camera multi-MB images.
- **Naming:** number files in the order you want (`1.webp`, `2.webp`, …, or a dated prefix like `20250904 Arumjigi-2.webp`). Use simple latin characters and numbers for filenames, no special characters.
- **Every image in the folder is part of the article's image set** (used by the full-screen enlarged view), even if you never reference it in a media block. Don't leave stray draft images or alternates in the folder.

## 7. Checklist for a new article
1. Duplicate the closest **template or existing article** for the category
2. Rename the folder (again, no `?`, `#`, `%`, `/`).
3. Compress any images you have with Mass Image Compressor, upload any >10MB videos to Vimeo.
4. Drop your prepared images/videos into the folder.
5. Fill in the front matter, at minimum `title`, `date`, `teaser`, `hero_layout`, and the category's 4th-column field. Write dates as `YYYY-MM-DD`.
6. Write the body; first media block is hero.
7. Push to GitHub using the GitHub Desktop app or terminal.
8. Wait ~10mins. If not applying, check GitHub build logs and/or consult ChatGPT Codex.
