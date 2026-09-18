# dapa - install or update on a Mac, in one line.
#
# The Mac twin of dapa.ps1. It asks for your key, downloads the current dapa for Mac straight from a
# private release, checks it byte for byte, and puts dapa in your own Applications folder. No admin
# password. This file holds no key and no secret. It runs in zsh, the shell every Mac opens.
#
# The SAME file lives in two places, and each place has its own one line (paste it into Terminal):
#
#   Deloitte (production) - the file sits in Deloitte's private release repo, so the line asks for
#   the key FIRST, uses it to fetch this file, and hands it to this file on stdin:
#     printf 'Paste your dapa key: '; read -rs DAPA_KEY; echo; if S="$(printf 'Authorization: Bearer %s\n' "$DAPA_KEY" | curl -fsSL -H @- -H "Accept: application/vnd.github.raw" https://api.github.com/repos/Deloitte-US-Consulting/dapa-release/contents/dapa.sh)"; then printf '%s\n' "$DAPA_KEY" | DAPA_FEED=deloitte zsh -c "$S"; else echo "That key cannot reach the dapa download. Request a new key."; fi; unset DAPA_KEY S
#
#   Kevin's own feed - the file is public, so it is fetched first and asks for the key itself:
#     if S="$(curl -fsSL https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.sh)"; then zsh -c "$S"; fi
#
# Both lines work whether Terminal runs zsh (every new Mac account since 2019) or bash (an older
# account carried over): they use only printf, read and curl, and run this file with zsh by name.
# No PowerShell: on a Mac it is optional, and a customer must never have to install it for dapa.
#
# THE KEY NEVER SITS IN A PROGRAM'S ARGUMENTS OR ENVIRONMENT, where any program this user runs could
# read it. It travels on stdin: from the shell's own printf (a builtin in zsh and bash, so no new
# program) into curl -H @-, and from the Deloitte line into this file. (Codex macapp-r1, finding 3.)

stop() { print -P "\n%F{red}$1%f"; exit 1; }

# The right computer, before anything else. dapa for Mac is built for Apple silicon only.
# hw.optional.arm64 answers 1 on an M-series Mac even when Terminal runs under Rosetta, where
# uname -m says x86_64; an Intel Mac has no such entry at all.
[[ "$(uname -s)" == Darwin ]] || stop "STOPPED: this line installs dapa on a Mac. On Windows, use the PowerShell line. Nothing was installed."
[[ "$(sysctl -in hw.optional.arm64 2>/dev/null)" == 1 ]] || stop "STOPPED: dapa for Mac needs a Mac with Apple silicon, M1 or newer. Nothing was installed."

# The RELEASE repos, which hold installers and no source code. These must match FEED_REPOS in the app
# (desktop/src/updater.ts). DAPA_FEED chooses; anything not on this list is refused, so a stray value
# can never send a key somewhere nothing was published.
which="${DAPA_FEED:-personal}"
case "${which:l}" in
  personal) repo="kevinblumenfeld/dapa-release" ;;
  deloitte) repo="Deloitte-US-Consulting/dapa-release" ;;
  *) stop "STOPPED: '$which' is not a dapa download. Use 'personal' or 'deloitte'." ;;
esac

# The Deloitte line already asked for the key and hands it over on stdin: one paste, not two.
# Run from Terminal with nothing piped in, this file asks for it itself.
if [[ -t 0 ]]; then read -rs "key?Paste your dapa key: "; echo; else read -r key; fi
key="${key//[[:space:]]/}"
[[ -n "$key" ]] || stop "No key was pasted. Nothing was installed."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
api="https://api.github.com/repos/$repo"
# Every GitHub call: the key rides in on stdin (-H @-), never in curl's arguments.
gh_curl() { print -r -- "Authorization: Bearer $key" | curl -H @- -H "User-Agent: dapa-install" "$@"; }

# 1. Ask which version is current. The key is what gets you in.
code="$(gh_curl -sS -o "$tmp/latest.json" -w '%{http_code}' "$api/releases/latest")" \
  || stop "Could not reach the download. Check your internet, then run this again."
case "$code" in
  200) ;;
  401) stop "That key is not valid. Request a new key." ;;
  403|404)
    # A 404 means EITHER "this key cannot see the repo" OR "the repo has no release yet". Asking about
    # the repo itself tells them apart, because the fix is different: a new key, or a release.
    if gh_curl -fsS -o /dev/null "$api"; then stop "Your key works, but there is no dapa release to download yet. Report this."
    else stop "That key cannot reach the dapa download. Request a new key."; fi ;;
  *) stop "Could not reach the download (HTTP $code). Run this again." ;;
esac

# Pick the Mac zip and its sha256. Every Mac reads JSON with JavaScript for Automation; no extra tools.
pick="$(osascript -l JavaScript -e 'function run(argv) {
  const rel = JSON.parse(argv[0]);
  const file = (rel.assets || []).find((a) => /^dapa-.*mac-arm64\.zip$/i.test(a.name));
  const sum = file && /^sha256:([0-9a-f]{64})$/i.exec(file.digest || "");
  return file && sum ? [rel.tag_name, file.name, file.url, file.size, sum[1].toLowerCase()].join("\t") : "";
}' "$(cat "$tmp/latest.json")" 2>/dev/null)"
[[ -n "$pick" ]] || stop "This version has no Mac download that can be checked, so nothing was installed. Report this."
IFS=$'\t' read -r tag name url size sum <<< "$pick"

# 2. Download it. Half a file is never left looking whole.
print -P "\n%F{cyan}dapa $tag%f"
print "Downloading $(( size / 1048576 )) MB. This takes a few minutes."
gh_curl -fL --progress-bar -H "Accept: application/octet-stream" -o "$tmp/$name.part" "$url" \
  || stop "The download stopped early. Run this again."

# 3. Check it is exactly the file Kevin published, byte for byte.
[[ "$(shasum -a 256 "$tmp/$name.part" | cut -d' ' -f1)" == "$sum" ]] \
  || stop "The download was damaged. Nothing was kept. Run this again."
ditto -x -k "$tmp/$name.part" "$tmp/unpacked" && [[ -d "$tmp/unpacked/dapa.app" ]] \
  || stop "The download would not unpack. Nothing was changed. Report this."

# 4. Hand the key to dapa, so it is never pasted a second time. dapa claims this file the first time
# it starts: it stores the key in the Mac keychain, then deletes the file. Running this again with a
# NEW key is also how a key is replaced.
data="$HOME/Library/Application Support/dapa-desktop"
mkdir -p "$data" && (umask 077 && print -rn -- "$key" > "$data/update-key.txt") \
  || stop "Could not hand the key to dapa. Nothing was installed."

# 5. Install for you only, in ~/Applications: no admin password, and your settings stay. A running
# dapa is closed first (only when it IS running: asking a closed app to quit would open it).
print -P "%F{green}Checked. Installing now.%f"
if pgrep -xq dapa; then osascript -e 'quit app "dapa"' >/dev/null 2>&1; sleep 2; fi
apps="$HOME/Applications"
mkdir -p "$apps" && rm -rf "$apps/dapa.app" && mv "$tmp/unpacked/dapa.app" "$apps/dapa.app" \
  || stop "Could not put dapa in $apps. Close dapa, then run this again."
print -P "\n%F{green}dapa is installed in your Applications folder.%f"
print "It will keep itself up to date. There is nothing else to paste."
open "$apps/dapa.app"
