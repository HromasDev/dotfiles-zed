# Zed config

Zed settings synced via git, auto-committed and pushed on every change, on Windows, macOS, and Linux.

## Windows

Windows has no native "run task on file change" trigger, and this account has no
symlink or Task Scheduler privilege, so config is kept in sync by a small
always-on watcher instead of symlinks. It uses `FileSystemWatcher` to react
instantly to changes (no polling), sits at ~0% CPU while idle, and:

- on change in `%APPDATA%\Zed\` → copies changed files into this repo, commits, pulls, pushes
- on pull bringing in changes from another machine → copies them back onto `%APPDATA%\Zed\`

It launches at logon via a silent VBScript in the Startup folder (no console window).
The watcher itself lives in the parent [`dotfiles`](https://github.com/HromasDev/dotfiles)
repo, at `scripts/watch-sync.ps1` — one generic script reused by every synced
config, not a copy per repo.

### Setup on a new Windows machine

Easiest: clone the [`dotfiles`](https://github.com/HromasDev/dotfiles) repo and run
`.\bootstrap.ps1 -Only zed` — it clones this repo as a submodule, seeds
`%APPDATA%\Zed\`, and starts the watcher for you.

To wire it up manually instead:

```powershell
git clone <this-repo-url> $env:USERPROFILE\dotfiles-zed
git clone https://github.com/HromasDev/dotfiles.git $env:USERPROFILE\dotfiles --depth 1 -n
git -C $env:USERPROFILE\dotfiles show HEAD:scripts/watch-sync.ps1 > $env:USERPROFILE\dotfiles-zed\..\watch-sync.ps1

# copy current live config into the repo once (skip if repo already has what you want)
$live = "$env:APPDATA\Zed"
$repo = "$env:USERPROFILE\dotfiles-zed\zed"
Copy-Item "$live\settings.json","$live\keymap.json","$live\tasks.json" $repo -Force
Copy-Item "$live\snippets","$live\themes" $repo -Recurse -Force

# install the silent startup launcher
$startup = [Environment]::GetFolderPath('Startup')
$watchScript = "$env:USERPROFILE\dotfiles\scripts\watch-sync.ps1"
$args = "-RepoPath ""$repo"" -LiveDir ""$live"" -Items settings.json,keymap.json,tasks.json,snippets,themes"
$vbs = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$watchScript"" $args", 0, False
"@
Set-Content -Path (Join-Path $startup "ZedConfigSync.vbs") -Value $vbs -Encoding ASCII

# start it now without waiting for next logon
cscript.exe //B (Join-Path $startup "ZedConfigSync.vbs")
```

If your account has Developer Mode enabled (or you run as admin), you can use real
symlinks instead — they survive `git checkout`/`pull` because they point by path,
not by inode (unlike hardlinks, which this repo avoided for exactly that reason).
In that case skip the watcher and symlink directly:

```powershell
cmd /c mklink "$env:APPDATA\Zed\settings.json" "$env:USERPROFILE\dotfiles-zed\zed\settings.json"
cmd /c mklink "$env:APPDATA\Zed\keymap.json" "$env:USERPROFILE\dotfiles-zed\zed\keymap.json"
cmd /c mklink "$env:APPDATA\Zed\tasks.json" "$env:USERPROFILE\dotfiles-zed\zed\tasks.json"
cmd /c mklink /D "$env:APPDATA\Zed\snippets" "$env:USERPROFILE\dotfiles-zed\zed\snippets"
cmd /c mklink /D "$env:APPDATA\Zed\themes" "$env:USERPROFILE\dotfiles-zed\zed\themes"
```
You'd still want *something* watching for changes to auto-commit/push — a
scheduled task with a "log on" trigger running a debounced `git add/commit/push`
loop, same idea as `sync-watch.ps1` minus the copy steps.

## macOS

Real symlinks work without any special privilege, so no watcher process needs to
copy anything — just link the files, then use `fswatch` + `launchd` to
auto-commit/push on change.

```bash
git clone <this-repo-url> ~/dotfiles-zed
mkdir -p ~/.config/zed
for f in settings.json keymap.json tasks.json; do
  rm -f ~/.config/zed/$f
  ln -s ~/dotfiles-zed/zed/$f ~/.config/zed/$f
done
for d in snippets themes; do
  rm -rf ~/.config/zed/$d
  ln -s ~/dotfiles-zed/zed/$d ~/.config/zed/$d
done

brew install fswatch
```

Sync script `~/dotfiles-zed/sync-watch.sh`:

```bash
#!/bin/bash
cd ~/dotfiles-zed
git pull --rebase --quiet
fswatch -o -l 5 zed | while read; do
  git add -A
  git diff --cached --quiet || git commit -q -m "sync: $(date '+%Y-%m-%d %H:%M:%S')"
  git pull --rebase --quiet
  git push --quiet
done
```

```bash
chmod +x ~/dotfiles-zed/sync-watch.sh
```

launchd agent `~/Library/LaunchAgents/com.zedconfig.sync.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>Label</key><string>com.zedconfig.sync</string>
  <key>ProgramArguments</key>
  <array><string>/Users/YOURNAME/dotfiles-zed/sync-watch.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/zedconfig-sync.log</string>
  <key>StandardErrorPath</key><string>/tmp/zedconfig-sync.log</string>
</dict></plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.zedconfig.sync.plist
```

## Linux

Same idea as macOS: real symlinks, `inotifywait` instead of `fswatch`,
`systemd --user` instead of `launchd`.

```bash
git clone <this-repo-url> ~/dotfiles-zed
mkdir -p ~/.config/zed
for f in settings.json keymap.json tasks.json; do
  rm -f ~/.config/zed/$f
  ln -s ~/dotfiles-zed/zed/$f ~/.config/zed/$f
done
for d in snippets themes; do
  rm -rf ~/.config/zed/$d
  ln -s ~/dotfiles-zed/zed/$d ~/.config/zed/$d
done

sudo apt install inotify-tools   # or your distro's equivalent
```

Sync script `~/dotfiles-zed/sync-watch.sh`:

```bash
#!/bin/bash
cd ~/dotfiles-zed
git pull --rebase --quiet
while inotifywait -r -e modify,create,delete,move -q zed; do
  sleep 5   # debounce
  git add -A
  git diff --cached --quiet || git commit -q -m "sync: $(date '+%Y-%m-%d %H:%M:%S')"
  git pull --rebase --quiet
  git push --quiet
done
```

```bash
chmod +x ~/dotfiles-zed/sync-watch.sh
```

systemd user unit `~/.config/systemd/user/zedconfig-sync.service`:

```ini
[Unit]
Description=Zed config auto-sync

[Service]
ExecStart=%h/dotfiles-zed/sync-watch.sh
Restart=always

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now zedconfig-sync.service
```

## Notes

- All three watchers debounce (5s) so rapid edits collapse into one commit.
- Each does `pull --rebase` before pushing, so edits on two machines merge instead
  of racing — if you edit the same file on two machines within the debounce
  window, expect an occasional rebase conflict to resolve by hand.
- Nothing here touches Zed's credentials/auth — those live outside this directory.
