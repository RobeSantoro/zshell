#!/bin/bash

# --- 1. HELP FUNCTION ---
show_help() {
    SCRIPT_NAME=$(basename "$0")
    echo "Usage: ./$SCRIPT_NAME [options] files... [output_directory]"
    echo ""
    echo "Description:"
    echo "  Converts JPG/JPEG images to WebP format using cwebp."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message."
    echo ""
    echo "Examples:"
    echo "  1. Convert specific files:"
    echo "     ./$SCRIPT_NAME image1.jpg image2.jpeg"
    echo ""
    echo "  2. Convert all JPGs in current folder:"
    echo "     ./$SCRIPT_NAME *.jpg"
    echo ""
    echo "  3. Convert all JPGs and save to a folder:"
    echo "     ./$SCRIPT_NAME *.jpg ./converted_images"
    echo ""
    echo "Dependencies:"
    echo "  Requires 'cwebp' (brew install webp)"
}

# --- 2. CHECK DEPENDENCIES ---
if ! command -v cwebp &> /dev/null; then
    echo "Error: 'cwebp' tool is missing."
    echo "Please install it: brew install webp"
    exit 1
fi

# --- 3. CHECK ARGUMENTS ---
if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# --- 4. HANDLE OUTPUT DIRECTORY ---
last_arg="${@: -1}"
dest_dir=""
files_list=("$@")

if [ -d "$last_arg" ]; then
    echo "📂 Output directory detected: $last_arg"
    dest_dir="$last_arg"
    unset 'files_list[${#files_list[@]}-1]'
    if [ ${#files_list[@]} -eq 0 ]; then
       echo "Error: No input files specified before the directory."
       echo "Usage: ./$(basename "$0") *.jpg output_folder"
       exit 1
    fi
fi

# Enable case-insensitive matching
shopt -s nocasematch

echo "Starting conversion..."

# --- 5. MAIN LOOP ---
for img_file in "${files_list[@]}"; do

  if [ ! -f "$img_file" ]; then
    echo "Skipping '$img_file': File not found."
    continue
  fi

  # Check extension (matches .jpg and .jpeg case-insensitive)
  if [[ "$img_file" == *.jpg || "$img_file" == *.jpeg ]]; then

    if [ -n "$dest_dir" ]; then
        base_name=$(basename "$img_file")
        output_file="$dest_dir/${base_name%.*}.webp"
    else
        output_file="${img_file%.*}.webp"
    fi

    cwebp -q 80 "$img_file" -o "$output_file" -quiet

    if [ $? -eq 0 ]; then
      echo "✅ Converted: $img_file -> $output_file"
    else
      echo "❌ Error converting: $img_file"
    fi
  else
    echo "⚠️  Ignored: '$img_file' is not a JPG/JPEG."
  fi
done

echo "Done."
