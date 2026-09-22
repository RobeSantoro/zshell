# zshell

A collection of small command-line scripts for macOS dedicated to converting audio, images, and PDFs, plus simple file-name operations and a launch-at-login helper for DeepSeek Harness.

The scripts are standalone: there is no build process, package manager, or global project configuration. Every utility can be run directly from the repository directory.

## Available scripts

| Script | Purpose | Default output | Dependencies |
| --- | --- | --- | --- |
| `flac2mp3.sh` | Converts one or more FLAC files to MP3 and preserves compatible metadata and cover art | Next to the FLAC, with a `.mp3` extension | `ffmpeg` |
| `mkv2mp3.sh` | Extracts the first audio track from one or more MKV files and encodes it to MP3 | Next to the MKV, with a `.mp3` extension | `ffmpeg` |
| `png2webp.sh` | Converts PNG images to WebP with quality 80 | Next to the PNG, with a `.webp` extension | `cwebp` |
| `jpg2webp.sh` | Converts JPG/JPEG images to WebP with quality 80 | Next to the JPG/JPEG, with a `.webp` extension | `cwebp` |
| `luma2alpha.sh` | Uses inverted, high-contrast luminance as the alpha channel | `<name>_alpha.png` | ImageMagick |
| `flatpdf.sh` | Rasterizes and recompresses a PDF at the chosen resolution | `<name>_optimized.pdf` | Ghostscript, `img2pdf` |
| `prepend.sh` | Adds a prefix to the names of multiple files | Files renamed in place | Standard macOS utilities |
| `ollama-launch-dsh.sh` | Starts `ollama launch dsh` (DeepSeek Harness web) with no Terminal window; it is the program the LaunchAgent runs | - | Ollama, `dsh` from fnm |
| `install-ollama-dsh-login.sh` | Installs or removes the launch-at-login item for DeepSeek Harness | - | Standard macOS utilities |

## Installation

On macOS, all dependencies can be installed with Homebrew:

```bash
brew install ffmpeg webp imagemagick ghostscript img2pdf
```

The scripts in the repository are already executable. If they are not:

```bash
chmod +x ./*.sh
```

## Audio conversion

### FLAC to MP3

```bash
./flac2mp3.sh track.flac
./flac2mp3.sh *.flac
./flac2mp3.sh --quality 0 *.flac
./flac2mp3.sh --bitrate 320k *.flac
./flac2mp3.sh --output-dir ./mp3 *.flac
```

### MKV to MP3

`mkv2mp3.sh` uses the first audio track of the MKV, omits the video, and preserves global metadata compatible with MP3.

```bash
./mkv2mp3.sh recording.mkv
./mkv2mp3.sh *.mkv
./mkv2mp3.sh --quality 0 *.mkv
./mkv2mp3.sh --bitrate 320k --output-dir ./audio *.mkv
```

The options shared by the two converters are:

| Option | Meaning |
| --- | --- |
| `-q N`, `--quality N` | VBR quality from 0, best, to 9, smallest. The default value is 2 |
| `-b RATE`, `--bitrate RATE` | Constant bitrate, for example `192k` or `320k` |
| `-o DIR`, `--output-dir DIR` | Destination directory; it is created if it does not exist |
| `-f`, `--force` | Overwrites MP3s that already exist |
| `--delete-original`, `--DO` | Deletes the source only after a successful conversion |
| `-h`, `--help` | Shows the full help |

You can also pass an already existing destination directory as the last argument:

```bash
./mkv2mp3.sh *.mkv ./existing_audio
```

The audio converters first write to a temporary file and move it to the destination only once finished. Without `--force`, an MP3 that already exists is skipped. With `--delete-original`, skipped files or failed conversions are not deleted.

## Image conversion

### PNG or JPG to WebP

```bash
./png2webp.sh *.png
./png2webp.sh *.png ./existing_webp

./jpg2webp.sh photo.jpg photo.jpeg
./jpg2webp.sh *.jpg ./existing_webp
```

The last argument is interpreted as a destination only if it is an already existing directory. The WebP quality is currently fixed at 80.

### Luminance into the alpha channel

```bash
./luma2alpha.sh image.png
```

The script greatly increases contrast, inverts the luminance, and uses it as transparency: light areas become more transparent, dark areas more opaque.

## PDF optimization

```bash
./flatpdf.sh document.pdf
./flatpdf.sh document.pdf 200
```

The second argument is the resolution in DPI and defaults to 150. The PDF is rasterized page by page and then rebuilt with the Ghostscript `/ebook` profile.

> Rasterization flattens text, vector graphics, links, and other interactive elements. Always keep the original PDF.

## Adding a prefix

The prefix is always the last argument:

```bash
./prepend.sh *.webp "IMG_"
```

Run `prepend.sh` from the directory containing the files and pass simple relative names. The script renames files in place and does not offer a preview mode.

## Finder Quick Actions

The scripts can be invoked from Automator through a **Run Shell Script** action, using `/bin/bash` and passing the input as arguments.

On this machine the installed actions are located in:

```text
~/Library/Services/
```

The Automator workflows are not versioned in this repository: they contain local absolute paths to the scripts. After adding or modifying a Quick Action, enable it from **Finder → Quick Actions → Customize…** or from the macOS extensions settings.

The `Convert MKV to MP3` Quick Action accepts Finder items generically because macOS Sonoma may not associate MKVs with a standard video type; before running `ffmpeg`, the workflow still verifies that every file has a `.mkv` extension.

## DeepSeek Harness at login

`install-ollama-dsh-login.sh` installs a LaunchAgent that runs `ollama launch dsh`
when you log in. Because it is a LaunchAgent rather than a login item, it starts
in the background with no Terminal window and no Dock icon, and it appears in
**System Settings → General → Login Items & Extensions** under **Allow in the
Background**.

```bash
./install-ollama-dsh-login.sh install     # install and load (default)
./install-ollama-dsh-login.sh status      # launchd state, port, log
./install-ollama-dsh-login.sh restart     # stop and start again
./install-ollama-dsh-login.sh uninstall   # stop and remove
```

The agent runs `ollama-launch-dsh.sh`, a wrapper rather than the bare command,
because launchd starts jobs with a minimal `PATH`: `dsh` is installed in the fnm
global bin and would not be found. The wrapper also stands down when DSH web is
already listening on port 3080, so a manually started instance and the login item
never fight over the port; waits briefly for the Ollama server, which is itself a
login item; and passes `-y`, since a background job has no terminal to answer
prompts on.

DSH uses the `WorkingDirectory` of `com.robe.ollama-launch-dsh.plist` as its
workspace, and writes its log to `~/Library/Logs/ollama-launch-dsh.log`.

## Safety and overwriting

- Use `--delete-original` only when you really want to remove the audio or video sources.
- `flac2mp3.sh` and `mkv2mp3.sh` protect existing outputs unless `--force` is used explicitly.
- The WebP scripts, `luma2alpha.sh`, `flatpdf.sh`, and `prepend.sh` do not implement the same full protection: check the destination names in advance.
- Enclose paths containing spaces in quotes.

## Quick verification

There is no automated test suite. You can at least verify the syntax with:

```bash
bash -n flac2mp3.sh install-ollama-dsh-login.sh jpg2webp.sh luma2alpha.sh mkv2mp3.sh ollama-launch-dsh.sh png2webp.sh prepend.sh
zsh -n flatpdf.sh
```

For the specific help of a script that supports it:

```bash
./mkv2mp3.sh --help
```
