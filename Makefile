
PDF ?= magazine.pdf
OUT ?= .
DPI ?= 200

all: pages thumbs count

pages:
	mkdir -p pages
	pdftoppm -jpeg -r $(DPI) $(PDF) pages/page

thumbs:
	mkdir -p thumbs
	mogrify -path thumbs -resize 300x pages/page-*.jpg

count:
	@ls pages/page-*.jpg | wc -l > pagecount.txt
	@echo "Pages:" `cat pagecount.txt`

clean:
	rm -rf pages thumbs pagecount.txt
