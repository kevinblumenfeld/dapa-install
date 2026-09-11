# Install dapa

You need two things. A Windows PC, and the key Kevin sent you.

## Install it

Open PowerShell. Paste the one line Kevin sent you and press Enter.

If you are at Deloitte, Kevin sends you a different line. It fetches everything from Deloitte.

Everyone else, use this line.

```powershell
iex (irm 'https://raw.githubusercontent.com/kevinblumenfeld/dapa-install/main/dapa.ps1')
```

Your key only works with its own line. Use the one that matches your key.

It asks for your key. Paste the key and press Enter.

It then downloads dapa and installs it. That takes a few minutes.

You do not need admin rights. dapa installs for you only.

## Updates

There is nothing more to do. You paste your key once, here.

dapa keeps that key and updates itself when a new version comes out.

If your key is replaced, run the same one line again with the new key.

## If it says the key did not work

Keys stop working after a set time. Ask Kevin for a new one.

## What this script does

It asks GitHub for the current dapa installer and downloads it.

It checks the file against the published fingerprint before anything runs.

If the file does not match, it is deleted and nothing is installed.

This script holds no key and no password. It only asks you for yours.
