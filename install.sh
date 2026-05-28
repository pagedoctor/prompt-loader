#!/bin/sh
# Prompt Loader — Pagedoctor Learning Platform
# https://github.com/pagedoctor/prompt-loader
# Copyright (c) Colin Atkins (Pagedoctor)
set -e

ARTIFACT_URL="${1:-}"
tmpdir=""

die()  { printf "${RED}${MSG_ERROR_LABEL:-Error}:${RESET} %s\n" "$*" >&2; exit 1; }
info() { printf "${CYAN}==>${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${RESET}  %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Locale detection and i18n string definitions
# ---------------------------------------------------------------------------
detect_locale() {
    raw="${LC_ALL:-${LC_MESSAGES:-${LANGUAGE:-${LANG:-}}}}"
    raw="${raw%%:*}"   # LANGUAGE can be "de:en" — take first entry
    raw="${raw%%_*}"   # strip territory: de_DE → de
    raw="${raw%%.*}"   # strip encoding: en.UTF-8 → en
    lang=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
    case "$lang" in
        de) LOCALE_LANG="de" ;;
        ja) LOCALE_LANG="ja" ;;
        *)  LOCALE_LANG="en" ;;
    esac
}

setup_i18n() {
    case "${LOCALE_LANG:-en}" in
        de)
            MSG_ERROR_LABEL='Fehler'
            MSG_TOKEN_PROMPT='Pagedoctor Authentifizierungstoken:'
            MSG_CURL_REQUIRED='curl oder wget wird benötigt'
            MSG_UNZIP_REQUIRED='unzip wird benötigt'
            MSG_NO_COMPOSER_JSON='Keine composer.json im Artefakt gefunden'
            MSG_INSTALLED_TO='Installiert nach %s'
            MSG_TITLE='Prompt Loader — Installation abgeschlossen'
            MSG_LABEL_PACKAGE='Paket'
            MSG_LABEL_LOCATION='Speicherort'
            MSG_LABEL_PROMPT='Prompt:'
            MSG_CLIPBOARD_QUESTION='Prompt in Zwischenablage kopieren? [Enter=Ja / n=Nein]'
            MSG_CLIPBOARD_OK='Prompt in die Zwischenablage kopiert.'
            MSG_NO_CLIPBOARD='Kein Zwischenablage-Tool gefunden. Installiere xclip (X11), xsel oder wl-copy (Wayland)\n  und führe das Skript erneut aus, oder kopiere den Prompt oben manuell.'
            MSG_USAGE='Verwendung: install.sh <artefakt-url>'
            MSG_NO_TOKEN='Kein Authentifizierungstoken gefunden.'
            MSG_TOKEN_REQUIRED='Ein gültiger Token ist erforderlich'
            MSG_DOWNLOADING='Artefakt wird heruntergeladen...'
            MSG_AUTH_FAILED='Authentifizierung fehlgeschlagen. Bitte gib einen gültigen Token ein.'
            MSG_DOWNLOAD_FAILED='Download fehlgeschlagen (HTTP %s)'
            MSG_NO_PKG_NAME='Paketname konnte nicht aus dem Artefakt ermittelt werden'
            MSG_INSTALLING='Installiere %s...'
            MSG_INJECT_PROMPT='Ich habe das Pagedoctor-Lernartefakt `%s` installiert. Bitte lade alle Kontexte, Skills, Aufgaben, Anweisungen und Code-Snippets aus `vendor/%s` in diesem Projekt und wende sie an, um mir bei der TYPO3-Entwicklung zu helfen.'
            ;;
        ja)
            MSG_ERROR_LABEL='エラー'
            MSG_TOKEN_PROMPT='Pagedoctor 認証トークン:'
            MSG_CURL_REQUIRED='curl または wget が必要です'
            MSG_UNZIP_REQUIRED='unzip が必要です'
            MSG_NO_COMPOSER_JSON='アーティファクト内に composer.json が見つかりません'
            MSG_INSTALLED_TO='%s にインストールしました'
            MSG_TITLE='Prompt Loader — インストール完了'
            MSG_LABEL_PACKAGE='パッケージ'
            MSG_LABEL_LOCATION='場所'
            MSG_LABEL_PROMPT='プロンプト:'
            MSG_CLIPBOARD_QUESTION='プロンプトをクリップボードにコピーしますか？ [Enter=はい / n=いいえ]'
            MSG_CLIPBOARD_OK='プロンプトをクリップボードにコピーしました。'
            MSG_NO_CLIPBOARD='クリップボードツールが見つかりません。xclip (X11)、xsel、または wl-copy (Wayland) をインストールして\n  再実行するか、上記のプロンプトを手動でコピーしてください。'
            MSG_USAGE='使用方法: install.sh <アーティファクトURL>'
            MSG_NO_TOKEN='認証トークンが見つかりません。'
            MSG_TOKEN_REQUIRED='有効なトークンが必要です'
            MSG_DOWNLOADING='アーティファクトをダウンロード中...'
            MSG_AUTH_FAILED='認証に失敗しました。有効なトークンを入力してください。'
            MSG_DOWNLOAD_FAILED='ダウンロードに失敗しました (HTTP %s)'
            MSG_NO_PKG_NAME='アーティファクトからパッケージ名を特定できません'
            MSG_INSTALLING='%s をインストール中...'
            MSG_INJECT_PROMPT='Pagedoctor の学習アーティファクト `%s` をインストールしました。このプロジェクトの `vendor/%s` からすべてのコンテキスト、スキル、タスク、指示、コードスニペットを読み込み、TYPO3 開発のサポートに役立ててください。'
            ;;
        *)
            MSG_ERROR_LABEL='Error'
            MSG_TOKEN_PROMPT='Pagedoctor authentication token:'
            MSG_CURL_REQUIRED='curl or wget is required'
            MSG_UNZIP_REQUIRED='unzip is required'
            MSG_NO_COMPOSER_JSON='No composer.json found inside the artifact'
            MSG_INSTALLED_TO='Installed to %s'
            MSG_TITLE='Prompt Loader — Installation Complete'
            MSG_LABEL_PACKAGE='Package'
            MSG_LABEL_LOCATION='Location'
            MSG_LABEL_PROMPT='Prompt:'
            MSG_CLIPBOARD_QUESTION='Copy prompt to clipboard? [Enter=yes / n=no]'
            MSG_CLIPBOARD_OK='Prompt copied to clipboard.'
            MSG_NO_CLIPBOARD='No clipboard tool found. Install xclip (X11), xsel, or wl-copy (Wayland)\n  and re-run, or copy the prompt above manually.'
            MSG_USAGE='Usage: install.sh <artifact-url>'
            MSG_NO_TOKEN='No authentication token found.'
            MSG_TOKEN_REQUIRED='A valid token is required'
            MSG_DOWNLOADING='Downloading artifact...'
            MSG_AUTH_FAILED='Authentication failed. Please enter a valid token.'
            MSG_DOWNLOAD_FAILED='Download failed (HTTP %s)'
            MSG_NO_PKG_NAME='Could not determine package name from artifact'
            MSG_INSTALLING='Installing %s...'
            MSG_INJECT_PROMPT='I have installed the Pagedoctor learning artifact `%s`. Please load all context, skills, tasks, instructions, and code snippets from `vendor/%s` in this project and apply them to assist me with TYPO3 development.'
            ;;
    esac
}

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
    printf "${YELLOW}%s${RESET} " "$MSG_TOKEN_PROMPT" >/dev/tty
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
        die "$MSG_CURL_REQUIRED"
    fi
}

# ---------------------------------------------------------------------------
# Extract package name from the artifact zip
# ---------------------------------------------------------------------------
pkg_name_from_zip() {
    z="$1"
    command -v unzip >/dev/null 2>&1 || die "$MSG_UNZIP_REQUIRED"

    cjson=$(unzip -l "$z" 2>/dev/null \
        | awk 'NF>=4 && /composer\.json$/ {print length($NF), $NF}' \
        | sort -n | head -1 | awk '{print $2}')

    [ -z "$cjson" ] && die "$MSG_NO_COMPOSER_JSON"

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
    ok "$(printf "$MSG_INSTALLED_TO" "${BOLD}$target${RESET}")"
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
    msg=$(printf "$MSG_INJECT_PROMPT" "$pkg" "$pkg")

    printf '\n'
    printf "${BOLD}${CYAN}  %s${RESET}\n" "$MSG_TITLE"
    printf "${DIM}  ──────────────────────────────────────${RESET}\n"
    printf "  ${DIM}%s${RESET}   ${BOLD}%s${RESET}\n" "$MSG_LABEL_PACKAGE" "$pkg"
    printf "  ${DIM}%s${RESET}  ${BOLD}vendor/%s${RESET}\n\n" "$MSG_LABEL_LOCATION" "$pkg"

    printf "${DIM}  %s${RESET}\n\n" "$MSG_LABEL_PROMPT"
    printf '%s\n' "$msg"

    printf '\n'
    printf "${DIM}  %s${RESET} " "$MSG_CLIPBOARD_QUESTION" >/dev/tty
    read -r answer </dev/tty
    case "${answer:-y}" in
        [Yy]*)
            if copy_to_clipboard "$msg"; then
                ok "$MSG_CLIPBOARD_OK"
            else
                printf "${DIM}  $MSG_NO_CLIPBOARD${RESET}\n"
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
    detect_locale
    setup_i18n
    [ -z "$ARTIFACT_URL" ] && die "$MSG_USAGE"

    token=$(load_token)
    if [ -z "$token" ]; then
        info "$MSG_NO_TOKEN"
        token=$(prompt_token)
        [ -z "$token" ] && die "$MSG_TOKEN_REQUIRED"
        save_token "$token"
    fi

    tmpdir=$(mktemp -d)
    artifact="$tmpdir/artifact.zip"

    info "$MSG_DOWNLOADING"
    status=$(http_get "$ARTIFACT_URL" "$artifact" "$token")

    if [ "$status" = "401" ] || [ "$status" = "403" ]; then
        printf "${RED}%s${RESET}\n" "$MSG_AUTH_FAILED" >&2
        token=$(prompt_token)
        [ -z "$token" ] && die "$MSG_TOKEN_REQUIRED"
        save_token "$token"
        status=$(http_get "$ARTIFACT_URL" "$artifact" "$token")
    fi

    [ "$status" != "200" ] && die "$(printf "$MSG_DOWNLOAD_FAILED" "$status")"

    pkg=$(pkg_name_from_zip "$artifact")
    [ -z "$pkg" ] && die "$MSG_NO_PKG_NAME"

    info "$(printf "$MSG_INSTALLING" "$pkg")"
    install_to_vendor "$artifact" "$pkg"
    show_instructions "$pkg"
}

main
