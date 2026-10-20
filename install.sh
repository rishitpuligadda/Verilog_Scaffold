#!/usr/bin/env bash
# install.sh - install verilog_scaffold as a command you can run from anywhere
#
#   ./install.sh                         install for your user as "vscaff"
#   ./install.sh --dev                   link to this repo (edits apply instantly)
#   ./install.sh --name vgen             use a different command name
#   sudo ./install.sh --prefix /usr/local    install for all users
#   ./install.sh --uninstall             remove it again (same options as install)
#   ./install.sh --no-deps               don't install Tcl/Tcllib automatically
#   ./install.sh --no-path               don't edit your shell startup file
#
# Missing prerequisites (Tcl 8.6+ and Tcllib) are installed automatically
# with the system package manager: apt, dnf, yum, pacman, zypper, apk or
# Homebrew. You may be asked for your sudo password.
#
# If the install directory is not on your PATH, a small block is added to
# your shell's startup file (~/.bashrc, ~/.zshrc, ...) so the command works
# in every new terminal. --uninstall removes that block again.

set -euo pipefail

NAME="vscaff"
PREFIX="$HOME/.local"
MODE="copy"
ACTION="install"
INSTALL_DEPS=1
SETUP_PATH=1

usage() {
    cat << EOF
Usage: ./install.sh [options]

Options:
  --name <cmd>     Command name to install (default: vscaff)
  --prefix <dir>   Install under <dir>/bin and <dir>/share (default: ~/.local)
  --dev            Link to this repository instead of copying it, so your
                   edits to src/ take effect immediately (for development)
  --no-deps        Don't install missing prerequisites (Tcl, Tcllib);
                   only check for them
  --no-path        Don't add the install directory to PATH in your shell's
                   startup file (~/.bashrc, ~/.zshrc, ...)
  --uninstall      Remove a previous installation (Tcl/Tcllib are left alone)
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)      NAME="${2:?--name needs a value}";     shift 2 ;;
        --prefix)    PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
        --dev)       MODE="dev";                            shift ;;
        --uninstall) ACTION="uninstall";                    shift ;;
        --no-deps)   INSTALL_DEPS=0;                        shift ;;
        --no-path)   SETUP_PATH=0;                          shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "ERROR: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/verilog_scaffold"
LINK="$BIN_DIR/$NAME"

# ---------------------------------------------------------------- PATH setup
MARK_BEGIN="# >>> verilog_scaffold >>>"
MARK_END="# <<< verilog_scaffold <<<"

# The startup file read by new terminals for the user's shell
shell_rc_file() {
    case "$(basename "${SHELL:-bash}")" in
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
        fish) echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
        bash) if [[ "$(uname -s)" == "Darwin" ]]; then
                  echo "$HOME/.bash_profile"     # macOS terminals start login shells
              else
                  echo "$HOME/.bashrc"
              fi ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

# Every startup file the block might have been added to (for uninstall)
all_rc_files() {
    echo "$HOME/.bashrc"
    echo "$HOME/.bash_profile"
    echo "${ZDOTDIR:-$HOME}/.zshrc"
    echo "$HOME/.profile"
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
}

# Show a path with ~ instead of $HOME
pretty() { echo "${1/#$HOME/\~}"; }

# The block added to the startup file. It only prepends BIN_DIR if it is not
# already on PATH, so sourcing the file twice never creates duplicates.
path_block() {
    local rc="$1" dir="$BIN_DIR"
    if [[ "$dir" == "$HOME/"* ]]; then
        dir="\$HOME/${dir#"$HOME/"}"
    fi
    echo "$MARK_BEGIN"
    echo "# Added by verilog_scaffold's install.sh so the \"$NAME\" command is found."
    echo "# Remove it with: ./install.sh --uninstall"
    if [[ "$rc" == *.fish ]]; then
        echo "if not contains \"$dir\" \$PATH"
        echo "    set -gx PATH \"$dir\" \$PATH"
        echo "end"
    else
        echo "case \":\$PATH:\" in"
        echo "    *\":$dir:\"*) ;;"
        echo "    *) export PATH=\"$dir:\$PATH\" ;;"
        echo "esac"
    fi
    echo "$MARK_END"
}

has_path_block() { [[ -f "$1" ]] && grep -qF "$MARK_BEGIN" "$1"; }

remove_path_block() {
    local rc="$1" tmp
    has_path_block "$rc" || return 1
    tmp="$(mktemp)"
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        $0 == b { skip = 1; next }
        skip && $0 == e { skip = 0; next }
        !skip' "$rc" > "$tmp"
    cat "$tmp" > "$rc"                          # keeps the file's permissions
    rm -f "$tmp"
}

# Result of setup_path:
#   on_path   BIN_DIR is already on PATH in this terminal
#   added     the block was added to PATH_RC just now
#   present   the block was already in PATH_RC from an earlier install
#   manual    nothing was changed (--no-path, or BIN_DIR outside $HOME)
PATH_STATUS=""
PATH_RC=""
setup_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) PATH_STATUS="on_path"; return ;;
    esac
    # Only personal installs touch personal startup files
    if [[ $SETUP_PATH -eq 0 || "$BIN_DIR" != "$HOME/"* ]]; then
        PATH_STATUS="manual"; return
    fi
    PATH_RC="$(shell_rc_file)"
    if has_path_block "$PATH_RC"; then
        PATH_STATUS="present"; return
    fi
    mkdir -p "$(dirname "$PATH_RC")"
    # Make sure the block starts on its own line
    if [[ -s "$PATH_RC" && -n "$(tail -c 1 "$PATH_RC")" ]]; then
        echo >> "$PATH_RC"
    fi
    path_block "$PATH_RC" >> "$PATH_RC"
    PATH_STATUS="added"
}

# ---------------------------------------------------------------- uninstall
if [[ "$ACTION" == "uninstall" ]]; then
    if [[ -L "$LINK" ]]; then
        rm "$LINK"
        echo "Removed command:  $LINK"
    elif [[ -e "$LINK" ]]; then
        echo "ERROR: $LINK is not a link created by this installer; leaving it alone" >&2
        exit 1
    else
        echo "No command found at $LINK"
    fi
    if [[ -f "$SHARE_DIR/generate_verilog.tcl" ]]; then
        # Keep the files if another command name still points at them
        still_used=""
        for other in "$BIN_DIR"/*; do
            if [[ -L "$other" && "$(readlink "$other")" == "$SHARE_DIR/"* ]]; then
                still_used="$other"
                break
            fi
        done
        if [[ -n "$still_used" ]]; then
            echo "Kept files:       $SHARE_DIR (still used by $still_used)"
        else
            rm -rf "$SHARE_DIR"
            echo "Removed files:    $SHARE_DIR"
        fi
    fi

    # Remove the PATH block, unless another command from this tool remains
    other_cmd=""
    for other in "$BIN_DIR"/*; do
        if [[ -L "$other" && "$(readlink "$other")" == */generate_verilog.tcl ]]; then
            other_cmd="$other"
            break
        fi
    done
    if [[ -z "$other_cmd" ]]; then
        while read -r rc; do
            if remove_path_block "$rc"; then
                echo "Removed PATH setup from $(pretty "$rc")"
            fi
        done < <(all_rc_files)
    fi
    exit 0
fi

# ---------------------------------------------------------------- checks
if [[ ! -f "$REPO_DIR/src/generate_verilog.tcl" ]]; then
    echo "ERROR: run install.sh from the verilog_scaffold repository" >&2
    exit 1
fi

# ---------------------------------------------------------------- prerequisites
# Each check prints nothing; the exit status says whether it passed.
have_tcl()  { command -v tclsh > /dev/null 2>&1 &&
              [[ "$(echo 'puts [package vsatisfies [info patchlevel] 8.6-]' | tclsh 2> /dev/null)" == "1" ]]; }
# Note: tclsh reading from a pipe exits 0 even after an error, so these checks
# look at what Tcl prints rather than at its exit status.
have_json() { command -v tclsh > /dev/null 2>&1 &&
              [[ "$(echo 'puts [expr {![catch {package require json}]}]' | tclsh 2> /dev/null)" == "1" ]]; }

deps_ok() { have_tcl && have_json; }

# Run a command as root: directly if we are root, otherwise through sudo
as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo > /dev/null 2>&1; then
        sudo "$@"
    else
        echo "ERROR: need root to install packages, but sudo is not available." >&2
        echo "       Run as root, or install the packages yourself: $*" >&2
        return 1
    fi
}

# Which package manager to use ("" if none is supported)
detect_pkg_manager() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        command -v brew > /dev/null 2>&1 && echo brew
        return
    fi
    local m
    for m in apt-get dnf yum pacman zypper apk brew; do
        if command -v "$m" > /dev/null 2>&1; then
            echo "$m"
            return
        fi
    done
}

install_deps() {
    local pkgs=(tcl tcllib)
    local mgr
    mgr="$(detect_pkg_manager)"

    if [[ -z "$mgr" ]]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            echo "ERROR: Homebrew is needed to install Tcl on macOS: https://brew.sh" >&2
        else
            echo "ERROR: no supported package manager found (apt, dnf, yum, pacman, zypper, apk, brew)." >&2
        fi
        return 1
    fi

    # Ask for the sudo password once, up front, with an explanation.
    # (Homebrew must never be run as root, so it is skipped.)
    if [[ "$mgr" != "brew" && $EUID -ne 0 ]]; then
        if ! command -v sudo > /dev/null 2>&1; then
            echo "ERROR: installing packages needs root, but sudo is not available." >&2
            return 1
        fi
        echo "Administrator access is needed to install ${pkgs[*]}."
        echo "You may be asked for your password."
        if ! sudo -v; then
            echo "ERROR: could not get administrator access." >&2
            return 1
        fi
    fi

    case "$mgr" in
        brew)
            echo "Installing Tcl (with Tcllib) using Homebrew..."
            brew install tcl-tk                 # the tcl-tk formula bundles Tcllib
            ;;
        apt-get)
            echo "Installing ${pkgs[*]} using apt..."
            as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" ||
                { echo "Refreshing the package list and retrying..."
                  as_root apt-get update &&
                  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"; }
            ;;
        dnf|yum)
            echo "Installing ${pkgs[*]} using $mgr..."
            as_root "$mgr" install -y "${pkgs[@]}"
            ;;
        pacman)
            echo "Installing ${pkgs[*]} using pacman..."
            as_root pacman -S --needed --noconfirm "${pkgs[@]}"
            ;;
        zypper)
            echo "Installing ${pkgs[*]} using zypper..."
            as_root zypper --non-interactive install "${pkgs[@]}"
            ;;
        apk)
            echo "Installing ${pkgs[*]} using apk..."
            as_root apk add "${pkgs[@]}"
            ;;
    esac
}

deps_help() {
    echo "Install the prerequisites yourself, then run ./install.sh again:" >&2
    echo "    Tcl 8.6 or newer (tclsh)  and  Tcllib (provides the 'json' package)" >&2
    echo "    Ubuntu/Debian: sudo apt install tcl tcllib" >&2
    echo "    Fedora:        sudo dnf install tcl tcllib" >&2
    echo "    Arch:          sudo pacman -S tcl tcllib" >&2
    echo "    macOS:         brew install tcl-tk" >&2
}

if deps_ok; then
    echo "Prerequisites:     OK (Tcl $(echo 'puts [info patchlevel]' | tclsh), Tcllib json)"
elif [[ $INSTALL_DEPS -eq 0 ]]; then
    have_tcl  || echo "WARNING: Tcl 8.6+ (tclsh) not found; $NAME will not run." >&2
    have_json || echo "WARNING: Tcllib's 'json' package not found; -config will not work." >&2
    deps_help
else
    have_tcl  || echo "Missing: Tcl 8.6+ (tclsh)"
    have_json || echo "Missing: Tcllib (the 'json' package)"
    if ! install_deps; then
        echo "ERROR: could not install the prerequisites automatically." >&2
        deps_help
        exit 1
    fi
    hash -r                                     # pick up a newly installed tclsh
    if ! deps_ok; then
        echo "ERROR: packages were installed, but the prerequisites still aren't usable:" >&2
        have_tcl  || echo "       - tclsh is missing or older than 8.6 ($(command -v tclsh || echo 'not found'))" >&2
        have_json || echo "       - Tcl cannot load the 'json' package" >&2
        deps_help
        exit 1
    fi
    echo "Prerequisites:     installed (Tcl $(echo 'puts [info patchlevel]' | tclsh), Tcllib json)"
fi

if [[ -e "$LINK" && ! -L "$LINK" ]]; then
    echo "ERROR: $LINK already exists and is not a link; refusing to overwrite it" >&2
    exit 1
fi

# ---------------------------------------------------------------- install
if [[ "$MODE" == "dev" ]]; then
    TARGET="$REPO_DIR/src/generate_verilog.tcl"
    # Clean up any earlier copied install so only one version exists
    if [[ -f "$SHARE_DIR/generate_verilog.tcl" ]]; then
        rm -rf "$SHARE_DIR"
    fi
else
    rm -rf "$SHARE_DIR"
    mkdir -p "$SHARE_DIR"
    cp -R "$REPO_DIR/src/." "$SHARE_DIR/"
    TARGET="$SHARE_DIR/generate_verilog.tcl"
fi

[[ -x "$TARGET" ]] || chmod +x "$TARGET"
mkdir -p "$BIN_DIR"
ln -sfn "$TARGET" "$LINK"

if deps_ok && ! "$LINK" -h > /dev/null 2>&1; then
    echo "ERROR: installed, but '$LINK -h' failed. Try running it to see why." >&2
    exit 1
fi

echo "Installed command: $LINK"
if [[ "$MODE" == "dev" ]]; then
    echo "Mode:              dev (linked to $REPO_DIR/src)"
else
    echo "Files copied to:   $SHARE_DIR"
fi

# ---------------------------------------------------------------- PATH
setup_path
echo
case "$PATH_STATUS" in
    on_path)
        echo "Done! Try:  $NAME -h"
        ;;
    added|present)
        if [[ "$PATH_STATUS" == "added" ]]; then
            echo "Added $(pretty "$BIN_DIR") to your PATH in $(pretty "$PATH_RC")."
        fi
        echo "Done! '$NAME' will work in every new terminal."
        echo
        echo "To use it in THIS terminal right away, run:"
        echo
        echo "    source $(pretty "$PATH_RC")"
        echo
        echo "(An installer can't change the PATH of the terminal that started it.)"
        ;;
    manual)
        echo "Note: $BIN_DIR is not on your PATH, so '$NAME' won't be found yet."
        echo "Add this line to your shell's startup file (e.g. ~/.bashrc):"
        echo
        echo "    export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac
