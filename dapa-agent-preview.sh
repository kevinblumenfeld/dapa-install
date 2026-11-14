# dapa agent preview - install or update on a Mac, in one line.
#
# The Mac twin of dapa-agent-preview.ps1. dapa agent preview (2026-11-10) is the agent-preview branch's own app: dapa
# dev plus the agent work, built for Microsoft Ignite. It is a third app that installs BESIDE dapa and dapa dev, and
# it updates only from its own builds. This file installs it and nothing else: dapa and dapa dev keep their own line
# (dapa.sh beside this file), which this file never changes.
#
# It asks for your key, downloads the newest dapa agent preview for Mac straight from a private release, checks it
# byte for byte, and puts it in your own Applications folder. No admin password. This file holds no key and no
# secret. It runs in zsh, the shell every Mac opens. dapa's key works: its builds sit in the same release repo, as
# pre-releases that dapa and dapa dev never offer.
#
# The SAME file lives in two places, and each place has its own one line (paste it into Terminal):
#
#   Deloitte (production) - the file sits in Deloitte's private release repo, so the line asks for the key FIRST,
#   uses it to fetch this file, and hands it to this file on stdin:
#     printf 'Paste your dapa key: '; read -rs DAPA_KEY; echo; if S="$(printf 'Authorization: Bearer %s\n' "$DAPA_KEY" | curl -fsSL -H @- -H "Accept: application/vnd.github.raw" https://api.github.com/repos/Deloitte-US-Consulting/dapa-release/contents/dapa-agent-preview.sh)"; then printf '%s\n' "$DAPA_KEY" | DAPA_FEED=deloitte zsh -c "$S"; else echo "That key cannot reach the dapa download. Request a new key."; fi; unset DAPA_KEY S
#
#   Kevin's own feed - the file is public, so it is fetched first and asks for the key itself:
#     if S="$(curl -fsSL https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa-agent-preview.sh)"; then zsh -c "$S"; fi
#
# Both lines work whether Terminal runs zsh or bash: they use only printf, read and curl, and run this file with zsh
# by name. A Mac's dapa agent preview starts with its own settings: the Mac keeps each app's saved secrets under that
# app's own name, so a copy of another app's data could not open them.
#
# THE KEY NEVER SITS IN A PROGRAM'S ARGUMENTS OR ENVIRONMENT, where any program this user runs could read it. It
# travels on stdin: from the shell's own printf (a builtin in zsh and bash) into curl -H @-, and from the Deloitte
# line into this file.

stop() { print -P "\n%F{red}$1%f"; exit 1; }

# The right computer, before anything else. dapa for Mac is built for Apple silicon only.
[[ "$(uname -s)" == Darwin ]] || stop "STOPPED: this line installs dapa agent preview on a Mac. On Windows, use the PowerShell line. Nothing was installed."
[[ "$(sysctl -in hw.optional.arm64 2>/dev/null)" == 1 ]] || stop "STOPPED: dapa for Mac needs a Mac with Apple silicon, M1 or newer. Nothing was installed."

# The RELEASE repos, the same two dapa installs from (FEED_REPOS in desktop/src/updater.ts). DAPA_FEED chooses;
# anything not on this list is refused, so a stray value can never send a key somewhere nothing was published.
which="${DAPA_FEED:-personal}"
case "${which:l}" in
  personal) repo="kevinblumenfeld/dapa-release" ;;
  deloitte) repo="Deloitte-US-Consulting/dapa-release" ;;
  *) stop "STOPPED: '$which' is not a dapa download. Use 'personal' or 'deloitte'." ;;
esac
# The app's names: its builds' tags and files, its data folder, and what people see. They match the app
# (AGENT_PREVIEW_APP in desktop/src/build-flavor.ts of the dapa source).
app="dapa agent preview"
channel="agent-preview"
data_name="dapa-agent-preview"

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

# 1. Ask which builds there are. The key is what gets you in.
code="$(gh_curl -sS -o "$tmp/list.json" -w '%{http_code}' "$api/releases?per_page=50")" \
  || stop "Could not reach the download. Check your internet, then run this again."
case "$code" in
  200) ;;
  401) stop "That key is not valid. Request a new key." ;;
  403|404)
    if gh_curl -fsS -o /dev/null "$api"; then stop "Your key works, but there is no $app build to download yet. Report this."
    else stop "That key cannot reach the dapa download. Request a new key."; fi ;;
  *) stop "Could not reach the download (HTTP $code). Run this again." ;;
esac

# The newest build holding its Mac zip with a checksum: a pre-release tagged agent-preview-v<version>, whose zip is
# named for that SAME version (a release holding another version's zip would offer one version and install another).
# A build missing either is passed over, never installed; a draft, a full release, and dapa's and dapa dev's builds
# are never taken. Every Mac reads JSON with JavaScript for Automation; no extra tools.
pick="$(osascript -l JavaScript -e 'function run(argv) {
  const body = JSON.parse(argv[0]);
  const channel = argv[1];
  const sumOf = (file) => file && /^sha256:([0-9a-f]{64})$/i.exec(file.digest || "");
  let best = null;
  let rel = null;
  let file = null;
  for (const r of Array.isArray(body) ? body : []) {
    const m = new RegExp(`^${channel}-v((\\d+)\\.(\\d+)\\.(\\d+))$`).exec(r.tag_name || "");
    const zip = m ? (r.assets || []).find((a) => (a.name || "") === `dapa-${channel}-${m[1]}-mac-arm64.zip`) : null;
    if (!m || r.draft || r.prerelease !== true || !sumOf(zip)) continue;
    const v = [Number(m[2]), Number(m[3]), Number(m[4])];
    const newer = !best || v[0] > best[0] || (v[0] === best[0] && (v[1] > best[1] || (v[1] === best[1] && v[2] > best[2])));
    if (newer) { best = v; rel = r; file = zip; }
  }
  const sum = sumOf(file);
  return rel && sum ? [rel.tag_name, file.name, file.url, file.size, sum[1].toLowerCase()].join("\t") : "";
}' "$(cat "$tmp/list.json")" "$channel" 2>/dev/null)"
[[ -n "$pick" ]] || stop "Your key works, but there is no $app build for a Mac to download yet. Report this."
IFS=$'\t' read -r tag name url size sum <<< "$pick"

# 2. Download it. Half a file is never left looking whole.
print -P "\n%F{cyan}$app ${tag#$channel-}%f"
print "Downloading $(( size / 1048576 )) MB. This takes a few minutes."
gh_curl -fL --progress-bar -H "Accept: application/octet-stream" -o "$tmp/$name.part" "$url" \
  || stop "The download stopped early. Run this again."

# 3. Check it is exactly the file Kevin published, byte for byte.
[[ "$(shasum -a 256 "$tmp/$name.part" | cut -d' ' -f1)" == "$sum" ]] \
  || stop "The download was damaged. Nothing was kept. Run this again."
ditto -x -k "$tmp/$name.part" "$tmp/unpacked" && [[ -d "$tmp/unpacked/$app.app" ]] \
  || stop "The download would not unpack. Nothing was changed. Report this."

# 4. Hand the key to the app, so it is never pasted a second time. The app claims this file the first time it
# starts: it stores the key in the Mac keychain, then deletes the file. Running this again with a NEW key is also
# how a key is replaced.
data="$HOME/Library/Application Support/$data_name"
mkdir -p "$data" && (umask 077 && print -rn -- "$key" > "$data/update-key.txt") \
  || stop "Could not hand the key to $app. Nothing was installed."

# 5. Install for you only, in ~/Applications: no admin password, and its settings stay. A running copy of this app
# is closed first (only when it IS running: asking a closed app to quit would open it). The running check looks for
# the program's whole path, which does not depend on how many letters of a program's name a Mac keeps ("dapa agent
# preview" is 18; MEASURED 2026-11-10 on macOS 27: the path check and a name check both find a running copy). dapa and
# dapa dev are separate apps, so installing this one never closes either.
print -P "%F{green}Checked. Installing now.%f"
if pgrep -fq "/$app.app/Contents/MacOS/$app"; then osascript -e "quit app \"$app\"" >/dev/null 2>&1; sleep 2; fi
apps="$HOME/Applications"
mkdir -p "$apps" && rm -rf "$apps/$app.app" && mv "$tmp/unpacked/$app.app" "$apps/$app.app" \
  || stop "Could not put $app in $apps. Close $app, then run this again."
print -P "\n%F{green}$app is installed beside dapa and dapa dev, in your Applications folder.%f"
print "It keeps itself up to date with its own builds. dapa and dapa dev stay as they are."
open "$apps/$app.app"
