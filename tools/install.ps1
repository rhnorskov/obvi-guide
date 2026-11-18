# Installs the newest Obvi Guide from GitHub, before it's released: downloads the repo's zip and puts the addon folders
# in the game's AddOns folder. No git needed. Run it again to update. In PowerShell:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/rhnorskov/obvi-guide/main/tools/install.ps1)))
#
# Options (after the line above, or with  powershell -ExecutionPolicy Bypass -File install.ps1 ...):
#   -Path "D:\Games\World of Warcraft\_forever_\Interface\AddOns"     where to install (found by itself otherwise)
#   -Addons "ObviGuide,ObviGuide_Dungeons"                            which addons (default: the five below)
#   -Branch main                                                      which branch
#   -NoQuestieDB                                                      don't install or update QuestieDB
#
# An addon already in AddOns is replaced, unless it's a link to a checkout (a developer's setup): that one is left as it
# is. Saved settings live in the WTF folder and are kept.
#
# It also installs QuestieDB, the quest database Obvi Guide reads pre-quests and quest XP from: the newest release's
# Forever zip from github.com/Questie/QuestieDB, unless that version is already there.
param(
    [string]$Path,
    [string]$Addons = "ObviGuide,ObviGuide_Dungeons,ObviGuide_Professions,ObviGuide_Extras,ObviGuide_Zygor",
    [string]$Branch = "main",
    [switch]$NoQuestieDB
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is very slow in Windows PowerShell with the bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$names = @($Addons -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# the game's AddOns folder: the one given, or the WoW Forever ones (under _forever_) found in the usual places (asks which when there are several)
if (-not $Path) {
    $bases = @("${env:ProgramFiles(x86)}\World of Warcraft", "$env:ProgramFiles\World of Warcraft") +
        (Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            Join-Path $_.Root "World of Warcraft"
            Join-Path $_.Root "Games\World of Warcraft"
        })
    $found = @($bases | Select-Object -Unique | Where-Object { Test-Path $_ } |
        ForEach-Object { Get-ChildItem $_ -Directory -Filter "_forever_" -ErrorAction SilentlyContinue } |
        ForEach-Object { Join-Path $_.FullName "Interface\AddOns" } | Where-Object { Test-Path $_ })
    if ($found.Count -eq 0) {
        throw "Couldn't find World of Warcraft. Run it again with -Path `"<your game folder>\_forever_\Interface\AddOns`"."
    }
    if ($found.Count -eq 1) {
        $Path = $found[0]
    } else {
        Write-Host "Which game?"
        for ($i = 0; $i -lt $found.Count; $i++) { Write-Host "  $($i + 1)) $($found[$i])" }
        $pick = [int](Read-Host "Number")
        if ($pick -lt 1 -or $pick -gt $found.Count) { throw "No such choice." }
        $Path = $found[$pick - 1]
    }
}
if (-not (Test-Path $Path)) { throw "No such folder: $Path" }

# the zip of the branch, unpacked in a temporary folder (its one top folder is "obvi-guide-<branch>")
$temp = Join-Path ([IO.Path]::GetTempPath()) ("obvi-guide-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory $temp | Out-Null
try {
    $zip = Join-Path $temp "obvi-guide.zip"
    Write-Host "Downloading Obvi Guide ($Branch) from GitHub..."
    Invoke-WebRequest -UseBasicParsing "https://github.com/rhnorskov/obvi-guide/archive/refs/heads/$Branch.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $temp
    $repo = Get-ChildItem $temp -Directory | Select-Object -First 1

    Write-Host "Installing into $Path"
    foreach ($name in $names) {
        $source = Join-Path $repo.FullName $name
        if (-not (Test-Path (Join-Path $source "$name.toc"))) { Write-Warning "$name isn't in the download: skipped"; continue }
        $target = Join-Path $Path $name
        $item = Get-Item $target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) { Write-Host "  $name is linked to a checkout: left as it is"; continue }
        if ($item) { Remove-Item $target -Recurse -Force }             # the version installed before
        Copy-Item $source $target -Recurse
        Write-Host "  $name"
    }

    # QuestieDB
    if (-not $NoQuestieDB) {
        $target = Join-Path $Path "QuestieDB"
        $item = Get-Item $target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) {
            Write-Host "  QuestieDB is linked to a checkout: left as it is"
        } else {
            $release = Invoke-RestMethod "https://api.github.com/repos/Questie/QuestieDB/releases/latest"
            $version = $release.tag_name -replace "^v", ""
            $asset = $release.assets | Where-Object { $_.name -like "QuestieDB-*-Forever.zip" } | Select-Object -First 1
            $toc = Join-Path $target "QuestieDB_Forever.toc"
            $installed = $null
            if ((Test-Path $toc) -and ((Get-Content $toc -TotalCount 40) -join "`n") -match "(?m)^## Version:\s*(\S+)") {
                $installed = $Matches[1]
            }
            if (-not $asset) {
                Write-Warning "QuestieDB $version has no Forever zip: QuestieDB not installed"
            } elseif ($installed -eq $version) {
                Write-Host "  QuestieDB $version (already there)"
            } else {
                Write-Host "  QuestieDB $version, from github.com/Questie/QuestieDB..."
                $dbZip = Join-Path $temp $asset.name
                $dbDir = Join-Path $temp "questiedb"
                Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $dbZip
                Expand-Archive $dbZip -DestinationPath $dbDir      # one top folder, QuestieDB
                $source = Join-Path $dbDir "QuestieDB"
                if (-not (Test-Path (Join-Path $source "QuestieDB_Forever.toc"))) { throw "The QuestieDB zip has no QuestieDB folder." }
                if ($item) { Remove-Item $target -Recurse -Force }
                Copy-Item $source $target -Recurse
            }
        }
    }
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Done. Restart the game (or /reload if it was already running with these addons). Run this again to update."
