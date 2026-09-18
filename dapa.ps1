# dapa - install or update, in one line.
#
# This file holds no key and no secret. It asks for your key, then downloads the current dapa
# installer straight from a private release and checks it before it runs. Works in Windows
# PowerShell 5.1 and PowerShell 7.
#
# The SAME file lives in two places, and each place has its own one line:
#
#   Deloitte (production) - the file sits in Deloitte's private release repo, so the line asks for
#   the key FIRST, uses it to fetch this file, and this file reuses it. Nothing public is involved.
#   The try/catch is there because a wrong key fails BEFORE this file exists on the machine, so this
#   file cannot explain it; $DapaScript is cleared first so a stale copy from an earlier run is never
#   the one that runs:
#     $DapaScript=$null; $DapaFeed='deloitte'; $DapaKey=[Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host 'Paste your dapa key' -AsSecureString))); try { $DapaScript = irm 'https://api.github.com/repos/Deloitte-US-Consulting/dapa-release/contents/dapa.ps1' -Headers @{Authorization="Bearer $DapaKey"; Accept='application/vnd.github.raw'} } catch { Write-Host 'That key cannot reach the dapa download. Request a new key.' -ForegroundColor Red }; if ($DapaScript) { iex $DapaScript }
#
#   Kevin's own feed - the file is public, so it is fetched first and asks for the key itself:
#     iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.ps1')
#
# A Mac has its own lines, in the Mac's own Terminal, with no PowerShell: see dapa.sh beside this file.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'    # a visible progress bar makes the download crawl
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# The right computer, before the key is asked for. PowerShell also runs on a Mac, where it is optional,
# and a Mac installs dapa through the Mac line in Terminal instead. $IsWindows exists only in
# PowerShell 6 and later, and Windows PowerShell 5.1 runs on Windows alone, so the version is asked
# first: -and stops there on 5.1, which matters because strict mode turns reading a variable that
# does not exist into an error (Codex installmac-r1, finding 1).
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
  Write-Host "`nSTOPPED: this line installs dapa on Windows. On a Mac, open Terminal and use the Mac line. Nothing was installed." -ForegroundColor Red
  return
}

# The RELEASE repos, which hold installers and no source code. A key for one is worth exactly one
# installer: GitHub has no releases-only permission, so a key for the source repo would also clone
# dapa. These must match FEED_REPOS in the app (desktop/src/updater.ts).
#
# Two of them, because dapa ships from two places and Deloitte is production. $DapaFeed chooses;
# anything not on this list is refused, so a stray value can never send a customer's key somewhere
# we did not publish. The names are deliberately specific ($DapaFeed, $DapaKey, not $Feed or $k): a
# generic variable already sitting in someone's session must never be taken for one of these.
$repos = @{ personal = 'kevinblumenfeld/dapa-release'; deloitte = 'Deloitte-US-Consulting/dapa-release' }
# Get-Variable, not $DapaFeed: the personal line never sets these two, and strict mode would stop the
# script on reading a variable that does not exist.
$feedIn = Get-Variable -Name DapaFeed -ValueOnly -ErrorAction SilentlyContinue
$keyIn = Get-Variable -Name DapaKey -ValueOnly -ErrorAction SilentlyContinue
$which = if ($feedIn) { "$feedIn".Trim().ToLower() } else { 'personal' }
if (-not $repos.ContainsKey($which)) {
  Write-Host "`nSTOPPED: '$which' is not a dapa download. Use 'personal' or 'deloitte'." -ForegroundColor Red
  return
}
$repo = $repos[$which]
function Stop-Dapa([string]$m) { Write-Host "`n$m" -ForegroundColor Red }

# The Deloitte line already asked for the key to fetch this file, so reuse it: one paste, not two.
# The prompt hides the key as it is pasted, as the Mac line does: a key on screen can be read over a
# shoulder or caught by a screen share (Codex installmac-r1, finding 2). SecureStringToBSTR with
# PtrToStringBSTR reads it back the same way in Windows PowerShell 5.1 and PowerShell 7.
function Read-DapaKey {
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host 'Paste your dapa key' -AsSecureString))
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
$key = if ($keyIn) { "$keyIn".Trim() } else { "$(Read-DapaKey)".Trim() }
if (-not $key) { Stop-Dapa 'No key was pasted. Nothing was installed.'; return }

# 1. Ask which version is current. The key is what gets you in.
$head = @{ Authorization = "Bearer $key"; 'User-Agent' = 'dapa-install' }
try {
  $body = (Invoke-WebRequest "https://api.github.com/repos/$repo/releases/latest" -Headers $head -UseBasicParsing).Content
}
catch {
  $code = 0
  try { $code = [int]$_.Exception.Response.StatusCode } catch { }
  # These three mean very different things, and saying so is what stops a wasted round trip: a
  # customer who hears "wrong key" retypes it forever when the real problem is which boxes were
  # ticked when the key was made (MEASURED 2026-09-11 - a valid key with no repository selected
  # answers 404 here, exactly like no key at all).
  if ($code -eq 401) { Stop-Dapa 'That key is not valid. Request a new key.' }
  elseif ($code -eq 403 -or $code -eq 404) {
    # A 404 on releases/latest means EITHER "this key cannot see the repo" OR "the repo has no release
    # yet" - GitHub answers both the same way. Ask about the repo itself to tell them apart, because
    # the fix is completely different: a new key, or Kevin publishing a release (MEASURED 2026-09-11,
    # a working Deloitte key read "cannot reach the download" before the first release existed).
    $canSee = $false
    try { $null = Invoke-WebRequest "https://api.github.com/repos/$repo" -Headers $head -UseBasicParsing; $canSee = $true } catch { }
    if ($canSee) { Stop-Dapa 'Your key works, but there is no dapa release to download yet. Report this.' }
    else { Stop-Dapa 'That key cannot reach the dapa download. Request a new key.' }
  }
  else { Stop-Dapa "Could not reach the download. Check your internet, then run this again. ($($_.Exception.Message))" }
  return
}

$rel = $body | ConvertFrom-Json
$file = $rel.assets | Where-Object { $_.name -match '^dapa-.*win-x64-install\.exe$' } | Select-Object -First 1
$sum = [regex]::Match("$($file.digest)", '^sha256:([0-9a-f]{64})$', 'IgnoreCase')
if (-not $file -or -not $sum.Success) { Stop-Dapa 'This version cannot be checked, so it will not be installed. Report this.'; return }

# 2. Download it. Half a file is never left looking whole.
$exe = Join-Path $env:TEMP $file.name
Write-Host "`ndapa $($rel.tag_name)" -ForegroundColor Cyan
Write-Host "Downloading $([math]::Round($file.size / 1MB)) MB. This takes a few minutes."
$head['Accept'] = 'application/octet-stream'
try { Invoke-WebRequest $file.url -Headers $head -OutFile "$exe.part" -UseBasicParsing }
catch { Stop-Dapa "The download stopped early. Run this again. ($($_.Exception.Message))"; return }

# 3. Check it is exactly the file Kevin published, byte for byte.
if ((Get-FileHash "$exe.part" -Algorithm SHA256).Hash -ne $sum.Groups[1].Value.ToUpper()) {
  Remove-Item "$exe.part" -Force
  Stop-Dapa 'The download was damaged. Nothing was kept. Run this again.'
  return
}
Move-Item "$exe.part" $exe -Force

# 4. Hand the key to dapa, so it is never pasted a second time. dapa claims this file the first time
# it starts: it stores the key the way Windows encrypts secrets, then deletes the file. Running this
# script again with a NEW key is also how a key is replaced.
$data = Join-Path $env:APPDATA 'dapa-desktop'
if (-not (Test-Path $data)) { New-Item -ItemType Directory -Path $data -Force | Out-Null }
Set-Content -Path (Join-Path $data 'update-key.txt') -Value $key -Encoding utf8 -NoNewline

# 5. Install. No admin rights. It installs for you only, and keeps your settings.
Write-Host 'Checked. Installing now.' -ForegroundColor Green
Start-Process $exe -Wait
Remove-Item $exe -Force -ErrorAction SilentlyContinue
Write-Host "`ndapa is installed. Open it from the Start menu." -ForegroundColor Green
Write-Host 'It will keep itself up to date. There is nothing else to paste.'
