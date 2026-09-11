# dapa - install or update, in one line.
#
#   iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.ps1')
#
# This file is public. It holds no key and no secret. It asks you for your key, then downloads
# the current dapa installer straight from the private release and checks it before it runs.
# Works in Windows PowerShell 5.1 and PowerShell 7.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'    # a visible progress bar makes the download crawl
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# The RELEASE repos, which hold installers and no source code. A key for one is worth exactly one
# installer: GitHub has no releases-only permission, so a key for the source repo would also clone
# dapa. These must match FEED_REPOS in the app (desktop/src/updater.ts).
#
# Two of them, because dapa ships from two places and Deloitte is production. Set $Feed before this
# script runs to choose; anything not on this list is refused, so a stray value can never send a
# customer's key somewhere we did not publish:
#   $Feed='deloitte'; iex (irm '<this url>')
$repos = @{ personal = 'kevinblumenfeld/dapa-release'; deloitte = 'Deloitte-US-Consulting/dapa-release' }
$which = if ($Feed) { "$Feed".Trim().ToLower() } else { 'personal' }
if (-not $repos.ContainsKey($which)) {
  Write-Host "`nSTOPPED: '$which' is not a dapa download. Use 'personal' or 'deloitte'." -ForegroundColor Red
  return
}
$repo = $repos[$which]
function Stop-Dapa([string]$m) { Write-Host "`n$m" -ForegroundColor Red }

$key = (Read-Host 'Paste your dapa key').Trim()
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
  if ($code -eq 401) { Stop-Dapa 'That key is not valid. It was mistyped, or it has been cancelled. Ask Kevin for a new one.' }
  elseif ($code -eq 403 -or $code -eq 404) { Stop-Dapa 'That key is valid, but it cannot reach the dapa download. Ask Kevin for a new one, and tell him it needs access to the dapa-release repository.' }
  else { Stop-Dapa "Could not reach the download. Check your internet, then run this again. ($($_.Exception.Message))" }
  return
}

$rel = $body | ConvertFrom-Json
$file = $rel.assets | Where-Object { $_.name -match '^dapa-.*win-x64-install\.exe$' } | Select-Object -First 1
$sum = [regex]::Match("$($file.digest)", '^sha256:([0-9a-f]{64})$', 'IgnoreCase')
if (-not $file -or -not $sum.Success) { Stop-Dapa 'This version cannot be checked, so it will not be installed. Tell Kevin.'; return }

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
