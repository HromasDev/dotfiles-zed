# Zed config

Zed settings synced via git. Files at `%APPDATA%\Zed\` are hardlinked/junctioned to this repo:

- `zed/settings.json`, `zed/keymap.json`, `zed/tasks.json` — hardlinks
- `zed/snippets/`, `zed/themes/` — directory junctions

## Setup on a new machine

```powershell
git clone <this-repo> $env:USERPROFILE\dotfiles-zed
$src = "$env:APPDATA\Zed"
$dst = "$env:USERPROFILE\dotfiles-zed\zed"
Remove-Item "$src\settings.json","$src\keymap.json","$src\tasks.json" -ErrorAction SilentlyContinue
Remove-Item "$src\snippets","$src\themes" -Recurse -ErrorAction SilentlyContinue
cmd /c mklink /H "$src\settings.json" "$dst\settings.json"
cmd /c mklink /H "$src\keymap.json" "$dst\keymap.json"
cmd /c mklink /H "$src\tasks.json" "$dst\tasks.json"
cmd /c mklink /J "$src\snippets" "$dst\snippets"
cmd /c mklink /J "$src\themes" "$dst\themes"
```
