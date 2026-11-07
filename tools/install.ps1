# Installs the newest Obvi Guide from GitHub, before it's released: downloads the repo's zip and puts the addon folders
# in the game's AddOns folder. No git needed. Run it again to update. In PowerShell:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/rhnorskov/obvi-guide/main/tools/install.ps1)))
#
# Options (after the line above, or with  powershell -ExecutionPolicy Bypass -File install.ps1 ...):
#   -Path "D:\Games\World of Warcraft\_forever_\Interface\AddOns"     where to install (found by itself otherwise)
#   -Addons "ObviGuide,ObviGuide_Dungeons"                            which addons (default: the four below)
#   -Branch main                                                      which branch
#
# An addon already in AddOns is replaced. One that is a link (a developer's checkout) only loses the link; the
# checkout it points at is left alone. Saved settings live in the WTF folder and are kept.
param(
    [string]$Path,
    [string]$Addons = "ObviGuide,ObviGuide_Dungeons,ObviGuide_Professions,ObviGuide_Extras",
    [string]$Branch = "main"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is very slow in Windows PowerShell with the bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$names = @($Addons -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# the game's AddOns folder: the one given, or the ones found in the usual places (asks which when there are several)
if (-not $Path) {
    $bases = @("${env:ProgramFiles(x86)}\World of Warcraft", "$env:ProgramFiles\World of Warcraft") +
        (Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            Join-Path $_.Root "World of Warcraft"
            Join-Path $_.Root "Games\World of Warcraft"
        })
    $found = @($bases | Select-Object -Unique | Where-Object { Test-Path $_ } |
        ForEach-Object { Get-ChildItem $_ -Directory -Filter "_*_" -ErrorAction SilentlyContinue } |
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
        if ($item -and $item.LinkType) { $item.Delete() }              # only the link, not what it points at
        elseif ($item) { Remove-Item $target -Recurse -Force }         # the version installed before
        Copy-Item $source $target -Recurse
        Write-Host "  $name"
    }
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Done. Restart the game (or /reload if it was already running with these addons). Run this again to update."
