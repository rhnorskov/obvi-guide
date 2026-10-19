# Type-check AnyGuide with the Lua language server, as CI does (.github/workflows/check.yml).
# First run fetches Ketho's WoW API annotations into .types/ (git-ignored, not shipped).
# Needs git and lua-language-server on PATH:  winget install LuaLS.lua-language-server
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$commit = "d0b5b51fac4c52c493371b9b18e66ce604ea4326"   # keep in step with check.yml
$types = Join-Path $root ".types/wow-api"

if (-not (Test-Path (Join-Path $types "Annotations/Core"))) {
    git init -q $types
    git -C $types remote add origin https://github.com/Ketho/vscode-wow-api
    git -C $types sparse-checkout set Annotations/Core
    git -C $types fetch -q --depth 1 --filter=blob:none origin $commit
    git -C $types checkout -q FETCH_HEAD
}

lua-language-server --check="$root" --checklevel=Warning --check_format=pretty --logpath="$env:TEMP\anyguide-luals"
exit $LASTEXITCODE
