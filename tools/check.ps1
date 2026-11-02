# Type-check every addon in the repo with the Lua language server.
# First run fetches Ketho's WoW API annotations into .types/ (git-ignored, not shipped), shared by all addons.
# Needs git and lua-language-server on PATH:  winget install LuaLS.lua-language-server
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$commit = "d0b5b51fac4c52c493371b9b18e66ce604ea4326"
$types = Join-Path $root ".types/wow-api"

if (-not (Test-Path (Join-Path $types "Annotations/Core"))) {
    git init -q $types
    git -C $types remote add origin https://github.com/Ketho/vscode-wow-api
    git -C $types sparse-checkout set Annotations/Core
    git -C $types fetch -q --depth 1 --filter=blob:none origin $commit
    git -C $types checkout -q FETCH_HEAD
}

# every folder with a TOC of its own name is an addon
$failed = 0
foreach ($addon in Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).toc") }) {
    Write-Host "== $($addon.Name)"
    lua-language-server --check="$($addon.FullName)" --checklevel=Warning --check_format=pretty --logpath="$env:TEMP\obviguide-luals"
    if ($LASTEXITCODE -ne 0) { $failed++ }
}
exit $failed
