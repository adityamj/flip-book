SHELL := /bin/sh

HUGO ?= hugo
CONFIG ?= hugo.toml
PUBLIC_DIR ?= public
JOBS ?= 8

GZIP ?= gzip
ZSTD ?= zstd
BROTLI ?= brotli
RSYNC ?= rsync

HUGO_FLAGS ?= --gc --minify --config $(CONFIG)
TEXT_FILE_EXPR = \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.json' -o -name '*.xml' -o -name '*.svg' -o -name '*.txt' -o -name '*.csv' -o -name '*.map' \)

RSYNC_SRC ?= $(PUBLIC_DIR)/
RSYNC_DEST ?=
RSYNC_OPTS ?= -avz --delete

.PHONY: help build compress deploy publish clean check-tools check-rsync

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make build      - Build the Hugo site with minification enabled' \
	  '  make compress   - Create .gz, .zst, and .br files for text outputs under public/' \
	  '  make deploy     - Rsync public/ to RSYNC_DEST' \
	  '  make publish    - Build, compress, and deploy' \
	  '  make clean      - Remove the generated public/ directory' \
	  '' \
	  'Important variables:' \
	  '  CONFIG=<file>        Hugo config file (default: hugo.toml)' \
	  '  PUBLIC_DIR=<dir>     Hugo publish dir (default: public)' \
	  '  JOBS=<n>             Parallel workers for compression (default: 8)' \
	  '  RSYNC_DEST=<target>  Required for deploy/publish, e.g. user@host:/var/www/site/' \
	  '  RSYNC_OPTS=<opts>    Rsync flags (default: -avz --delete)'

check-tools:
	@command -v $(HUGO) >/dev/null 2>&1 || { printf 'Missing command: %s\n' '$(HUGO)' >&2; exit 1; }
	@command -v $(GZIP) >/dev/null 2>&1 || { printf 'Missing command: %s\n' '$(GZIP)' >&2; exit 1; }
	@command -v $(ZSTD) >/dev/null 2>&1 || { printf 'Missing command: %s\n' '$(ZSTD)' >&2; exit 1; }
	@command -v $(BROTLI) >/dev/null 2>&1 || { printf 'Missing command: %s\n' '$(BROTLI)' >&2; exit 1; }
	@command -v xargs >/dev/null 2>&1 || { printf 'Missing command: xargs\n' >&2; exit 1; }
	@command -v find >/dev/null 2>&1 || { printf 'Missing command: find\n' >&2; exit 1; }

build: check-tools
	$(HUGO) $(HUGO_FLAGS)

compress: check-tools
	@test -d "$(PUBLIC_DIR)" || { printf 'Directory not found: %s\n' '$(PUBLIC_DIR)' >&2; exit 1; }
	@printf 'Compressing text outputs in %s with %s workers\n' '$(PUBLIC_DIR)' '$(JOBS)'
	@find "$(PUBLIC_DIR)" -type f $(TEXT_FILE_EXPR) -print0 | xargs -0 -P $(JOBS) -n 16 $(GZIP) -kf
	@find "$(PUBLIC_DIR)" -type f $(TEXT_FILE_EXPR) -print0 | xargs -0 -P $(JOBS) -n 16 $(ZSTD) -q -f -k
	@find "$(PUBLIC_DIR)" -type f $(TEXT_FILE_EXPR) -print0 | xargs -0 -P $(JOBS) -n 16 $(BROTLI) -f -k -q 11

check-rsync:
	@command -v $(RSYNC) >/dev/null 2>&1 || { printf 'Missing command: %s\n' '$(RSYNC)' >&2; exit 1; }
	@test -n "$(RSYNC_DEST)" || { printf 'RSYNC_DEST is required. Example: make deploy RSYNC_DEST=user@host:/var/www/site/\n' >&2; exit 1; }

deploy: check-rsync
	@test -d "$(PUBLIC_DIR)" || { printf 'Directory not found: %s\n' '$(PUBLIC_DIR)' >&2; exit 1; }
	$(RSYNC) $(RSYNC_OPTS) "$(RSYNC_SRC)" "$(RSYNC_DEST)"

publish: build compress deploy

clean:
	rm -rf "$(PUBLIC_DIR)"
