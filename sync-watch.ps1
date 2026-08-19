# Watches the live Zed config folder and mirrors changes into the git repo,
# then commits/pushes. After a pull picks up changes from another machine,
# mirrors the repo back onto the live config so Zed sees updates too.
# Windows lacks a native "run task on file change" trigger and this account
# has no symlink/Task Scheduler privilege, so a lightweight always-on watcher
# process (near-zero CPU/RAM while idle) is used instead of hardlinks.

$ErrorActionPreference = "SilentlyContinue"
$global:repo = "$env:USERPROFILE\dotfiles-zed"
$global:liveDir = "$env:APPDATA\Zed"
$global:repoDir = "$global:repo\zed"
$debounceMs = 5000

$global:items = @("settings.json", "keymap.json", "tasks.json", "snippets", "themes")

function Mirror-LiveToRepo {
    foreach ($item in $global:items) {
        $src = Join-Path $global:liveDir $item
        $dst = Join-Path $global:repoDir $item
        if (Test-Path $src) {
            if ((Get-Item $src) -is [System.IO.DirectoryInfo]) {
                robocopy $src $dst /MIR /NFL /NDL /NJH /NJS | Out-Null
            } else {
                Copy-Item -Path $src -Destination $dst -Force
            }
        }
    }
}

function Mirror-RepoToLive {
    foreach ($item in $global:items) {
        $src = Join-Path $global:repoDir $item
        $dst = Join-Path $global:liveDir $item
        if (Test-Path $src) {
            if ((Get-Item $src) -is [System.IO.DirectoryInfo]) {
                robocopy $src $dst /MIR /NFL /NDL /NJH /NJS | Out-Null
            } else {
                Copy-Item -Path $src -Destination $dst -Force
            }
        }
    }
}

$global:timer = New-Object Timers.Timer
$global:timer.Interval = $debounceMs
$global:timer.AutoReset = $false

$syncAction = {
    Set-Location $global:repo
    Mirror-LiveToRepo

    git add -A | Out-Null
    $status = git status --porcelain
    if ($status) {
        git commit -m "sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-Null
    }

    $before = git rev-parse HEAD
    git pull --rebase --quiet 2>$null | Out-Null
    $after = git rev-parse HEAD
    if ($before -ne $after) {
        Mirror-RepoToLive
    }

    git push --quiet 2>$null | Out-Null
}

Register-ObjectEvent -InputObject $global:timer -EventName Elapsed -Action $syncAction | Out-Null

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $global:liveDir
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, FileName, DirectoryName'
$watcher.EnableRaisingEvents = $true

$onChange = {
    $global:timer.Stop()
    $global:timer.Start()
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $onChange | Out-Null

# Also run once at startup to catch changes made while this wasn't running,
# and to pull down anything pushed from another machine.
& $syncAction

while ($true) { Start-Sleep -Seconds 3600 }
