# CLAUDE.md

Zed editor config, synced via git and kept in sync with the live install through an auto-sync watcher (not symlinks — see below for why).

## Layout

- `zed/settings.json`, `zed/keymap.json`, `zed/tasks.json` — mirror `%APPDATA%\Zed\{settings,keymap,tasks}.json`
- `zed/snippets/`, `zed/themes/` — mirror the matching folders under `%APPDATA%\Zed\`
- This repo nests its actual config content one level down in `zed/` (alongside this file, `README.md`, etc. at the repo root) — when writing tooling that reads this repo as a submodule, the item root is `<submodule>/zed/`, not the submodule root itself. This has bitten `dotfiles/bootstrap.ps1` once already (`SubPath` field exists specifically to handle it).

## Sync mechanism

The watcher script now lives centrally at `dotfiles/scripts/watch-sync.ps1` (shared across all watched components), not in this repo. This repo's own copy was deleted deliberately — don't recreate a per-repo `sync-watch.ps1` here.

- No symlinks: this Windows account has neither Developer Mode nor admin rights, so real symlinks aren't available, and Zed hardcodes its config path (`%APPDATA%\Zed`) so it can't be pointed at this repo directly either. The watcher copies files both ways instead: live → repo on local edit, repo → live after a `git pull` brings in changes from elsewhere.
- Hardlinks were tried first and rejected: `git checkout`/`pull` replace a file via atomic rename, which silently detaches a hardlink from its pair — the two copies then drift with no error. Don't reintroduce that approach.
- Debounce is 5 minutes by default (raised from an initial 5 seconds, which produced a commit almost every keystroke-pause).

## Safety

- Confirm with the user before any manual `git push` from an agent's own Bash calls — this is a global rule (`~/.claude/settings.json`). The watcher process itself pushes autonomously by design; that's expected and not something to second-guess.
- This repo is **public** — never let real credentials, API keys, or personal paths leak into `settings.json`/`keymap.json`. If something sensitive shows up here it needs `git-history-rewrite`, not just a new commit removing it.
