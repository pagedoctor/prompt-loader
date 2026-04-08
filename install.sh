#!/bin/sh
# Prompt Loader — Pagedoctor Learning Platform
# https://github.com/pagedoctor/prompt-loader
# Copyright (c) Colin Atkins (Pagedoctor)
set -e

ARTIFACT_URL="${1:-}"
tmpdir=""

die()  { printf "${RED}Error:${RESET} %s\n" "$*" >&2; exit 1; }
info() { printf "${CYAN}==>${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${RESET}  %s\n" "$*"; }

# ---------------------------------------------------------------------------
# ANSI styles — disabled when stdout is not a terminal
# ---------------------------------------------------------------------------
setup_colors() {
    if [ -t 1 ]; then
        BOLD=$(printf '\033[1m');  DIM=$(printf '\033[2m');   RESET=$(printf '\033[0m')
        RED=$(printf '\033[31m');  GREEN=$(printf '\033[32m'); CYAN=$(printf '\033[36m')
        YELLOW=$(printf '\033[33m')
    else
        BOLD=''; DIM=''; RESET=''; RED=''; GREEN=''; CYAN=''; YELLOW=''
    fi
}

# ---------------------------------------------------------------------------
# Platform-aware config directory
# ---------------------------------------------------------------------------
config_dir() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) printf '%s' "${APPDATA:-$HOME}/prompt-loader" ;;
        Darwin)               printf '%s' "$HOME/Library/Application Support/prompt-loader" ;;
        *)                    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/prompt-loader" ;;
    esac
}

# ---------------------------------------------------------------------------
# Token management
# ---------------------------------------------------------------------------
load_token() {
    f="$(config_dir)/token"
    [ -f "$f" ] && cat "$f" || true
}

save_token() {
    f="$(config_dir)/token"
    mkdir -p "$(dirname "$f")"
    printf '%s' "$1" > "$f"
    chmod 600 "$f" 2>/dev/null || true
}

prompt_token() {
    printf "${YELLOW}Pagedoctor authentication token:${RESET} " >/dev/tty
    if stty -echo </dev/tty 2>/dev/null; then
        read -r tok </dev/tty
        stty echo </dev/tty 2>/dev/null || true
    else
        read -r tok </dev/tty
    fi
    printf '\n' >/dev/tty
    printf '%s' "$tok"
}

# ---------------------------------------------------------------------------
# HTTP download — returns HTTP status code, body written to $2
# ---------------------------------------------------------------------------
http_get() {
    url="$1"; out="$2"; tok="$3"
    if command -v curl >/dev/null 2>&1; then
        curl -sSL -w '%{http_code}' -H "Authorization: Bearer $tok" -o "$out" "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        hfile=$(mktemp)
        wget --server-response -q --header="Authorization: Bearer $tok" -O "$out" "$url" 2>"$hfile" || true
        awk '/HTTP\//{s=$2} END{print s+0}' "$hfile"
        rm -f "$hfile"
    else
        die "curl or wget is required"
    fi
}

# ---------------------------------------------------------------------------
# Extract package name from the artifact zip
# ---------------------------------------------------------------------------
pkg_name_from_zip() {
    z="$1"
    command -v unzip >/dev/null 2>&1 || die "unzip is required"

    cjson=$(unzip -l "$z" 2>/dev/null \
        | awk 'NF>=4 && /composer\.json$/ {print length($NF), $NF}' \
        | sort -n | head -1 | awk '{print $2}')

    [ -z "$cjson" ] && die "No composer.json found inside the artifact"

    unzip -p "$z" "$cjson" 2>/dev/null \
        | grep -m1 '"name"' \
        | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# ---------------------------------------------------------------------------
# Extract zip into vendor/, stripping a single top-level directory if present
# ---------------------------------------------------------------------------
install_to_vendor() {
    z="$1"; pkg="$2"
    target="vendor/$pkg"

    extract_dir="$tmpdir/extracted"
    unzip -q "$z" -d "$extract_dir"

    top_count=$(ls -1 "$extract_dir" | wc -l)
    if [ "$top_count" = "1" ]; then
        src="$extract_dir/$(ls -1 "$extract_dir")"
    else
        src="$extract_dir"
    fi

    mkdir -p "$target"
    cp -r "$src/." "$target/"
    ok "Installed to ${BOLD}$target${RESET}"
}

# ---------------------------------------------------------------------------
# Clipboard support — tries platform-native tools, silent on failure
# ---------------------------------------------------------------------------
copy_to_clipboard() {
    text="$1"
    if command -v pbcopy >/dev/null 2>&1; then
        printf '%s' "$text" | pbcopy
    elif command -v clip.exe >/dev/null 2>&1; then
        printf '%s' "$text" | clip.exe
    elif command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$text" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf '%s' "$text" | xsel --clipboard --input
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Post-install instructions
# ---------------------------------------------------------------------------
show_instructions() {
    pkg="$1"
    msg=$(printf 'I have installed the Pagedoctor learning artifact `%s`. Please load all context, skills, tasks, instructions, and code snippets from `vendor/%s` in this project and apply them to assist me with TYPO3 development.' "$pkg" "$pkg")

    printf '\n'
    printf "${BOLD}${CYAN}  Prompt Loader — Installation Complete${RESET}\n"
    printf "${DIM}  ──────────────────────────────────────${RESET}\n"
    printf "  ${DIM}Package${RESET}   ${BOLD}%s${RESET}\n" "$pkg"
    printf "  ${DIM}Location${RESET}  ${BOLD}vendor/%s${RESET}\n\n" "$pkg"

    printf "${DIM}  Prompt:${RESET}\n\n"
    printf '%s\n' "$msg"

    printf '\n'
    printf "${DIM}  Copy prompt to clipboard? [Y/n]${RESET} " >/dev/tty
    read -r answer </dev/tty
    case "${answer:-y}" in
        [Yy]*)
            if copy_to_clipboard "$msg"; then
                ok "Prompt copied to clipboard."
            else
                printf "${DIM}  No clipboard tool found. Install xclip (X11), xsel, or wl-copy (Wayland)\n  and re-run, or copy the prompt above manually.${RESET}\n"
            fi
            ;;
    esac

    printf '\n'
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
cleanup() { [ -n "$tmpdir" ] && rm -rf "$tmpdir" 2>/dev/null || true; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    setup_colors
    [ -z "$ARTIFACT_URL" ] && die "Usage: install.sh <artifact-url>"

    token=$(load_token)
    if [ -z "$token" ]; then
        info "No authentication token found."
        token=$(prompt_token)
        [ -z "$token" ] && die "A valid token is required"
        save_token "$token"
    fi

    tmpdir=$(mktemp -d)
    artifact="$tmpdir/artifact.zip"

    info "Downloading artifact..."
    status=$(http_get "$ARTIFACT_URL" "$artifact" "$token")

    if [ "$status" = "401" ] || [ "$status" = "403" ]; then
        printf "${RED}Authentication failed.${RESET} Please enter a valid token.\n" >&2
        token=$(prompt_token)
        [ -z "$token" ] && die "A valid token is required"
        save_token "$token"
        status=$(http_get "$ARTIFACT_URL" "$artifact" "$token")
    fi

    [ "$status" != "200" ] && die "Download failed (HTTP $status)"

    pkg=$(pkg_name_from_zip "$artifact")
    [ -z "$pkg" ] && die "Could not determine package name from artifact"

    info "Installing $pkg..."
    install_to_vendor "$artifact" "$pkg"
    show_instructions "$pkg"
}

main
