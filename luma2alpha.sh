#!/bin/bash

# luma2alpha - Transforms the luminance of an image to the alpha channel of a PNG
# Includes heavily boosted contrast and INVERTS the luma so brights = transparent.

# 1. Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_image>"
    exit 1
fi

INPUT="$1"

# 2. Check if the input file actually exists
if [ ! -f "$INPUT" ]; then
    echo "Error: File '$INPUT' does not exist."
    exit 1
fi

# 3. Determine if ImageMagick v7 (magick) or v6 (convert) is installed
if command -v magick &> /dev/null; then
    CMD="magick"
elif command -v convert &> /dev/null; then
    CMD="convert"
else
    echo "Error: ImageMagick is not installed. Please install it first."
    exit 1
fi

# 4. Parse the filename to construct the output path
DIR=$(dirname "$INPUT")
BASE=$(basename "$INPUT")
NAME="${BASE%.*}"

if [ "$DIR" = "." ]; then
    OUTPUT="${NAME}_alpha.png"
else
    OUTPUT="${DIR}/${NAME}_alpha.png"
fi

# 5. Process the image using ImageMagick
# Inside the parentheses: 
#   -colorspace gray       -> converts to luma
#   -sigmoidal-contrast 15 -> boosts contrast heavily
#   -negate                -> inverts it (black becomes white, white becomes black)
$CMD "$INPUT" \
     \( "$INPUT" -colorspace gray -sigmoidal-contrast 15x50% -negate \) \
     -compose CopyOpacity -composite \
     "$OUTPUT"

# 6. Verify success
if [ $? -eq 0 ]; then
    echo "Success! Saved as: $OUTPUT"
else
    echo "Error: Image processing failed."
    exit 1
fi