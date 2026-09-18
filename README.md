# Install dapa

You need two things. A Windows PC or a Mac, and the key you were sent.

On a Mac, see "On a Mac" below.

## Install it

Open PowerShell. Paste the one line you were sent and press Enter.

If you are at Deloitte, you get a different line. It fetches everything from Deloitte.

Everyone else, use this line.

```powershell
iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.ps1')
```

Your key only works with its own line. Use the one that matches your key.

It asks for your key. Paste the key and press Enter.

It then downloads dapa and installs it. That takes a few minutes.

You do not need admin rights. dapa installs for you only.

## On a Mac

dapa runs on a Mac with Apple silicon, M1 or newer.

Open Terminal. Paste this line and press Enter.

```zsh
if S="$(curl -fsSL https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.sh)"; then zsh -c "$S"; fi
```

If you are at Deloitte, you get a different line. It fetches everything from Deloitte.

It asks for your key. Paste the key and press Enter.

dapa goes into your own Applications folder. You do not need an admin password.

## Updates

There is nothing more to do. You paste your key once, here.

dapa keeps that key and updates itself when a new version comes out.

If your key is replaced, run the same one line again with the new key.

## If it says the key did not work

Keys stop working after a set time. Request a new key.

## What this script does

It finds the current dapa download for your computer and downloads it.

It checks the file against the published fingerprint before anything runs.

If the file does not match, it is deleted and nothing is installed.

This script holds no key and no password. It only asks you for yours.
