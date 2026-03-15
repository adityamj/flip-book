# Flip Book

`flip-book` is a Hugo theme for publishing magazine archives as browser-based flipbooks.

This theme is released under the MIT License. See `LICENSE`.

It is built for a simple content model:

- multiple magazines
- each magazine has multiple issues
- each issue is a page bundle rendered as a flipbook

The theme uses `page-000.jpg` as the issue cover and first page, renders the rest of the pages from `pages/`, uses `thumbs/` when available, and serves issue data as JSON for the frontend reader.

## Content Model

```text
content/
  magazines/
    _index.md
    example-magazine/
      _index.md
      issue-2025-01/
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

Routes:

- `/` -> library home
- `/magazines/` -> all magazines
- `/magazines/example-magazine/` -> all issues for that magazine
- `/magazines/example-magazine/issue-2025-01/` -> issue reader

## File Conventions

- `page-000.jpg` = cover page
- `pages/page-001.jpg`, `pages/page-002.jpg`, ... = inner pages
- `thumbs/page-000.jpg`, `thumbs/page-001.jpg`, ... = optional thumbnails
- if a thumb is missing, the page image is used as fallback

The reader assumes A4-derived page images.

## Theme Features

- magazine index and issue index templates
- JSON-backed issue payloads
- PageFlip-based reader
- lazy-loaded thumbnails
- progressive nearby page loading
- desktop arrows
- keyboard arrow navigation
- mobile swipe support
- mobile thumbnail drawer
- fullscreen reading mode
- configurable colors, typography, footer, and metadata

## Upstream Open Source Projects

`flip-book` builds on a small set of upstream open source projects and hosted assets:

- `Hugo` - the static site generator used to build the theme, templates, asset pipeline, and output formats
- `StPageFlip` / `page-flip` - the browser flipbook engine used by the issue reader; loaded from jsDelivr in `layouts/issue/single.html`
- `Source Sans 3` - the default typeface referenced from Google Fonts in `layouts/_default/baseof.html`

Notes:

- this theme's own templates, SCSS, and JavaScript are maintained in this repository
- third-party projects keep their own licenses and notices
- if you vendor or redistribute third-party assets locally, review the upstream repositories and license texts before shipping

## Installation

Use it as a Hugo theme in your site.

1. Add the theme under `themes/flip-book`
2. Set this in your site's `hugo.toml`:

```toml
theme = "flip-book"
```

You can also use this repo directly as a Hugo site for local development.

## Sample Config

A reusable sample config is included at `hugo.toml.example`.

Typical start:

```bash
cp hugo.toml.example hugo.toml
```

Then edit at least:

- `baseURL`
- `title`
- `theme`

Text minification is enabled in the sample config via Hugo's `[minify]` settings.

## Front Matter

Magazine section:

```yaml
---
title: "Example Magazine"
type: "magazine"
description: "A magazine with multiple issues rendered as flipbooks."
---
```

Issue bundle:

```yaml
---
title: "Issue 01"
date: 2025-01-01
type: "issue"
description: "January issue"

flipbook:
  show_cover: true
  thumb_panel_width: 160
---
```

## Theme Customization

Theme colors and fonts are configurable from `hugo.toml` under `[params.flipbook_theme]`.

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

## Footer and Site Metadata

Configure footer content from `hugo.toml`:

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

## Archetypes

Create content with:

```bash
hugo new magazines/example-magazine/_index.md
hugo new magazines/example-magazine/issue-2026-01/index.md
```

Then place `page-000.jpg`, `pages/`, and optional `thumbs/` into that issue bundle.

## Importing PDFs

If you already have magazine PDFs, use `scripts/import-pdfs.sh`.

Input mode A: one subdirectory per magazine

```text
incoming/
  magazine-one/
    Issue 01.pdf
    Issue 02.pdf
  magazine-two/
    Launch Edition.pdf
```

```bash
scripts/import-pdfs.sh \
  --source incoming \
  --content-root content/magazines
```

Input mode B: one magazine folder with PDFs directly inside

```text
incoming/example-magazine/
  Issue 01.pdf
  Issue 02.pdf
```

```bash
scripts/import-pdfs.sh \
  --source incoming/example-magazine \
  --content-root content/magazines
```

What it does:

- creates one magazine section per input folder
- creates one issue bundle per PDF using the PDF filename as the issue slug
- renders the first PDF page as `page-000.jpg`
- renders remaining pages as `pages/page-001.jpg`, `pages/page-002.jpg`, ...
- creates progressive JPEGs for both pages and thumbs
- skips existing issues unless `--force` is used
- supports `--overwrite-jpgs` to rebuild only JPG assets without touching Markdown

Performance tips:

- default render DPI is `120`
- use `--dpi 300` for higher fidelity
- use `--jobs N` to parallelize rendering and thumbnail generation

See `scripts/README.md` for more details.

## Build and Deploy

The Makefile is oriented around Hugo build, compression, and rsync deployment.

```bash
make build
make compress
make deploy RSYNC_DEST=user@host:/var/www/site/
make publish RSYNC_DEST=user@host:/var/www/site/
make clean
```

What they do:

- `make build` builds the Hugo site with minification enabled
- `make compress` creates `.gz`, `.zst`, and `.br` files for text outputs in `public/`
- `make deploy` uploads `public/` with `rsync`
- `make publish` runs build, compress, and deploy in one go
- `make clean` removes the generated `public/` directory

Useful variables:

```bash
make build CONFIG=hugo.toml
make compress JOBS=8
make deploy RSYNC_DEST=user@host:/var/www/site/ RSYNC_OPTS='-avz --delete'
```

## Example Site

See `exampleSite/` for a minimal working content tree and starter config.

## License

This theme is licensed under the MIT License.

Third-party dependencies and externally loaded assets, including `page-flip` and `Source Sans 3`, are licensed by their respective authors under their own terms.

## Notes

- issue pages publish both HTML and JSON outputs
- the frontend reader uses the `page-flip` browser build from jsDelivr
- the theme expects zero-padded filenames such as `page-000.jpg` and `page-001.jpg`
