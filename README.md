# Flipbook for Hugo

This repo provides a Hugo-ready flipbook setup for a simple publishing model:

- multiple magazines
- each magazine has multiple issues
- each issue opens as a flipbook

`page-000.jpg` is used as the issue cover and also becomes the first page in the book.

## Content Model

Use one section for all magazines:

```text
content/
  magazines/
    _index.md
    gyan-vahini/
      _index.md
      gyan-vahini-01-cancer-cervix-jan-25/
        index.md
        page-000.jpg
        pages/
          page-001.jpg
          page-002.jpg
        thumbs/
          page-000.jpg
          page-001.jpg
          page-002.jpg
```

Routes then become:

- `/` -> library home
- `/magazines/` -> all magazines
- `/magazines/gyan-vahini/` -> all issues for that magazine
- `/magazines/gyan-vahini/gyan-vahini-01-cancer-cervix-jan-25/` -> flipbook

## Naming Conventions

- `page-000.jpg` = cover page
- `pages/page-001.jpg`, `pages/page-002.jpg`, ... = inside pages
- `thumbs/page-000.jpg`, `thumbs/page-001.jpg`, ... = optional thumbnails
- if a thumb is missing, the full-size image is used as a fallback

The layout assumes A4-derived pages.

## Hugo Files Included

- `layouts/index.html` for the home page
- `layouts/magazines/list.html` for the magazine directory
- `layouts/magazine/list.html` for one magazine's issue list
- `layouts/issue/single.html` for the flipbook page
- `layouts/partials/flipbook/` helpers for issue resources and cards
- `assets/js/flipbook/index.js` for the interactive viewer
- `assets/scss/flipbook/styles.scss` for styling
- `archetypes/magazine.md` and `archetypes/issue.md`
- `exampleSite/` with a sample content tree

## Front Matter

Magazine section `content/magazines/gyan-vahini/_index.md`:

```yaml
---
title: "Gyan Vahini"
type: "magazine"
description: "A magazine with multiple issues rendered as flipbooks."
---
```

Issue bundle `content/magazines/gyan-vahini/gyan-vahini-01/index.md`:

```yaml
---
title: "Issue 01"
date: 2026-01-01
type: "issue"
description: "January issue"

flipbook:
  show_cover: true
  thumb_panel_width: 160
---
```

## Viewer Behavior

For each issue bundle, Hugo:

- reads `page-000.jpg` as the cover
- reads and sorts `pages/page-*.jpg`
- pairs each page with `thumbs/page-*.jpg` when present
- emits an issue JSON payload alongside the HTML page
- fetches that JSON in the browser and initializes `page-flip`

Features:

- cover page support from `page-000.jpg`
- lazy-loaded thumbnails
- progressive loading of nearby full pages
- desktop side arrows
- keyboard arrow navigation
- mobile swipe support
- mobile hamburger drawer for thumbnails

## Example Site

See `exampleSite/` for a minimal sample:

```text
exampleSite/
  hugo.toml
  content/
    _index.md
    magazines/
      _index.md
      gyan-vahini/
        _index.md
        issue-2026-01/
          index.md
```

Add your real `page-000.jpg`, `pages/`, and `thumbs/` files to the issue folder.

## Sample Hugo Config

A starter config is included at `hugo.toml`.

If you are running Hugo directly in this repo, you do not need a module import or theme setting. Just edit:

- `baseURL`
- `title`

If you later use this as a theme in another Hugo site:

```toml
theme = "flipbook"
```

If you later publish/use it as a Hugo module, replace the placeholder path in the commented module section with the real module path.

## Theme Customization

The color system is configurable from `hugo.toml` under `[params.flipbook_theme]`.

Example:

```toml
[params.flipbook_theme]
  bg = "#f6f4ee"
  bg_strong = "#e5ece7"
  panel = "#1d3140"
  panel_soft = "#2a4659"
  text = "#1f2933"
  muted = "#667085"
  card = "#ffffff"
  line = "rgba(31, 41, 51, 0.12)"
  accent = "#0f9d8a"
  accent_soft = "#b9ebe4"
  navy = "#173042"
  shadow = "rgba(17, 24, 39, 0.12)"
  font_sans = "'Source Sans 3', 'Helvetica Neue', sans-serif"
```

This lets you reuse the theme with a different palette without editing the SCSS directly.

## Footer and Site Metadata

You can configure the footer from `hugo.toml`.

Example:

```toml
[params]
  description = "A Hugo-powered library of magazine flipbooks."

  [params.footer]
    blurb = "Browse the archive online, open each issue as a flipbook, and read it comfortably on desktop or mobile."
    copyright = "© 2025 Your Organization. All rights reserved."

    [[params.footer.links]]
      label = "Home"
      url = "/"

    [[params.footer.links]]
      label = "Magazines"
      url = "/magazines/"
```

Good candidates to customize here are:

- site description
- copyright text
- footer navigation links

## Archetypes

Create a magazine and issue with:

```bash
hugo new magazines/gyan-vahini/_index.md
hugo new magazines/gyan-vahini/issue-2026-01/index.md
```

Then add the images into that issue bundle.

## PDF Import Helper

If you already have PDFs, use `scripts/import-pdfs.sh`.

Input mode A: one subdirectory per magazine

```text
incoming/
  gyan-vahini/
    Issue 01.pdf
    Issue 02.pdf
  sehat-sandesh/
    Launch Edition.pdf
```

Run:

```bash
scripts/import-pdfs.sh \
  --source incoming \
  --content-root exampleSite/content/magazines
```

To use more CPU cores for high-DPI imports:

```bash
scripts/import-pdfs.sh \
  --source incoming \
  --content-root exampleSite/content/magazines \
  --dpi 300 \
  --jobs 8
```

Input mode B: one magazine folder with PDFs directly inside

```text
incoming/gyan-vahini/
  Issue 01.pdf
  Issue 02.pdf
```

Run:

```bash
scripts/import-pdfs.sh \
  --source incoming/gyan-vahini \
  --content-root exampleSite/content/magazines
```

What it does:

- creates one magazine section per input folder
- creates one issue bundle per PDF using the PDF filename as the issue slug
- renders the first PDF page as `page-000.jpg`
- renders remaining pages as `pages/page-001.jpg`, `pages/page-002.jpg`, ...
- creates matching `thumbs/` images
- skips issues that are already processed unless `--force` is used

Performance tips:

- the importer defaults to `--dpi 120` for faster conversion
- for quick checks, try `--dpi 100`
- use `--jobs N` to parallelize page rendering and thumbnail generation
- increase DPI only when you need higher page fidelity

See `scripts/README.md` for more details.

## Standalone Static Viewer

The original static `index.html` flow still works.

Requirements:

- `pdftoppm` from `poppler-utils`
- `mogrify` from `imagemagick`

Ubuntu/Debian:

```bash
sudo apt install poppler-utils imagemagick
```

Generate pages and thumbs in the repo root:

```bash
make PDF=magazine.pdf
```

Serve locally:

```bash
python3 -m http.server 8080
```

Then open:

```text
http://localhost:8080/index.html
```

## Make Targets

```bash
make                 # build pages, thumbnails, and pagecount.txt
make PDF=issue.pdf   # build from a different PDF
make clean           # remove generated pages, thumbs, and pagecount.txt
```

## Notes

- Hugo mode does not need `pagecount.txt`
- standalone mode still uses `pagecount.txt`
- filenames are expected in zero-padded form such as `page-000.jpg` and `page-001.jpg`
- the Hugo implementation uses the `page-flip` browser build from jsDelivr
- issue pages also publish a JSON representation used by the frontend viewer
