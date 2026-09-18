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
