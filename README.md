# Magazine Flipbook

Small static flipbook viewer for turning a PDF magazine into a browsable web experience.

It converts a PDF into full-size page JPGs and thumbnail JPGs, then serves them through a single `index.html` powered by `page-flip`.

## What It Does

- renders a PDF as numbered page images in `pages/`
- creates matching thumbnails in `thumbs/`
- reads the total page count from `pagecount.txt`
- shows a desktop thumbnail rail and a mobile hamburger drawer
- supports click, keyboard arrows, and mobile swipe navigation
- lazy-loads main page images and thumbnail images

## Repo Layout

```text
.
|- index.html
|- Makefile
|- pagecount.txt
|- magazine.pdf
|- pages/
`- thumbs/
```

## Requirements

Install these tools first:

- `pdftoppm` from `poppler-utils`
- `mogrify` from `imagemagick`

Ubuntu/Debian:

```bash
sudo apt install poppler-utils imagemagick
```

## Generate Pages

Place your PDF in the repo root, then run:

```bash
make PDF=magazine.pdf
```

This generates:

- `pages/page-001.jpg`, `pages/page-002.jpg`, ...
- `thumbs/page-001.jpg`, `thumbs/page-002.jpg`, ...
- `pagecount.txt`

Optional:

```bash
make PDF=magazine.pdf DPI=200
```

## Run Locally

Serve the folder with any static web server. Do not open `index.html` directly with `file://`, because the page count is loaded with `fetch()`.

Example:

```bash
python3 -m http.server 8080
```

Then open:

```text
http://localhost:8080/index.html
```

The viewer automatically reads the total page count from `pagecount.txt`.

You can still override it for testing:

```text
http://localhost:8080/index.html?pages=12
```

## Controls

- click a thumbnail to jump to a page
- click the side arrows to go backward or forward
- use keyboard `Left Arrow` and `Right Arrow`
- swipe left or right on mobile
- on mobile, open thumbnails with the hamburger button

## Notes

- filenames are expected in zero-padded form like `page-001.jpg`
- the current layout assumes A4-derived page images
- thumbnails are loaded lazily as you scroll the sidebar
- main page images are loaded progressively around the current spread

## Make Targets

```bash
make                 # build pages, thumbnails, and pagecount.txt
make PDF=issue.pdf   # build from a different PDF
make clean           # remove generated pages, thumbs, and pagecount.txt
```

## Troubleshooting

`Could not load pagecount.txt`
- make sure you are serving the repo through HTTP, not opening `file://`

404s for pages or thumbnails
- confirm the generated files exist in `pages/` and `thumbs/`
- confirm names follow the `page-001.jpg` pattern

Thumbnails do not appear on mobile
- make sure the viewport meta tag remains in `index.html`
- use the hamburger button to open the thumbnail drawer

## Customization

Useful places to tweak:

- `Makefile` for render DPI and thumbnail generation
- `index.html` for layout, navigation, and lazy-loading behavior
