# Writes ObviGuide_Extras/Exploration.lua: a guide per exploration challenge ("Explore Alterac Mountains"), a step per
# area with the spot to go to, from the game's own data tables (DB2) as wago.tools serves them for a build.
#
#   powershell -File tools\exploration.ps1                      # the WoW Forever build below
#   powershell -File tools\exploration.ps1 -Build 1.60.1.70888
#
# How the tables link up: an exploration challenge (Achievement) has a criteria tree whose criteria are of type 43,
# "explore area"; each one's asset is a WorldMapOverlay, the patch of the zone map the area uncovers, with a hit
# rectangle in map pixels (1002 x 668). Many challenges still point at the overlays of the old map art, which no
# UiMap uses any more, so an area is looked up again by its AreaTable id among the overlays of the zone's current
# map (UiMapXMapArt). The spot is the middle of that hit rectangle. The game lists a challenge's areas in an order
# the tables don't keep (their OrderIndex is mostly 0), so a step names its area by its criteria tree id and
# criterion id, and by name.
param(
    [string]$Build = "1.60.1.70888",
    [string]$Out = (Join-Path (Split-Path $PSScriptRoot -Parent) "ObviGuide_Extras\Exploration.lua")
)
$ErrorActionPreference = "Stop"
$inv = [Globalization.CultureInfo]::InvariantCulture

$cache = Join-Path $env:TEMP "obviguide-db2-$Build"
New-Item -ItemType Directory -Force $cache | Out-Null
function Table($name) {
    $file = Join-Path $cache "$name.csv"
    if (-not (Test-Path $file)) {
        Invoke-WebRequest -UseBasicParsing -UserAgent "obvi-guide-tools" -OutFile $file "https://wago.tools/db2/$name/csv?build=$Build"
    }
    Import-Csv $file
}
function ById($rows) { $h = @{}; foreach ($r in $rows) { $h[$r.ID] = $r }; $h }

$achievements = Table "Achievement"
$tree = Table "CriteriaTree"
$criteria = ById (Table "Criteria")
$overlays = Table "WorldMapOverlay"
$overlayById = ById $overlays
$maps = ById (Table "UiMap")
$mapArt = Table "UiMapXMapArt"

$children = @{}
foreach ($t in $tree) { if (-not $children[$t.Parent]) { $children[$t.Parent] = @() }; $children[$t.Parent] += $t }
# the maps (phase 0 first) each map art is shown on
$mapsOfArt = @{}
foreach ($x in ($mapArt | Sort-Object { [int]$_.PhaseID })) {
    if (-not $mapsOfArt[$x.UiMapArtID]) { $mapsOfArt[$x.UiMapArtID] = @() }
    $mapsOfArt[$x.UiMapArtID] += [int]$x.UiMapID
}
# the overlays each area has
$overlaysOfArea = @{}
foreach ($o in $overlays) {
    foreach ($a in @($o.AreaID_0, $o.AreaID_1, $o.AreaID_2, $o.AreaID_3)) {
        if ($a -and $a -ne "0") {
            if (-not $overlaysOfArea[$a]) { $overlaysOfArea[$a] = @() }
            $overlaysOfArea[$a] += $o
        }
    }
}

# the area's overlay on the zone's current map, and that map
function Place($old, $zone) {
    $areaId = $old.AreaID_0
    $candidates = @($old) + @($overlaysOfArea[$areaId] | Where-Object { $_.ID -ne $old.ID })
    $fallback = $null
    foreach ($o in $candidates) {
        foreach ($m in @($mapsOfArt[$o.UiMapArtID])) {
            if (-not $m) { continue }
            if ($maps["$m"].Name_lang -eq $zone) { return @{ overlay = $o; map = $m } }
            if (-not $fallback -and $maps["$m"].Type -eq "3") { $fallback = @{ overlay = $o; map = $m } }
        }
    }
    $fallback
}

function Num($v) { ([math]::Round($v, 1)).ToString("0.0", $inv) }
function Lua($s) { '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"' }

# nearest first, from an end: the area furthest from the middle, then always the closest one not yet visited
function Route($areas) {
    if ($areas.Count -le 2) { return $areas }
    $cx = ($areas | Measure-Object x -Average).Average
    $cy = ($areas | Measure-Object y -Average).Average
    # the map is 3:2, so a step across is worth 1.5 of one down
    function Dist($a, $bx, $by) { [math]::Sqrt([math]::Pow(($a.x - $bx) * 1.5, 2) + [math]::Pow($a.y - $by, 2)) }
    $left = [System.Collections.ArrayList]@($areas)
    $here = $left | Sort-Object { -(Dist $_ $cx $cy) } | Select-Object -First 1
    $route = @()
    while ($left.Count -gt 0) {
        $left.Remove($here)
        $route += $here
        if ($left.Count -eq 0) { break }
        $from = $here
        $here = $left | Sort-Object { Dist $_ $from.x $from.y } | Select-Object -First 1
    }
    # then untangle it (2-opt): turn round any stretch whose ends join up shorter the other way
    $n = $route.Count
    $better = $true
    while ($better) {
        $better = $false
        for ($i = 0; $i -lt $n - 1; $i++) {
            for ($j = $i + 1; $j -lt $n; $j++) {
                # the stretch i..j, between the stop before it and the stop after it (none at the route's ends)
                $before = 0; $after = 0
                if ($i -gt 0) {
                    $before = (Dist $route[$i - 1] $route[$i].x $route[$i].y) - (Dist $route[$i - 1] $route[$j].x $route[$j].y)
                }
                if ($j -lt $n - 1) {
                    $after = (Dist $route[$j + 1] $route[$j].x $route[$j].y) - (Dist $route[$j + 1] $route[$i].x $route[$i].y)
                }
                if ($before + $after -gt 0.01) {
                    [array]::Reverse($route, $i, $j - $i + 1)
                    $better = $true
                }
            }
        }
    }
    $route
}

# the guide list folder: where the challenge is in the game's legacy challenges, "Adventure\Kalimdor"
$categories = ById (Table "Achievement_Category")
function Folder($id) {
    $names = @()
    while ($id -and $id -ne "-1" -and $categories[$id]) {
        $names = @($categories[$id].Name_lang) + $names
        $id = $categories[$id].Parent
    }
    "Legacy Challenges\" + ($names -join "\")
}

$zones = @()
foreach ($a in $achievements) {
    if (-not $a.Criteria_tree -or -not $children[$a.Criteria_tree]) { continue }
    $kids = @($children[$a.Criteria_tree])
    $explore = @($kids | Where-Object { $criteria[$_.CriteriaID] -and $criteria[$_.CriteriaID].Type -eq "43" })
    if ($explore.Count -eq 0 -or $explore.Count -ne $kids.Count) { continue }
    $zone = $a.Title_lang -replace "^Explore\s+", ""

    $areas = @(); $mapCount = @{}
    foreach ($k in $kids) {
        $old = $overlayById[$criteria[$k.CriteriaID].Asset]
        if (-not $old) { Write-Warning "$($a.Title_lang): no map overlay for $($k.Description_lang); left out"; continue }
        $place = Place $old $zone
        if (-not $place) {
            # no current map has it (Undercity, Grim Batol...): the old map art is laid out as the zone's, so its
            # spot on the zone's map
            Write-Warning "$($a.Title_lang): $($k.Description_lang) is on no current map; using the old map's spot"
            $place = @{ overlay = $old; map = $null }
        }
        $o = $place.overlay
        $areas += [pscustomobject]@{
            tree = $k.ID; crit = $k.CriteriaID; name = $k.Description_lang; map = $place.map
            x = ([double]$o.HitRectLeft + [double]$o.HitRectRight) / 2 / 1002 * 100
            y = ([double]$o.HitRectTop + [double]$o.HitRectBottom) / 2 / 668 * 100
        }
        if ($place.map) { $mapCount[$place.map] = 1 + [int]$mapCount[$place.map] }
    }
    if ($areas.Count -eq 0) { continue }
    $main = ($mapCount.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    foreach ($ar in $areas) { if (-not $ar.map) { $ar.map = $main } }
    $zones += [pscustomobject]@{
        id = [int]$a.ID; zone = $zone; faction = [int]$a.Faction
        folder = Folder $a.Category
        map = $main
        areas = Route $areas
    }
}

# the challenges made of other challenges (criteria of type 8, "complete achievement"), all of them ones with a guide
# here: Explore Eastern Kingdoms and Explore Kalimdor (made of zones), Explore Azeroth (made of those two). Each gets
# a guide listing the parts not finished yet, in alphabetical order as the challenge lists them; clicking one opens
# its guide. One with a single part (Explorer: just Explore Azeroth) is left out: its part's guide is the same.
$achievementById = ById $achievements
$guided = @{}; foreach ($z in $zones) { $guided["$($z.id)"] = $true }
$metas = @()
$found = $true
while ($found) {
    $found = $false
    foreach ($a in ($achievements | Sort-Object { [int]$_.ID })) {
        if ($guided[$a.ID] -or -not $a.Criteria_tree -or -not $children[$a.Criteria_tree]) { continue }
        $parts = @(); $ok = $true
        foreach ($k in ($children[$a.Criteria_tree] | Sort-Object Description_lang)) {
            $c = $criteria[$k.CriteriaID]
            if (-not $c -or $c.Type -ne "8" -or -not $guided[$c.Asset]) { $ok = $false; break }
            $parts += [pscustomobject]@{ id = [int]$c.Asset; title = $achievementById[$c.Asset].Title_lang }
        }
        if (-not $ok -or $parts.Count -lt 2) { continue }
        $guided[$a.ID] = $true
        $found = $true
        $metas += [pscustomobject]@{ id = [int]$a.ID; title = $a.Title_lang; folder = Folder $a.Category; parts = $parts }
    }
}

$lines = @(
    "-- AUTO-GENERATED by tools/exploration.ps1 from the game's data (build $Build, via wago.tools). Do not edit by hand."
    "--"
    "-- A guide per exploration challenge, a step per area: the middle of the patch of map the area uncovers, in an"
    "-- order that walks from one to the next nearest. Each area is { name, x, y, criteria tree id, criterion id[, map] }."
    "-- And a guide per challenge made of those (Explore Kalimdor): the parts not finished yet, each opening its guide."
    ""
    "local ZONES = {"
)
foreach ($z in ($zones | Sort-Object folder, zone)) {
    $faction = $(if ($z.faction -eq 0) { "Horde" } elseif ($z.faction -eq 1) { "Alliance" } else { "nil" })
    $lines += "`t{ id = $($z.id), zone = $(Lua $z.zone), folder = $(Lua $z.folder), map = $($z.map), only = $(if ($faction -eq 'nil') { 'nil' } else { Lua $faction }), areas = {"
    foreach ($ar in $z.areas) {
        $other = $(if ($ar.map -ne $z.map) { ", $($ar.map)" } else { "" })
        $lines += "`t`t{ $(Lua $ar.name), $(Num $ar.x), $(Num $ar.y), $($ar.tree), $($ar.crit)$other },"
    }
    $lines += "`t} },"
}
$lines += @(
    "}"
    ""
    "-- the challenges made of the ones above, and their parts: { challenge id, title }"
    "local METAS = {"
)
foreach ($m in $metas) {
    $lines += "`t{ id = $($m.id), title = $(Lua $m.title), folder = $(Lua $m.folder), parts = {"
    foreach ($p in $m.parts) { $lines += "`t`t{ $($p.id), $(Lua $p.title) }," }
    $lines += "`t} },"
}
$lines += @(
    "}"
    ""
    "for _, z in ipairs(ZONES) do"
    "`tObviGuide.Guide(function(g)"
    "`t`tg.title = ""Explore "" .. z.zone"
    "`t`tg.group = z.folder"
    "`t`tg.id    = ""obvi-explore-"" .. z.id"
    "`t`tg.only  = z.only"
    "`t`tg.challenge = z.id"
    "`t`tfor _, a in ipairs(z.areas) do"
    "`t`t`tg:Step(function(s)"
    "`t`t`t`ts:Goto(a[6] or z.map, a[2], a[3])"
    "`t`t`t`ts:Explore(z.id, a[1], { a[4], a[5] })"
    "`t`t`tend)"
    "`t`tend"
    "`tend)"
    "end"
    ""
    "-- one step: the parts still to finish (each line goes once its part is finished), each opening its guide"
    "for _, m in ipairs(METAS) do"
    "`tObviGuide.Guide(function(g)"
    "`t`tg.title = m.title"
    "`t`tg.group = m.folder"
    "`t`tg.id    = ""obvi-explore-"" .. m.id"
    "`t`tg.challenge = m.id"
    "`t`tg:Step(function(s)"
    "`t`t`ts:Say(""Still to finish; click one to open its guide."")"
    "`t`t`tfor _, p in ipairs(m.parts) do s:Challenge(p[1], ""obvi-explore-"" .. p[1], p[2]) end"
    "`t`tend)"
    "`tend)"
    "end"
)
[IO.File]::WriteAllText($Out, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))
Write-Host "Wrote $($zones.Count) zone guides ($(($zones | ForEach-Object { $_.areas.Count } | Measure-Object -Sum).Sum) areas) and $($metas.Count) guides made of them to $Out"
foreach ($m in $metas) { Write-Host "  $($m.folder)\$($m.title): $(($m.parts | ForEach-Object { $_.title }) -join ', ')" }
