# Install dapa

You need two things: a Windows PC or a Mac, and the key you were sent.

There is one line for Windows and one for a Mac. Use the one for your computer.

The same key works on both.

## Install it on Windows

Open PowerShell. To find it, press the Windows key, type PowerShell, and press Enter.

Paste this line and press Enter.

```powershell
iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.ps1')
```

It asks for your key. Paste the key and press Enter.

The key shows as stars while you paste. That is normal.

It then downloads dapa and installs it. That takes a few minutes.

You do not need admin rights. dapa installs for you only.

## Install it on a Mac

dapa runs on a Mac with Apple silicon, M1 or newer.

Open Terminal. To find it, press Command and Space, type Terminal, and press Return.

Paste this line and press Return.

```zsh
if S="$(curl -fsSL https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.sh)"; then zsh -c "$S"; fi
```

It asks for your key. Paste the key and press Return.

The key stays hidden while you paste. That is normal.

It then downloads dapa and puts it in your own Applications folder.

You do not need PowerShell or an admin password.

## If you are at Deloitte

You get different lines, one for Windows and one for a Mac. They fetch everything from Deloitte.

## Updates

There is nothing more to do. You paste your key once, here.

dapa keeps that key and updates itself when a new version comes out.

If your key is replaced, run the same one line again with the new key.

## If it says the key did not work

Keys stop working after a set time. Request a new key.

## If it says this is the wrong line

Each line checks the computer first. On the wrong computer it stops, and nothing is installed.

Use the other line.

## What this script does

It finds the current dapa download for your computer and downloads it.

It checks the file against the published fingerprint before anything runs.

If the file does not match, it is deleted and nothing is installed.

This script holds no key and no password. It only asks you for yours.

## DTect, only if you need it

DTect is a PowerShell module. Install it only if you were told you need it.

It needs its own key. Your dapa key does not open it. Request a DTect key.

Open PowerShell. Paste this line and press Enter.

```powershell
iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/NoGit/main/module/NoGit/Public/Get-NoGitHubRepoTreeContents.ps1'); $o = 'kevinblumenfeld'; $base = ($env:PSModulePath -split [IO.Path]::PathSeparator | ? { $_ -and $_.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase) } | select -First 1); if (-not $base) { $base = if (($PSVersionTable.PSVersion.Major -ge 7) -and -not $IsWindows) { Join-Path $HOME '.local/share/powershell/Modules' } else { [IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), $(if ($PSVersionTable.PSVersion.Major -ge 7) { 'PowerShell\Modules' } else { 'WindowsPowerShell\Modules' })) } }; $mods = @(@{ n = 'dTect'; r = 'GacTools'; b = 'D-TECT'; p = 'Build/DTect/' }, @{ n = 'ImportExcel'; r = 'DTECT-Resources'; b = 'main'; p = 'Resources/SupportingModules/ImportExcel' }, @{ n = 'PSParallelPipeline'; r = 'DTECT-Resources'; b = 'main'; p = 'Resources/SupportingModules/PSParallelPipeline' }); $menu = ((0..($mods.Count - 1)) | % { ("{0}) {1}" -f ($_ + 1), $mods[$_].n) }) -join "`n"; $t = Read-Host 'Paste your GitHub PAT to start'; $dl = { param($m) if ([string]::IsNullOrWhiteSpace($t)) { Write-Host 'No token set. Choose K to paste your key.' } else { Get-NoGitHubRepoTreeContents -Token $t -Owner $o -Repo $m.r -Branch $m.b -SourcePath $m.p -TargetDir ([IO.Path]::Combine($base, $m.n)) -Verbose } }; $last = $null; while ($true) { $extra = if ($last) { "`nL) Last ($last)" } else { "" }; $ans = Read-Host ("Installing into $base`nSelect module(s) to install (comma-separated for multiple):`n$menu`nA) All`nK) Paste/Change key`nQ) Quit$extra"); if (!$ans -or $ans -match '^[Qq]$') { break } elseif ($ans -match '^[Kk]$') { $new = Read-Host 'Paste your GitHub PAT (leave blank to keep current)'; if (-not [string]::IsNullOrWhiteSpace($new)) { $t = $new } } elseif ($ans -match '^[Aa]$') { $last = 'All'; $mods | % { & $dl $_ }; Write-Host 'All done.' } elseif ($ans -match '^[Ll]$' -and $last) { $names = if ($last -eq 'All') { $mods.n } else { $last -split ', ' }; $mods | ? { $names -contains $_.n } | % { & $dl $_ }; Write-Host 'Done.' } else { $nums = $ans -split ',' | % { $_.Trim() } | ? { $_ }; $valid = $true; $selected = @(); foreach ($num in $nums) { $i = 0; if ([int]::TryParse($num, [ref]$i) -and $i -ge 1 -and $i -le $mods.Count) { $selected += $mods[$i - 1] } else { $valid = $false; break } }; if ($valid -and $selected.Count -gt 0) { $last = ($selected.n) -join ', '; $selected | % { & $dl $_ }; Write-Host 'Done.' } else { Write-Host 'Invalid choice.' } } }
```

It asks for a GitHub PAT. Paste your DTect key there and press Enter.

Then pick what to install. A installs all three. Type Q when you are done.

On a Mac, DTect needs PowerShell installed first.
