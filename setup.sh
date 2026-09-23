#!/bin/bash
# macOS Apple Silicon bootstrap: installs the applications, tools, and shell
# configuration used on this machine. It is part of the zshell repository:
# https://github.com/RobeSantoro/zshell
# Run as a normal user; Homebrew may require the administrator password.

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  printf '%s\n' 'This script requires macOS Apple Silicon with native ARM terminal.' >&2
  exit 1
fi
if [[ "$EUID" -eq 0 ]]; then
  printf '%s\n' 'Run this script as a normal user, without sudo.' >&2
  exit 1
fi

# Install Homebrew only if it is not already present in the Apple Silicon path.
if [[ ! -x /opt/homebrew/bin/brew ]]; then
  # The separate download ensures that a network error stops the script.
  homebrew_installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  /bin/bash -c "$homebrew_installer"
fi

# Makes Homebrew available now and in future zsh login sessions.
# Adds the line without overwriting or duplicating the profile on subsequent starts.
homebrew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
zsh_profile="${ZDOTDIR:-$HOME}/.zprofile"
touch "$zsh_profile"
if ! grep -Fqx "$homebrew_shellenv" "$zsh_profile"; then
  printf '\n# Homebrew (Apple Silicon)\n%s\n' "$homebrew_shellenv" >> "$zsh_profile"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# Graphical applications indicated in the conversation.
casks=(
  raycast
  rectangle
  wispr-flow
  ghostty
  google-chrome
  chatgpt
  whatsapp
  google-drive
  parsec
  rustdesk
  macs-fan-control
  microsoft-word
  microsoft-excel
  microsoft-powerpoint
  obsidian
  unnaturalscrollwheels
  maccy
  visual-studio-code
  chamburr/tap/glance # Glance from the developer repository.
  font-caskaydia-cove-nerd-font # Cascadia Code Nerd Font (includes the Mono variant).
  obs
  cavalry
  losslesscut
  qlvideo
  tailscale-app
)
for package in "${casks[@]}"; do
  if brew list --cask "$package" >/dev/null 2>&1; then
    printf 'Already installed: %s\n' "$package"
  else
    brew install --cask "$package"
  fi
done

# Terminal tools: keeps the formulas requested in the conversation.
for package in syncthing codex oh-my-posh fnm tree btop; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    printf 'Already installed: %s\n' "$package"
  else
    brew install --formula "$package"
  fi
done

# Git & Zshell repository
if ! command -v git >/dev/null 2>&1; then
  printf 'Git not found. Installing...\n'
  brew install git
fi

# This script is part of the zshell repository: cloning it here provides the
# helper scripts it runs later and the directory added to PATH at the end.
ZSHELL_DIR="$HOME/CODE/zshell"
if [[ ! -d "$ZSHELL_DIR" ]]; then
  printf 'Cloning the zshell repository into %s...\n' "$ZSHELL_DIR"
  mkdir -p "$(dirname "$ZSHELL_DIR")"
  git clone https://github.com/RobeSantoro/zshell.git "$ZSHELL_DIR"
else
  printf 'zshell repository already present in %s. Updating...\n' "$ZSHELL_DIR"
  cd "$ZSHELL_DIR" && git pull
fi

# Ollama: official installation, separate from Homebrew.
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
else
  printf 'Already installed: ollama\n'
fi

# Optional login item: starts `ollama launch dsh` at login with no Terminal
# window. ollama-dsh-login.sh lives in the zshell repository cloned above and
# manages a LaunchAgent for the current user. The answer defaults to no, and the
# question is skipped when the script has no interactive terminal.
dsh_login_installer="$ZSHELL_DIR/ollama-dsh-login.sh"
if [[ -f "$dsh_login_installer" ]]; then
  dsh_login_answer=''
  if [[ -t 0 ]]; then
    printf '\nDo you want to add `ollama launch dsh` to login items? [y/N] '
    read -r dsh_login_answer
  elif { true >/dev/tty; } 2>/dev/null; then
    # Stdin is not a terminal, typically because the script was piped into bash:
    # ask on the controlling terminal so the question is not silently skipped.
    # The redirect above proves /dev/tty can actually be opened.
    printf '\nDo you want to add `ollama launch dsh` to login items? [y/N] '
    read -r dsh_login_answer </dev/tty
  else
    printf '\nSkipping the `ollama launch dsh` login item: no interactive terminal.\n'
  fi
  case "$dsh_login_answer" in
    [yY] | [yY][eE][sS])
      if /bin/bash "$dsh_login_installer" install; then
        printf 'Login item installed: `ollama launch dsh` will start at login.\n'
      else
        printf '%s\n' 'The login item could not be installed; continuing.' >&2
      fi
      ;;
    *)
      printf 'Login item skipped. Add it later with:\n'
      printf '  /bin/bash %s install\n' "$dsh_login_installer"
      ;;
  esac
else
  printf 'Login item script not found: %s\n' "$dsh_login_installer"
fi

# Node: latest version managed by fnm.
# fnm install --latest picks the newest stable version.
eval "$(fnm env --shell bash)"
fnm install --latest
fnm use --latest
fnm default --latest

# Persistent initialization and version switching based on .node-version/.nvmrc.
zsh_rc="${ZDOTDIR:-$HOME}/.zshrc"
mkdir -p "$(dirname "$zsh_rc")"
touch "$zsh_rc"
fnm_init='eval "$(fnm env --use-on-cd --shell zsh)"'
if ! grep -Fqx "$fnm_init" "$zsh_rc"; then
  cp -p "$zsh_rc" "$zsh_rc.backup.$(date +%Y%m%d%H%M%S).$$"
  printf '\n# Node version manager (fnm)\n%s\n' "$fnm_init" >> "$zsh_rc"
fi
/bin/zsh -n "$zsh_rc"

# pnpm is installed for the selected Node, authorizing only its scripts.
# Does not reinstall pnpm if it is already present among this Node's global packages.
if ! npm list --global --depth=0 pnpm >/dev/null 2>&1; then
  npm install --global pnpm --allow-scripts=pnpm
fi
node --version
npm --version
pnpm --version
fnm current

# Automatic startup of Oh My Posh in interactive zsh shells.
# The personal theme must be present in ~/.config.omp.json: it is not overwritten.
zsh_rc="${ZDOTDIR:-$HOME}/.zshrc"
mkdir -p "$(dirname "$zsh_rc")"
touch "$zsh_rc"
posh_init='eval "$(oh-my-posh init zsh --config "$HOME/.config.omp.json" --strict)"'
if ! grep -Fqx "$posh_init" "$zsh_rc"; then
  cp -p "$zsh_rc" "$zsh_rc.backup.$(date +%Y%m%d%H%M%S).$$"
  cat >> "$zsh_rc" <<'ZSHRC'

# Oh My Posh: personal theme, loaded only if available.
if [[ -r "$HOME/.config.omp.json" ]]; then
  if ! command -v oh-my-posh >/dev/null 2>&1 && [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  if command -v oh-my-posh >/dev/null 2>&1; then
eval "$(oh-my-posh init zsh --config "$HOME/.config.omp.json" --strict)"
  fi
fi
ZSHRC
fi
/bin/zsh -n "$zsh_rc"
if [[ ! -r "$HOME/.config.omp.json" ]]; then
  printf '%s\n' 'Copy your theme to ~/.config.omp.json to activate Oh My Posh in new shells.'
fi

# Ghostty: uses Cascadia Nerd Font Mono; keeps other preferences.
ghostty_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$ghostty_dir"
ghostty_config="$ghostty_dir/config.ghostty"
# If the legacy file exists, it is loaded last: update that one.
if [[ -f "$ghostty_dir/config" ]]; then
  ghostty_config="$ghostty_dir/config"
fi
touch "$ghostty_config"
ghostty_tmp="$(mktemp "$ghostty_dir/.font-config.XXXXXX")"
# Removes previous font family choices, including bold/italic variants.
awk '!/^[[:space:]]*font-family(-bold|-italic|-bold-italic)?[[:space:]]*=/' "$ghostty_config" > "$ghostty_tmp"
printf '%s\n' 'font-family = "CaskaydiaCove Nerd Font Mono"' >> "$ghostty_tmp"
if ! cmp -s "$ghostty_config" "$ghostty_tmp"; then
  cp -p "$ghostty_config" "$ghostty_config.backup.$(date +%Y%m%d%H%M%S).$$"
  cat "$ghostty_tmp" > "$ghostty_config"
fi
rm -f "$ghostty_tmp"
printf '%s\n' 'To apply prompts and fonts, restart Ghostty or open a new tab.'

# Raycast launcher for btop: typing "btop" in Raycast opens a new Ghostty window
# already running btop. A minimal application bundle is used because Raycast
# indexes the applications in ~/Applications by itself; a Raycast Script Command
# would instead need a manual "Add Script Directory" step once per machine.
btop_app="$HOME/Applications/btop.app"
if command -v btop >/dev/null 2>&1; then
  mkdir -p "$btop_app/Contents/MacOS"
  cat > "$btop_app/Contents/Info.plist" <<'BTOP_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>btop</string>
	<key>CFBundleExecutable</key>
	<string>btop</string>
	<key>CFBundleIdentifier</key>
	<string>local.btop.launcher</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>btop</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
BTOP_PLIST
  cat > "$btop_app/Contents/MacOS/btop" <<'BTOP_LAUNCHER'
#!/bin/bash
# Opens a new Ghostty window running btop.
# Ghostty is started through `open -na Ghostty.app --args -e <command>`:
# launching the terminal from its own CLI is not supported on macOS, and -n makes
# sure the arguments reach a fresh instance even when Ghostty is already running.
set -u
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

if ! command -v btop >/dev/null 2>&1; then
  osascript -e 'display alert "btop is not installed" message "Install it with: brew install btop"' >/dev/null 2>&1
  exit 1
fi

if ! open -na Ghostty.app --args -e "$(command -v btop)"; then
  osascript -e 'display alert "Ghostty was not found" message "Install it with: brew install --cask ghostty"' >/dev/null 2>&1
  exit 1
fi
BTOP_LAUNCHER
  chmod +x "$btop_app/Contents/MacOS/btop"
  # Registers the bundle with Launch Services so Raycast and Spotlight find it
  # immediately, without waiting for a new login or a manual reindex.
  lsregister='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
  if [[ -x "$lsregister" ]]; then
    "$lsregister" -f "$btop_app"
  fi
  printf 'Raycast launcher ready: type "btop" in Raycast and press Enter.\n'
else
  printf '%s\n' 'btop not found: skipping the Raycast launcher.' >&2
fi

# Restores only the four personal aliases in the requested profile.
alias_profile="${ZDOTDIR:-$HOME}/.zshrc"
touch "$alias_profile"
alias_backup_done=false
while IFS= read -r alias_line; do
  if ! grep -Fqx "$alias_line" "$alias_profile"; then
    if [[ "$alias_backup_done" == false ]]; then
      cp -p "$alias_profile" "$alias_profile.backup.$(date +%Y%m%d%H%M%S).$$"
      printf '\n' >> "$alias_profile"
      alias_backup_done=true
    fi
    printf '%s\n' "$alias_line" >> "$alias_profile"
  fi
done <<'PERSONAL_ALIASES'
alias getip="ifconfig en0 | grep inet | grep -v inet6 | cut -d ' ' -f2"
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
PERSONAL_ALIASES
/bin/zsh -n "$alias_profile"

# Personal scripts: adds the folder to the PATH only if it exists and is not already present.
zshell_profile="${ZDOTDIR:-$HOME}/.zshrc"
mkdir -p "$(dirname "$zshell_profile")"
touch "$zshell_profile"
zshell_old_line='export PATH="$HOME/CODE/zshell:$PATH"'
zshell_path_line='if [[ -d "$HOME/CODE/zshell" && ":$PATH:" != *":$HOME/CODE/zshell:"* ]]; then export PATH="$HOME/CODE/zshell:$PATH"; fi'
zshell_tmp="$(mktemp)"
awk -v old="$zshell_old_line" '$0 != old' "$zshell_profile" > "$zshell_tmp"
if ! grep -Fqx "$zshell_path_line" "$zshell_tmp"; then
  printf '\n# Personal scripts\n%s\n' "$zshell_path_line" >> "$zshell_tmp"
fi
/bin/zsh -n "$zshell_tmp"
if ! cmp -s "$zshell_profile" "$zshell_tmp"; then
  cp -p "$zshell_profile" "$zshell_profile.backup.$(date +%Y%m%d%H%M%S).$$"
  cat "$zshell_tmp" > "$zshell_profile"
fi
rm -f "$zshell_tmp"

# Personal function to open the remote Git origin or upstream.
gb_profile="${ZDOTDIR:-$HOME}/.zshrc"
mkdir -p "$(dirname "$gb_profile")"
touch "$gb_profile"
if ! grep -Fqx 'function gb {' "$gb_profile"; then
  cp -p "$gb_profile" "$gb_profile.backup.$(date +%Y%m%d%H%M%S).$$"
  printf '\n' >> "$gb_profile"
  cat >> "$gb_profile" <<'GB_FUNCTION'
function gb {
    if [[ "$1" == "origin" ]]; then
        gbrowsevar=$(git config --get remote.origin.url)
    elif [[ "$1" == "upstream" ]]; then
        gbrowsevar=$(git config --get remote.upstream.url)
    else
        echo "Invalid argument. Usage: gb origin | gb upstream"
        return 1
    fi

    if [[ -z "$gbrowsevar" ]]; then
        echo "Remote URL not found."
        return 1
    fi

    printf "Opening: ${gbrowsevar}\n"
    open "$gbrowsevar"
}
GB_FUNCTION
fi
/bin/zsh -n "$gb_profile"

# Global Git identity. --replace-all also corrects any duplicate entries.
git config --global --replace-all user.name 'RobeSantoro'
git config --global --replace-all user.email 'santoro.robe@gmail.com'

printf '\nConfiguration complete. Global Git identity:\n'
git config --global --get user.name
git config --global --get user.email