#!/bin/zsh

# Check if a file was provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 input_file.pdf [DPI (default 150)]"
    exit 1
fi

INPUT="$1"
DPI=${2:-150} # Default 150 DPI (good balance between quality and file size)
FILENAME="${INPUT%.*}"
TEMP_DIR="temp_raster_$(date +%s)"
OUTPUT_FINAL="${FILENAME}_optimized.pdf"

echo "--- Processing started: $INPUT ---"

# 1. Create a temporary directory for raster files
mkdir -p "$TEMP_DIR"

echo "Step 1: Converting PDF to raster images (PNG) at ${DPI} DPI..."
# Convert each page into a numbered PNG file
gs -dNOPAUSE -dBATCH -sDEVICE=png16m -r$DPI -sOutputFile="$TEMP_DIR/page-%03d.png" "$INPUT" > /dev/null

echo "Step 2: Rebuilding PDF from raster files..."
# Merge images into a single temporary PDF
img2pdf "$TEMP_DIR"/page-*.png -o "$TEMP_DIR/raster_draft.pdf"

echo "Step 3: Final PDF optimization..."
# Apply Ghostscript compression profiles to reduce file size
# /ebook is a great compromise. Use /screen for maximum compression (low quality)
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
   -dNOPAUSE -dQUIET -dBATCH \
   -sOutputFile="$OUTPUT_FINAL" "$TEMP_DIR/raster_draft.pdf"

# Cleanup
rm -rf "$TEMP_DIR"

echo "--- Completed! ---"
echo "File created: $OUTPUT_FINAL"
ls -lh "$INPUT" "$OUTPUT_FINAL"
