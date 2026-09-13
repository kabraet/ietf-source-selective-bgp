# Define the source files explicitly based on your local directory structure
ATTR_SRC = bgp-source-selective-attr/draft-braet-idr-bgp-source-selective-attr-01.md
FRAME_SRC = source-selective-bgp-framework/draft-braet-idr-source-selective-bgp-framework-01.md

# Map the final targets we want to generate
TARGET_XML = $(ATTR_SRC:.md=.xml) $(FRAME_SRC:.md=.xml)
TARGET_TXT = $(ATTR_SRC:.md=.txt) $(FRAME_SRC:.md=.html)

.PHONY: all clean xml txt html

# Default rule compiles everything
all: xml txt html

# Rule to convert Markdown (.md) to RFC XMLv3 format (.xml)
%.xml: %.md
	kramdown-rfc $< > $@

# Rule to convert RFC XML to plain text IETF Draft format (.txt)
%.txt: %.xml
	xml2rfc --text $< -o $@

# Rule to convert RFC XML to IETF HTML format (.html)
%.html: %.xml
	xml2rfc --html $< -o $@

# Utility targets to run specific steps
xml: $(TARGET_XML)

txt: $(ATTR_SRC:.md=.txt) $(FRAME_SRC:.md=.txt)

html: $(ATTR_SRC:.md=.html) $(FRAME_SRC:.md=.html)

# Clean up all generated build artifacts
clean:
	rm -f bgp-source-selective-attr/*.xml bgp-source-selective-attr/*.txt bgp-source-selective-attr/*.html
	rm -f source-selective-bgp-framework/*.xml source-selective-bgp-framework/*.txt source-selective-bgp-framework/*.html

