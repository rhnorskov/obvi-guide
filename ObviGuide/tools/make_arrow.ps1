# Makes Obvi Guide's waypoint arrow from the minimap's quest arrow (Interface\Minimap\MiniMap-QuestArrow, 32x32):
# its pixels (tools\questarrow.txt, one row of RGBA hex per line, rows 4-26; the rest is empty) blown up 4x with
# plain blocks; the game smooths them when it draws the arrow smaller. Writes a 32-bit TGA and a PNG preview.
#   powershell -File tools\make_arrow.ps1 -Tga Art\Arrow.tga -Png preview.png
param([string]$Tga, [string]$Png, [string]$Preview)
Add-Type -AssemblyName System.Drawing

$N = 32
$rows = Get-Content (Join-Path $PSScriptRoot "questarrow.txt") | Where-Object { $_ }
# pixels as [r,g,b,a] in a flat array, row by row
$px = New-Object 'object[]' ($N * $N)
for ($i = 0; $i -lt $px.Length; $i++) { $px[$i] = [int[]]@(0, 0, 0, 0) }
for ($r = 0; $r -lt $rows.Count; $r++) {
	$line = $rows[$r]
	for ($c = 0; $c -lt $N; $c++) {
		$o = $c * 8
		$px[(4 + $r) * $N + $c] = [int[]]@([Convert]::ToInt32($line.Substring($o, 2), 16), [Convert]::ToInt32($line.Substring($o + 2, 2), 16),
			[Convert]::ToInt32($line.Substring($o + 4, 2), 16), [Convert]::ToInt32($line.Substring($o + 6, 2), 16))
	}
}

function ToBitmap($arr, $n) {
	$bmp = New-Object System.Drawing.Bitmap $n, $n, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	for ($y = 0; $y -lt $n; $y++) { for ($x = 0; $x -lt $n; $x++) {
		$q = $arr[$y * $n + $x]
		$bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($q[3], $q[0], $q[1], $q[2]))
	} }
	$bmp
}

# plain 4x blocks
$S = 4 * $N
$orig0 = ToBitmap $px $N
$bmp = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gb = [System.Drawing.Graphics]::FromImage($bmp)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$gb.DrawImage($orig0, 0, 0, $S, $S)
$gb.Dispose()

# a preview of how the game would draw it (smoothed down from the 128 blocks) at 56, 72 and 96 px
if ($Preview) {
	$pv = New-Object System.Drawing.Bitmap 300, 120
	$g = [System.Drawing.Graphics]::FromImage($pv)
	$g.Clear([System.Drawing.Color]::FromArgb(255, 40, 44, 40))
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.DrawImage($bmp, 10, 32, 56, 56)
	$g.DrawImage($bmp, 86, 24, 72, 72)
	$g.DrawImage($bmp, 178, 12, 96, 96)
	$g.Dispose()
	$pv.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)
}

if ($Png) { $bmp.Save($Png, [System.Drawing.Imaging.ImageFormat]::Png) }

# TGA: uncompressed true colour, 32 bits, origin top left (descriptor 0x28: 8 alpha bits + top-left)
if ($Tga) {
	$out = New-Object System.IO.MemoryStream
	$header = [byte[]]@(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, ($S -band 255), ($S -shr 8), ($S -band 255), ($S -shr 8), 32, 0x28)
	$out.Write($header, 0, $header.Length)
	$rect = New-Object System.Drawing.Rectangle 0, 0, $S, $S
	$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $bmp.PixelFormat)
	$bytes = New-Object byte[] ($data.Stride * $S)
	[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
	$bmp.UnlockBits($data)
	$out.Write($bytes, 0, $bytes.Length)   # GDI+ keeps BGRA order, as TGA wants
	[System.IO.File]::WriteAllBytes($Tga, $out.ToArray())
}
$bmp.Dispose()
"ok"
