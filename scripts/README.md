# Import Helpers

`import-pdfs.sh` converts a source directory of magazine PDFs into the Hugo magazine/issue bundle structure used by this repo.

Expected source layout:

```text
incoming/
  magazine-one/
    Issue 01.pdf
    Issue 02.pdf
  magazine-two/
    Launch Edition.pdf
```

It also supports a single magazine folder with PDFs directly inside:

```text
incoming/example-magazine/
  Issue 01.pdf
  Issue 02.pdf
```

Example:

```bash
scripts/import-pdfs.sh \
  --source incoming \
  --content-root exampleSite/content/magazines
```

Single-magazine example:

```bash
scripts/import-pdfs.sh \
  --source incoming/example-magazine \
  --content-root exampleSite/content/magazines
```

Use more CPU cores during import:

```bash
scripts/import-pdfs.sh \
  --source incoming \
  --content-root exampleSite/content/magazines \
  --dpi 300 \
  --jobs 8
```

This creates issue bundles like:

```text
exampleSite/content/magazines/example-magazine/issue-01/
  index.md
  page-000.jpg
  pages/page-001.jpg
  thumbs/page-000.jpg
```

Behavior:

- first PDF page becomes `page-000.jpg`
- remaining pages become `pages/page-001.jpg`, `pages/page-002.jpg`, ...
- full pages and thumbs are written as progressive JPEGs
- `_index.md` is created for each magazine if missing
- already processed issues are skipped unless `--force` is used

Performance tips:

- the importer defaults to `--dpi 120` for faster page rendering
- use `--dpi 100` or lower for quick test imports
- use `--jobs N` to render PDF pages and thumbnails in parallel
- use `--force` only when you really need to rebuild an existing issue
