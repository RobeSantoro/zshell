# Agent instructions

## Repository scope

This repository contains standalone shell utilities for macOS. There is no build system, no vendored dependency, and no automated test. Changes must stay small, readable, and consistent with the purpose of the individual script.

These instructions apply to the entire project directory.

## Project map

- `flac2mp3.sh`: FLAC → MP3 conversion with `ffmpeg`, safe temporary output, and optional deletion of the source.
- `mkv2mp3.sh`: extraction of the first MKV audio track → MP3 with the same guarantees as `flac2mp3.sh`.
- `png2webp.sh` and `jpg2webp.sh`: image conversion with `cwebp`, quality fixed at 80.
- `luma2alpha.sh`: alpha channel compositing with ImageMagick.
- `flatpdf.sh`: PDF rasterization and recompression; it is the only Zsh script.
- `prepend.sh`: destructive in-place rename by adding a prefix.
- `ollama-launch-dsh.sh`: starts `ollama launch dsh` with no Terminal window; it is the program the LaunchAgent runs, and exists to supply the fnm `PATH` and a duplicate-server guard.
- `install-ollama-dsh-login.sh`: installs or removes the LaunchAgent `com.robe.ollama-launch-dsh.plist`, which is kept in the repository as its template.
- `README.md`: user documentation and dependency overview.

## Working rules

1. Always check `git status --short` before modifying files. The worktree may contain untracked files or user changes: do not delete them, do not restore them, and do not accidentally include them in broad rewrites.
2. Preserve the executable bit of the scripts.
3. Use `/bin/bash` for the Bash scripts and `/bin/zsh` for `flatpdf.sh`. Do not introduce Bash 4+ features: macOS still ships an earlier version of Bash.
4. Always quote expansions and paths that may contain spaces. Prefer arrays for file lists.
5. Explicitly verify external dependencies with `command -v` and produce understandable errors.
6. Do not add new dependencies if a utility already available in the project solves the problem.
7. Keep help text, CLI messages, and existing technical comments in English, unless localization is explicitly requested.
8. Avoid unrequested cross-cutting refactoring: the scripts differ in age and style and must be able to keep working independently.

## Safety invariants

- A conversion must not destroy a valid output or leave a partial file behind.
- For `flac2mp3.sh` and `mkv2mp3.sh`, preserve the temporary file → success check → final move flow.
- Do not change the default behavior that skips existing MP3s. Overwriting must require `--force`.
- The source must be deleted only after a successful conversion and move, and only with `--delete-original` or `--DO`.
- An error, a skipped file, or an input with no audio track must not cause deletion of the source.
- For destructive operations on real files, use temporary fixtures and not user content.
- `flatpdf.sh` rasterizes the document: do not describe the result as semantically equivalent to the original.

## CLI conventions

- Support filenames containing spaces.
- If a script accepts multiple files, keep processing the other inputs after a recoverable error and return a non-zero exit code if at least one fails.
- Diagnostic output must clearly state the input, the destination, and the reason for the error.
- Already-published short and long options are API: do not remove them or change their meaning without an explicit request.
- Update `--help` and `README.md` when a user interface changes.

## Required validation

After every change, run at least:

```bash
bash -n flac2mp3.sh install-ollama-dsh-login.sh jpg2webp.sh luma2alpha.sh mkv2mp3.sh ollama-launch-dsh.sh png2webp.sh prepend.sh
zsh -n flatpdf.sh
git diff --check
```

For the modified script, add a functional test proportionate to the risk:

- Audio/video: create a short fixture in a directory obtained with `mktemp -d`, run the conversion, and inspect the result with `ffprobe`.
- Images: create a small temporary fixture, verify format, dimensions, and the presence of the alpha channel where relevant.
- PDF: use a temporary PDF of a few pages and verify the page count and that the output opens.
- Rename: work exclusively on temporary copies and check the final names.

Also test the relevant error cases: missing dependency, wrong extension, output already existing, file with no audio, and paths containing spaces. Remove the fixtures you created when you are done.

## Automator and Finder

Quick Actions are installed in `~/Library/Services` and are not part of the repository. Modify them only if the request explicitly includes Finder integration.

Local workflows call the scripts through absolute paths: if the repository is moved, update the Automator command too. Use `/bin/bash` and configure **Pass input: as arguments**.

On macOS Sonoma an MKV may not be classified as `public.movie`. The `Convert MKV to MP3` workflow therefore uses `public.item` to remain visible, but it must keep the internal case-insensitive check of the `.mkv` extension.

When you enable a Service as a Quick Action, verify both conditions:

- the workflow is present in the `pbs` registry;
- in `NSServicesStatus`, the `ContextMenu`, `FinderPreview`, `ServicesMenu`, and `TouchBar` values are integers `1`, not the strings `"1"`.

After an update, reload the Services cache and relaunch Finder. Prefer the **Quick Actions → Customize…** interface when available; do not change file opening associations, because they are independent of Quick Actions.

## Delivery

Summarize the modified files, the tests run, and any remaining risks. Do not declare a Quick Action change complete just because it appears under **Services**: on Sonoma you must also verify its presence in the **Quick Actions** submenu.
