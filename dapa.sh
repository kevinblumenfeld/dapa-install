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
# DAPA DEV (2026-10-19): the dev branch's own app, "dapa dev", which installs BESIDE dapa and updates only
# from dev builds. Its lines are the ones above with DAPA_BRANCH=dev before zsh: on the Deloitte line,
# "DAPA_FEED=deloitte DAPA_BRANCH=dev zsh -c ..."; on Kevin's, "DAPA_BRANCH=dev zsh -c ...". The same
# key works. A Mac's dapa dev starts with its own settings: the Mac keeps dapa's saved secrets under
# dapa's own name, so a copy of dapa's data could not open them.
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
# WHICH APP: dapa, or dapa dev when the line says DAPA_BRANCH=dev. Its names match the app
# (desktop/src/build-flavor.ts in the dapa source).
branch="${DAPA_BRANCH:-main}"
case "${branch:l}" in
  main) app="dapa"; prefix="dapa"; data_name="dapa-desktop" ;;
  dev) app="dapa dev"; prefix="dapa-dev"; data_name="dapa-desktop-dev" ;;
  *) stop "STOPPED: '$branch' is not a dapa build. Use 'dev', or leave it out for dapa. Nothing was installed." ;;
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

# 1. Ask which version is current. The key is what gets you in. dapa asks for the latest release, which
# is never a pre-release; dapa dev asks for the release list and takes its newest dev build.
if [[ "$app" == "dapa dev" ]]; then ask="$api/releases?per_page=50"; else ask="$api/releases/latest"; fi
code="$(gh_curl -sS -o "$tmp/latest.json" -w '%{http_code}' "$ask")" \
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
# dapa dev takes the newest dev build holding its Mac zip with a checksum: a pre-release tagged
# dev-v<version>. A build missing either is passed over, never installed.
pick="$(osascript -l JavaScript -e 'function run(argv) {
  const body = JSON.parse(argv[0]);
  const dev = argv[1] === "dapa-dev";
  const zipFor = (rel) => (rel.assets || []).find((a) => (dev ? /^dapa-dev-.*mac-arm64\.zip$/i : /^dapa-.*mac-arm64\.zip$/i).test(a.name));
  const sumOf = (file) => file && /^sha256:([0-9a-f]{64})$/i.exec(file.digest || "");
  let rel = body;
  if (dev) {
    rel = null;
    let best = null;
    for (const r of Array.isArray(body) ? body : []) {
      const m = /^dev-v(\d+)\.(\d+)\.(\d+)$/.exec(r.tag_name || "");
      if (!m || r.draft || r.prerelease !== true || !sumOf(zipFor(r))) continue;
      const v = [Number(m[1]), Number(m[2]), Number(m[3])];
      const newer = !best || v[0] > best[0] || (v[0] === best[0] && (v[1] > best[1] || (v[1] === best[1] && v[2] > best[2])));
      if (newer) { best = v; rel = r; }
    }
    if (!rel) return "";
  }
  const file = zipFor(rel);
  const sum = sumOf(file);
  return file && sum ? [rel.tag_name, file.name, file.url, file.size, sum[1].toLowerCase()].join("\t") : "";
}' "$(cat "$tmp/latest.json")" "$prefix" 2>/dev/null)"
if [[ -z "$pick" && "$app" == "dapa dev" ]]; then stop "Your key works, but there is no dapa dev build for a Mac to download yet. Report this."; fi
[[ -n "$pick" ]] || stop "This version has no Mac download that can be checked, so nothing was installed. Report this."
IFS=$'\t' read -r tag name url size sum <<< "$pick"

# 2. Download it. Half a file is never left looking whole.
print -P "\n%F{cyan}$app ${tag#dev-}%f"
print "Downloading $(( size / 1048576 )) MB. This takes a few minutes."
gh_curl -fL --progress-bar -H "Accept: application/octet-stream" -o "$tmp/$name.part" "$url" \
  || stop "The download stopped early. Run this again."

# 3. Check it is exactly the file Kevin published, byte for byte.
[[ "$(shasum -a 256 "$tmp/$name.part" | cut -d' ' -f1)" == "$sum" ]] \
  || stop "The download was damaged. Nothing was kept. Run this again."
ditto -x -k "$tmp/$name.part" "$tmp/unpacked" && [[ -d "$tmp/unpacked/$app.app" ]] \
  || stop "The download would not unpack. Nothing was changed. Report this."

# 4. Hand the key to the app, so it is never pasted a second time. The app claims this file the first
# time it starts: it stores the key in the Mac keychain, then deletes the file. Running this again with
# a NEW key is also how a key is replaced. dapa dev has a data folder of its own.
data="$HOME/Library/Application Support/$data_name"
mkdir -p "$data" && (umask 077 && print -rn -- "$key" > "$data/update-key.txt") \
  || stop "Could not hand the key to $app. Nothing was installed."

# 5. Install for you only, in ~/Applications: no admin password, and your settings stay. A running
# copy of this app is closed first (only when it IS running: asking a closed app to quit would open
# it). dapa and dapa dev are separate apps, so installing one never closes the other.
print -P "%F{green}Checked. Installing now.%f"
if pgrep -xq "$app"; then osascript -e "quit app \"$app\"" >/dev/null 2>&1; sleep 2; fi
apps="$HOME/Applications"
mkdir -p "$apps" && rm -rf "$apps/$app.app" && mv "$tmp/unpacked/$app.app" "$apps/$app.app" \
  || stop "Could not put $app in $apps. Close $app, then run this again."
if [[ "$app" == "dapa dev" ]]; then
  print -P "\n%F{green}dapa dev is installed beside dapa, in your Applications folder.%f"
  print "It keeps itself up to date with dev builds. dapa stays as it is."
else
  print -P "\n%F{green}dapa is installed in your Applications folder.%f"
  print "It will keep itself up to date. There is nothing else to paste."
fi
open "$apps/$app.app"
