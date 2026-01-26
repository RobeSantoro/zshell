#!/bin/bash

# --- 1. HELP FUNCTION ---
show_help() {
    echo "Usage: $(basename "$0") [options] files... [output_directory]"
    echo ""
    echo "Description:"
    echo "  Converts PNG images to WebP format using cwebp."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message."
    echo ""
    echo "Examples:"
    echo "  1. Convert specific files in place:"
    echo "     ./convert.sh image1.png image2.png"
    echo ""
    echo "  2. Convert all PNGs in current folder in place:"
    echo "     ./convert.sh *.png"
    echo ""
    echo "  3. Convert all PNGs and save to a specific folder:"
    echo "     ./convert.sh *.png ./output_folder"
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

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# --- 4. HANDLE OUTPUT DIRECTORY ---
# Check if the LAST argument is a directory
last_arg="${@: -1}"
dest_dir=""
files_list=("$@") # Start assuming all args are files

if [ -d "$last_arg" ]; then
    echo "📂 Output directory detected: $last_arg"
    dest_dir="$last_arg"
    
    # Remove the last argument from the list of files to process
    # We take a slice of the array from index 0 up to length-1
    unset 'files_list[${#files_list[@]}-1]'
    
    # If list is empty after removing dir (e.g. usage: ./convert.sh output_dir/)
    if [ ${#files_list[@]} -eq 0 ]; then
       echo "Error: No input files specified before the directory."
       exit 1
    fi
fi

# Enable case-insensitive matching for extensions
shopt -s nocasematch

echo "Starting conversion..."

# --- 5. MAIN LOOP ---
for img_file in "${files_list[@]}"; do

  # Check if file exists
  if [ ! -f "$img_file" ]; then
    echo "Skipping '$img_file': File not found."
    continue
  fi

  # Check extension
  if [[ "$img_file" == *.png ]]; then

    # Determine Output Path
    if [ -n "$dest_dir" ]; then
        # Extract just the filename (remove path)
        base_name=$(basename "$img_file")
        # Remove extension and add .webp
        output_file="$dest_dir/${base_name%.*}.webp"
    else
        # Save in the same location
        output_file="${img_file%.*}.webp"
    fi

    # Run conversion (quietly)
    cwebp -q 80 "$img_file" -o "$output_file" -quiet

    if [ $? -eq 0 ]; then
      echo "✅ Converted: $img_file -> $output_file"
    else
      echo "❌ Error converting: $img_file"
    fi
  else
    echo "⚠️  Ignored: '$img_file' is not a PNG."
  fi
done

echo "Done."