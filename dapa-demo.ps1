# dapa demo - install or update, in one line.
#
# dapa demo (2026-11-11) is the demo branch's own app: dapa dev plus the Coverage Gaps device filters and the Record
# button, the build shown at Microsoft Ignite. It is its own app that installs BESIDE dapa, dapa dev and dapa agent
# preview, with its own name, folders and Start menu icon, and it updates only from its own builds. This file installs
# it and nothing else: the other apps keep their own lines (dapa.ps1 and dapa-agent-preview.ps1 beside this file),
# which this file never changes.
#
# This file holds no key and no secret. It asks for your key, then downloads the newest dapa demo installer straight
# from a private release and checks it before it runs. dapa's key works: its builds sit in the same release repo, as
# pre-releases that dapa, dapa dev and dapa agent preview never offer. Works in Windows PowerShell 5.1 and PowerShell 7.
#
# The SAME file lives in two places, and each place has its own one line:
#
#   Deloitte (production) - the file sits in Deloitte's private release repo, so the line asks for the key FIRST,
#   uses it to fetch this file, and this file reuses it:
#     $DapaScript=$null; $DapaFeed='deloitte'; $DapaKey=[Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host 'Paste your dapa key' -AsSecureString))); try { $DapaScript = irm 'https://api.github.com/repos/Deloitte-US-Consulting/dapa-release/contents/dapa-demo.ps1' -Headers @{Authorization="Bearer $DapaKey"; Accept='application/vnd.github.raw'} } catch { Write-Host 'That key cannot reach the dapa download. Request a new key.' -ForegroundColor Red }; if ($DapaScript) { iex $DapaScript }
#
#   Kevin's own feed - the file is public, so it is fetched first and asks for the key itself:
#     iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa-demo.ps1')
#
# Its FIRST install starts from a copy of dapa dev's connections and settings on this PC (the demo branch is dev
# plus the device filters and the Record button), or dapa's when this PC has no dapa dev. A Mac has its own line, in
# the Mac's own Terminal: see dapa-demo.sh beside this file.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'    # a visible progress bar makes the download crawl
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# The right computer, before the key is asked for. $IsWindows exists only in PowerShell 6 and later, and Windows
# PowerShell 5.1 runs on Windows alone, so the version is asked first (dapa.ps1 says why).
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
  Write-Host "`nSTOPPED: this line installs dapa demo on Windows. On a Mac, open Terminal and use the Mac line. Nothing was installed." -ForegroundColor Red
  return
}

# The RELEASE repos, the same two dapa installs from (FEED_REPOS in desktop/src/updater.ts). $DapaFeed chooses;
# anything not on this list is refused, so a stray value can never send a key somewhere nothing was published.
# Get-Variable, not $DapaFeed: the personal line never sets these, and strict mode would stop on reading a variable
# that does not exist.
$repos = @{ personal = 'kevinblumenfeld/dapa-release'; deloitte = 'Deloitte-US-Consulting/dapa-release' }
$feedIn = Get-Variable -Name DapaFeed -ValueOnly -ErrorAction SilentlyContinue
$keyIn = Get-Variable -Name DapaKey -ValueOnly -ErrorAction SilentlyContinue
$which = if ($feedIn) { "$feedIn".Trim().ToLower() } else { 'personal' }
if (-not $repos.ContainsKey($which)) {
  Write-Host "`nSTOPPED: '$which' is not a dapa download. Use 'personal' or 'deloitte'." -ForegroundColor Red
  return
}
$repo = $repos[$which]
# The app's names: its builds' tags and files, its data folder, and what people see. They match the app
# (DEMO_APP in desktop/src/build-flavor.ts of the demo branch).
$app = 'dapa demo'
$channel = 'demo'
$dataName = 'dapa-demo'
function Stop-Dapa([string]$m) { Write-Host "`n$m" -ForegroundColor Red }

# The Deloitte line already asked for the key to fetch this file, so reuse it: one paste, not two. The prompt hides
# the key as it is pasted: a key on screen can be read over a shoulder or caught by a screen share.
function Read-DapaKey {
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host 'Paste your dapa key' -AsSecureString))
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
$key = if ($keyIn) { "$keyIn".Trim() } else { "$(Read-DapaKey)".Trim() }
if (-not $key) { Stop-Dapa 'No key was pasted. Nothing was installed.'; return }

# 1. Ask which builds there are. The key is what gets you in.
$head = @{ Authorization = "Bearer $key"; 'User-Agent' = 'dapa-install' }
try {
  $body = (Invoke-WebRequest "https://api.github.com/repos/$repo/releases?per_page=50" -Headers $head -UseBasicParsing).Content
}
catch {
  $code = 0
  try { $code = [int]$_.Exception.Response.StatusCode } catch { }
  # A 401 is a bad key; a 403 or 404 is a key that cannot see the repo (asked about the repo itself to be sure).
  if ($code -eq 401) { Stop-Dapa 'That key is not valid. Request a new key.' }
  elseif ($code -eq 403 -or $code -eq 404) {
    $canSee = $false
    try { $null = Invoke-WebRequest "https://api.github.com/repos/$repo" -Headers $head -UseBasicParsing; $canSee = $true } catch { }
    if ($canSee) { Stop-Dapa "Your key works, but there is no $app build to download yet. Report this." }
    else { Stop-Dapa 'That key cannot reach the dapa download. Request a new key.' }
  }
  else { Stop-Dapa "Could not reach the download. Check your internet, then run this again. ($($_.Exception.Message))" }
  return
}

# The newest build holding the Windows installer with a checksum: a pre-release tagged demo-v<version>,
# whose file is named for that SAME version (a release holding another version's file would offer one version and
# install another). A build missing its file or its checksum is passed over, never installed; a draft, a full
# release, and dapa's and dapa dev's builds are never taken. The list goes into a variable before it is walked:
# Windows PowerShell 5.1 hands a JSON list on as ONE object, and a variable holds it as the list it is.
$list = $body | ConvertFrom-Json
$rel = $null
$file = $null
$newest = $null
foreach ($r in $list) {
  if ($r.draft -or $r.prerelease -ne $true -or "$($r.tag_name)" -cnotmatch "^$channel-v((\d+)\.(\d+)\.(\d+))$") { continue }
  $v = [version]::new([int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
  $want = "dapa-$channel-$($Matches[1])-win-x64-install.exe"
  $f = $r.assets | Where-Object { $_.name -ceq $want } | Select-Object -First 1
  if (-not $f -or "$($f.digest)" -notmatch '^sha256:[0-9a-f]{64}$') { continue }
  if (-not $newest -or $v -gt $newest) { $rel = $r; $file = $f; $newest = $v }
}
if (-not $rel) { Stop-Dapa "Your key works, but there is no $app build to download yet. Report this."; return }
$sum = [regex]::Match("$($file.digest)", '^sha256:([0-9a-f]{64})$', 'IgnoreCase')
if (-not $sum.Success) { Stop-Dapa 'This version cannot be checked, so it will not be installed. Report this.'; return }

# 2. Download it. Half a file is never left looking whole.
$exe = Join-Path $env:TEMP $file.name
Write-Host "`n$app $("$($rel.tag_name)" -replace "^$channel-", '')" -ForegroundColor Cyan
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

# 4. Hand the key to the app, so it is never pasted a second time. The app claims this file the first time it
# starts: it stores the key the way Windows encrypts secrets, then deletes the file. Running this again with a NEW
# key is also how a key is replaced.
$data = Join-Path $env:APPDATA $dataName
# The FIRST install starts from a copy of dapa dev's data on this PC, or dapa's when there is no dapa dev, so the
# connections and settings are already there. Once only: an existing dapa demo folder is never touched.
# Windows keeps the key to the saved secrets per person, so the copy opens them too. Caches, logs and update
# downloads stay behind, as in dapa.ps1. robocopy skips a file the other app holds open instead of stopping. The
# copy only reads the other app's folder.
$fromName = 'dapa dev'
$from = Join-Path $env:APPDATA 'dapa-dev'
if (-not (Test-Path $from)) { $fromName = 'dapa'; $from = Join-Path $env:APPDATA 'dapa-desktop' }
if (-not (Test-Path $data) -and (Test-Path $from)) {
  if (Get-Process -Name $fromName -ErrorAction SilentlyContinue) {
    Write-Host "$fromName is open. Close it so its data copies cleanly, then press Enter." -ForegroundColor Yellow
    $null = Read-Host
  }
  Write-Host "Copying your $fromName connections and settings to $app, once. Downloaded AI models make this slower."
  $skipFolders = @('Cache', 'Code Cache', 'GPUCache', 'DawnGraphiteCache', 'DawnWebGPUCache', 'Crashpad', 'updates')
  $skipFiles = @('dapa.log', 'dapa.log.old', 'main.log', 'DevToolsActivePort', 'lockfile', 'SingletonLock', 'update-key.txt')
  robocopy $from $data /E /R:0 /W:0 /NFL /NDL /NJH /NJS /NP /XD @skipFolders /XF @skipFiles | Out-Null
  if ($LASTEXITCODE -ge 8) { Write-Host "Some of it could not be copied. $app starts with the rest." -ForegroundColor Yellow }
}
if (-not (Test-Path $data)) { New-Item -ItemType Directory -Path $data -Force | Out-Null }
Set-Content -Path (Join-Path $data 'update-key.txt') -Value $key -Encoding utf8 -NoNewline

# 5. Install. No admin rights. It installs for you only, keeps its settings, and never closes dapa or dapa dev.
Write-Host 'Checked. Installing now.' -ForegroundColor Green
Start-Process $exe -Wait
Remove-Item $exe -Force -ErrorAction SilentlyContinue
Write-Host "`n$app is installed beside dapa and dapa dev. Open it from the Start menu: $app." -ForegroundColor Green
Write-Host 'It keeps itself up to date with its own builds. dapa and dapa dev stay as they are.'
