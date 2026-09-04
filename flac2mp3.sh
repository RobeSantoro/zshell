#!/bin/bash

show_help() {
    local script_name
    script_name=$(basename "$0")

    cat <<EOF
Usage: ./$script_name [options] files... [existing_output_directory]

Description:
  Converts one or more FLAC audio files to MP3 using ffmpeg.
  By default, files are saved beside their sources using high-quality VBR.

Options:
  -q, --quality N         VBR quality from 0 (best) to 9 (smallest). Default: 2.
  -b, --bitrate RATE      Use constant bitrate, for example 192k or 320k.
  -o, --output-dir DIR    Save MP3s in DIR, creating it when necessary.
  -f, --force             Overwrite existing MP3 files.
  --delete-original, --DO Delete each FLAC after its MP3 is safely written.
  -h, --help              Show this help message.
  --                      Treat all remaining arguments as file names.

Examples:
  1. Convert specific files (saves in the same folders):
     ./$script_name track1.flac "track 2.flac"

  2. Convert all FLACs in the current folder:
     ./$script_name *.flac

  3. Convert files into an existing output folder:
     ./$script_name *.flac ./converted_audio

  4. Create an output folder and encode every file at 320 kbps:
     ./$script_name --bitrate 320k --output-dir ./converted_audio *.flac

  5. Convert files, then delete each successfully converted FLAC:
     ./$script_name --delete-original *.flac

Notes:
  Text metadata and compatible embedded cover art are preserved.
  Existing MP3s are skipped unless --force is specified. --delete-original
  only removes a FLAC after a successful conversion; skipped and failed files
  are always retained.

Dependency:
  Requires 'ffmpeg' (install on macOS with: brew install ffmpeg)
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

quality=""
bitrate=""
dest_dir=""
dest_dir_was_set=0
force=0
delete_original=0
files_list=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quality)
            [ "$#" -ge 2 ] || fail "$1 requires a value from 0 to 9."
            quality=$2
            shift 2
            ;;
        --quality=*)
            quality=${1#*=}
            shift
            ;;
        -b|--bitrate)
            [ "$#" -ge 2 ] || fail "$1 requires a value such as 192k or 320k."
            bitrate=$2
            shift 2
            ;;
        --bitrate=*)
            bitrate=${1#*=}
            shift
            ;;
        -o|--output-dir)
            [ "$#" -ge 2 ] || fail "$1 requires a directory path."
            dest_dir=$2
            dest_dir_was_set=1
            shift 2
            ;;
        --output-dir=*)
            dest_dir=${1#*=}
            dest_dir_was_set=1
            shift
            ;;
        -f|--force)
            force=1
            shift
            ;;
        --delete-original|--DO)
            delete_original=1
            shift
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                files_list+=("$1")
                shift
            done
            ;;
        -*)
            fail "Unknown option '$1'. Run ./$(basename "$0") --help for usage."
            ;;
        *)
            files_list+=("$1")
            shift
            ;;
    esac
done

case "$quality" in
    ""|[0-9]) ;;
    *) fail "Quality must be a single number from 0 to 9." ;;
esac

if [ -n "$bitrate" ] && [[ ! "$bitrate" =~ ^[0-9]+[kK]$ ]]; then
    fail "Bitrate must be written like 192k or 320k."
fi

if [ -n "$quality" ] && [ -n "$bitrate" ]; then
    fail "Use either --quality or --bitrate, not both."
fi

if [ ${#files_list[@]} -eq 0 ]; then
    fail "No input files specified. Run ./$(basename "$0") --help for usage."
fi

# Preserve the positional output-directory behavior of png2webp.sh. A new
# directory should be passed with --output-dir so it is not mistaken for a file.
if [ "$dest_dir_was_set" -eq 0 ]; then
    last_index=$((${#files_list[@]} - 1))
    last_arg=${files_list[$last_index]}
    if [ -d "$last_arg" ]; then
        dest_dir=$last_arg
        unset "files_list[$last_index]"
        printf 'Output directory detected: %s\n' "$dest_dir"
    fi
fi

if [ ${#files_list[@]} -eq 0 ]; then
    fail "No input files were specified before the output directory."
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    fail "'ffmpeg' is missing. Install it on macOS with: brew install ffmpeg"
fi

if [ "$dest_dir_was_set" -eq 1 ]; then
    if [ -e "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
        fail "Output path '$dest_dir' exists but is not a directory."
    fi
    if [ ! -d "$dest_dir" ] && ! mkdir -p -- "$dest_dir"; then
        fail "Could not create output directory '$dest_dir'."
    fi
fi

if [ -z "$quality" ] && [ -z "$bitrate" ]; then
    quality=2
fi

if [ -n "$bitrate" ]; then
    encoding_args=(-b:a "$bitrate")
    encoding_description="CBR $bitrate"
else
    encoding_args=(-q:a "$quality")
    encoding_description="VBR quality $quality"
fi

current_temp=""
cleanup_temp() {
    if [ -n "$current_temp" ] && [ -f "$current_temp" ]; then
        rm -f -- "$current_temp"
    fi
    current_temp=""
}
trap cleanup_temp EXIT
trap 'exit 130' INT TERM

shopt -s nocasematch
converted=0
deleted=0
skipped=0
failed=0

printf 'Starting conversion (%s)...\n' "$encoding_description"

for flac_file in "${files_list[@]}"; do
    if [ ! -f "$flac_file" ]; then
        printf "Error: '%s' is not a file.\n" "$flac_file" >&2
        failed=$((failed + 1))
        continue
    fi

    if [[ "$flac_file" != *.flac ]]; then
        printf "Ignored: '%s' is not a FLAC file.\n" "$flac_file" >&2
        failed=$((failed + 1))
        continue
    fi

    if [ -n "$dest_dir" ]; then
        base_name=$(basename "$flac_file")
        output_file="$dest_dir/${base_name%.*}.mp3"
    else
        output_file="${flac_file%.*}.mp3"
    fi

    if [ -e "$output_file" ] && [ "$force" -eq 0 ]; then
        printf "Skipped: '%s' already exists (use --force to overwrite).\n" "$output_file"
        skipped=$((skipped + 1))
        continue
    fi

    output_dir=$(dirname "$output_file")
    output_name=$(basename "$output_file")
    if ! current_temp=$(mktemp "$output_dir/.${output_name}.tmp.XXXXXX"); then
        printf "Error: Could not create a temporary file for '%s'.\n" "$output_file" >&2
        failed=$((failed + 1))
        continue
    fi

    # Convert into a temporary file, then move it into place. This prevents a
    # failed conversion from leaving a partial MP3 or destroying an older one.
    if ffmpeg -hide_banner -loglevel error -stats -y \
        -i "$flac_file" \
        -map 0:a:0 -map '0:v?' -map_metadata 0 \
        -c:a libmp3lame "${encoding_args[@]}" \
        -c:v copy -id3v2_version 3 -f mp3 "$current_temp"; then
        if mv -f -- "$current_temp" "$output_file"; then
            current_temp=""
            printf 'Converted: %s -> %s\n' "$flac_file" "$output_file"
            converted=$((converted + 1))
            if [ "$delete_original" -eq 1 ]; then
                if rm -- "$flac_file"; then
                    printf 'Deleted original: %s\n' "$flac_file"
                    deleted=$((deleted + 1))
                else
                    printf "Error: Converted successfully, but could not delete '%s'.\n" "$flac_file" >&2
                    failed=$((failed + 1))
                fi
            fi
        else
            printf "Error: Could not move the converted file to '%s'.\n" "$output_file" >&2
            cleanup_temp
            failed=$((failed + 1))
        fi
    else
        printf "Error converting: '%s'\n" "$flac_file" >&2
        cleanup_temp
        failed=$((failed + 1))
    fi
done

if [ "$delete_original" -eq 1 ]; then
    printf 'Done: %d converted, %d originals deleted, %d skipped, %d failed.\n' \
        "$converted" "$deleted" "$skipped" "$failed"
else
    printf 'Done: %d converted, %d skipped, %d failed.\n' "$converted" "$skipped" "$failed"
fi

if [ "$failed" -gt 0 ]; then
    exit 1
fi
