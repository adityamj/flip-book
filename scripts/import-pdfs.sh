#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/import-pdfs.sh --source DIR [options]

Input mode A: one subdirectory per magazine
  DIR/
    magazine-one/
      Issue 01.pdf
      Issue 02.pdf
    magazine-two/
      Launch Edition.pdf

Input mode B: one magazine directory with PDFs directly inside
  DIR/
    Issue 01.pdf
    Issue 02.pdf

Output structure:
  CONTENT_ROOT/
    magazine-one/
      _index.md
      issue-01/
        index.md
        page-000.jpg
        pages/page-001.jpg
        thumbs/page-000.jpg

Options:
  --source DIR          Root directory with magazine subdirectories or PDFs directly.
  --magazine SLUG       Magazine slug when SOURCE_DIR contains PDFs directly.
  --magazine-title TXT  Magazine title when SOURCE_DIR contains PDFs directly.
  --content-root DIR    Hugo content root for magazine output.
                        Default: content/magazines
  --dpi NUM             PDF render DPI. Default: 120
  --thumb-width NUM     Thumbnail width in pixels. Default: 300
  --jobs NUM            Parallel workers for page renders/thumbs.
                        Default: detected CPU cores
  --overwrite-jpgs      Rebuild JPG assets for existing issues without touching markdown.
  --force               Rebuild issues even if already processed.
  --help                Show this message.

Notes:
  - The first PDF page becomes page-000.jpg and is used as the cover.
  - Remaining pages become pages/page-001.jpg, pages/page-002.jpg, ...
  - Matching thumbs are created in thumbs/.
  - Existing processed issues are skipped unless --force is used.
  - --overwrite-jpgs rebuilds only JPG assets and preserves existing markdown files.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

default_jobs() {
  if command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n'
  else
    printf '1\n'
  fi
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

human_title() {
  printf '%s' "$1" | tr '_-' ' '
}

escape_yaml() {
  printf '%s' "$1" | sed 's/"/\\"/g'
}

create_section_index() {
  target_file="$1"
  title="$2"

  if [ -f "$target_file" ]; then
    return
  fi

  cat > "$target_file" <<EOF
---
title: "$(escape_yaml "$title")"
type: "magazine"
description: ""
---
EOF
}

create_issue_index() {
  target_file="$1"
  title="$2"

  if [ -f "$target_file" ]; then
    return
  fi

  cat > "$target_file" <<EOF
---
title: "$(escape_yaml "$title")"
date: $(date +%F)
type: "issue"
description: ""

flipbook:
  show_cover: true
  thumb_panel_width: 160
---
EOF
}

is_processed_issue() {
  issue_dir="$1"
  [ -f "$issue_dir/page-000.jpg" ] && [ -d "$issue_dir/pages" ] && [ -d "$issue_dir/thumbs" ]
}

process_pdf() {
  pdf_path="$1"
  magazine_dir="$2"

  pdf_name="$(basename "$pdf_path")"
  issue_name="${pdf_name%.*}"
  issue_slug="$(slugify "$issue_name")"

  if [ -z "$issue_slug" ]; then
    printf 'Skipping PDF with empty slug: %s\n' "$pdf_path" >&2
    return
  fi

  issue_dir="$magazine_dir/$issue_slug"

  if is_processed_issue "$issue_dir"; then
    if [ "$FORCE" = "1" ] || [ "$OVERWRITE_JPGS" = "1" ]; then
      printf 'Rebuilding JPG assets for existing issue: %s\n' "$issue_dir"
    else
      printf 'Skipping existing issue: %s\n' "$issue_dir"
      skipped_count=$((skipped_count + 1))
      return
    fi
  fi

  printf 'Processing %s -> %s\n' "$pdf_path" "$issue_dir"

  if [ "$OVERWRITE_JPGS" = "1" ]; then
    mkdir -p "$issue_dir"
    rm -rf "$issue_dir/pages" "$issue_dir/thumbs"
    rm -f "$issue_dir/page-000.jpg"
  else
    rm -rf "$issue_dir"
  fi

  mkdir -p "$issue_dir/pages" "$issue_dir/thumbs"
  create_issue_index "$issue_dir/index.md" "$(human_title "$issue_name")"

  tmpdir="$(mktemp -d)"
  render_dir="$tmpdir/rendered"

  mkdir -p "$render_dir"

  cleanup_issue_tmpdir() {
    rm -rf "$tmpdir"
  }

  trap cleanup_issue_tmpdir EXIT INT TERM

  page_count="$(pdfinfo "$pdf_path" | awk '/^Pages:/ {print $2; exit}')"

  if [ -z "$page_count" ] || [ "$page_count" -le 0 ]; then
    printf 'Could not determine page count for %s\n' "$pdf_path" >&2
    cleanup_issue_tmpdir
    trap - EXIT INT TERM
    return
  fi

  printf '  Rendering %s pages with %s workers...\n' "$page_count" "$JOBS"
  seq 1 "$page_count" | xargs -P "$JOBS" -I '{}' sh -c '
    page="$1"
    pdf="$2"
    dpi="$3"
    out_dir="$4"
    base=$(printf "%s/page-%06d" "$out_dir" "$page")
    pdftoppm -jpeg -r "$dpi" -f "$page" -l "$page" -singlefile "$pdf" "$base" >/dev/null
  ' sh '{}' "$pdf_path" "$DPI" "$render_dir"

  render_list="$tmpdir/rendered-pages.txt"
  find "$render_dir" -maxdepth 1 -type f -name 'page-*.jpg' | sort -V > "$render_list"

  if [ ! -s "$render_list" ]; then
    printf 'No pages rendered for %s\n' "$pdf_path" >&2
    cleanup_issue_tmpdir
    trap - EXIT INT TERM
    return
  fi

  page_index=0
  while IFS= read -r rendered_page; do
    if [ "$page_index" -eq 0 ]; then
      cp "$rendered_page" "$issue_dir/page-000.jpg"
      cp "$rendered_page" "$issue_dir/thumbs/page-000.jpg"
    else
      output_name="page-$(printf '%03d' "$page_index").jpg"
      cp "$rendered_page" "$issue_dir/pages/$output_name"
      cp "$rendered_page" "$issue_dir/thumbs/$output_name"
    fi
    page_index=$((page_index + 1))
  done < "$render_list"

  printf '  Optimizing full pages as progressive JPEGs...\n'
  find "$issue_dir" -maxdepth 1 -type f -name 'page-*.jpg' -print0 | xargs -0 -P "$JOBS" -I '{}' sh -c '
    image_path="$1"
    mogrify -interlace Plane "$image_path" >/dev/null
  ' sh '{}'

  find "$issue_dir/pages" -maxdepth 1 -type f -name '*.jpg' -print0 | xargs -0 -P "$JOBS" -I '{}' sh -c '
    image_path="$1"
    mogrify -interlace Plane "$image_path" >/dev/null
  ' sh '{}'

  printf '  Building thumbnails with %s workers...\n' "$JOBS"
  find "$issue_dir/thumbs" -maxdepth 1 -type f -name '*.jpg' -print0 | xargs -0 -P "$JOBS" -I '{}' sh -c '
    target_dir="$1"
    width="$2"
    thumb_path="$3"
    mogrify -path "$target_dir" -resize "${width}x" -interlace Plane "$thumb_path" >/dev/null
  ' sh "$issue_dir/thumbs" "$THUMB_WIDTH" '{}'

  cleanup_issue_tmpdir
  trap - EXIT INT TERM

  printf '  Done: %s pages\n' "$page_index"
  processed_count=$((processed_count + 1))
}

SOURCE_DIR=""
MAGAZINE_SLUG=""
MAGAZINE_TITLE=""
CONTENT_ROOT="content/magazines"
DPI="120"
THUMB_WIDTH="300"
FORCE="0"
OVERWRITE_JPGS="0"
JOBS="$(default_jobs)"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --magazine)
      MAGAZINE_SLUG="$2"
      shift 2
      ;;
    --magazine-title)
      MAGAZINE_TITLE="$2"
      shift 2
      ;;
    --content-root)
      CONTENT_ROOT="$2"
      shift 2
      ;;
    --dpi)
      DPI="$2"
      shift 2
      ;;
    --thumb-width)
      THUMB_WIDTH="$2"
      shift 2
      ;;
    --jobs)
      JOBS="$2"
      shift 2
      ;;
    --overwrite-jpgs)
      OVERWRITE_JPGS="1"
      shift 1
      ;;
    --force)
      FORCE="1"
      shift 1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$SOURCE_DIR" ]; then
  usage >&2
  exit 1
fi

require_command find
require_command mktemp
require_command mogrify
require_command pdftoppm
require_command pdfinfo
require_command sort
require_command seq
require_command xargs

case "$JOBS" in
  ''|*[!0-9]*)
    printf 'Invalid --jobs value: %s\n' "$JOBS" >&2
    exit 1
    ;;
esac

if [ "$JOBS" -le 0 ]; then
  printf 'Invalid --jobs value: %s\n' "$JOBS" >&2
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  printf 'Source directory not found: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$CONTENT_ROOT"

processed_count=0
skipped_count=0
found_magazine_dirs=0

top_dir_list="$(mktemp)"
trap 'rm -f "$top_dir_list"' EXIT INT TERM
find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d | sort > "$top_dir_list"

while IFS= read -r candidate_dir; do
  [ -n "$candidate_dir" ] || continue
  found_magazine_dirs=1

  magazine_name="$(basename "$candidate_dir")"
  magazine_slug="$(slugify "$magazine_name")"

  if [ -z "$magazine_slug" ]; then
    printf 'Skipping magazine with empty slug: %s\n' "$magazine_name" >&2
    continue
  fi

  magazine_out_dir="$CONTENT_ROOT/$magazine_slug"
  mkdir -p "$magazine_out_dir"
  create_section_index "$magazine_out_dir/_index.md" "$(human_title "$magazine_name")"

  pdf_found=0
  pdf_list="$(mktemp)"
  find "$candidate_dir" -mindepth 1 -maxdepth 1 -type f \( -iname '*.pdf' \) | sort > "$pdf_list"
  while IFS= read -r pdf_path; do
    [ -n "$pdf_path" ] || continue
    pdf_found=1
    process_pdf "$pdf_path" "$magazine_out_dir"
  done < "$pdf_list"
  rm -f "$pdf_list"

  if [ "$pdf_found" -eq 0 ]; then
    printf 'No PDFs found in %s\n' "$candidate_dir"
  fi
done < "$top_dir_list"

if [ "$found_magazine_dirs" -eq 0 ]; then
  if [ -z "$MAGAZINE_SLUG" ]; then
    MAGAZINE_SLUG="$(slugify "$(basename "$SOURCE_DIR")")"
  fi

  if [ -z "$MAGAZINE_TITLE" ]; then
    MAGAZINE_TITLE="$(human_title "$(basename "$SOURCE_DIR")")"
  fi

  if [ -z "$MAGAZINE_SLUG" ]; then
    printf 'Could not derive magazine slug from source directory: %s\n' "$SOURCE_DIR" >&2
    exit 1
  fi

  magazine_out_dir="$CONTENT_ROOT/$MAGAZINE_SLUG"
  mkdir -p "$magazine_out_dir"
  create_section_index "$magazine_out_dir/_index.md" "$MAGAZINE_TITLE"

  pdf_found=0
  pdf_list="$(mktemp)"
  find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type f \( -iname '*.pdf' \) | sort > "$pdf_list"
  while IFS= read -r pdf_path; do
    [ -n "$pdf_path" ] || continue
    pdf_found=1
    process_pdf "$pdf_path" "$magazine_out_dir"
  done < "$pdf_list"
  rm -f "$pdf_list"

  if [ "$pdf_found" -eq 0 ]; then
    printf 'No PDFs found in %s\n' "$SOURCE_DIR"
  fi
fi

rm -f "$top_dir_list"
trap - EXIT INT TERM

printf '\nDone. Processed: %s, skipped: %s\n' "$processed_count" "$skipped_count"
