param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Test-RowOccupied {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Y, [int]$AlphaThreshold)
    for ($x = 0; $x -lt $Bitmap.Width; $x++) {
        if ($Bitmap.GetPixel($x, $Y).A -gt $AlphaThreshold) { return $true }
    }
    return $false
}

function Find-TransparentRowSplit {
    param([System.Drawing.Bitmap]$Bitmap, [int]$AlphaThreshold)
    $middle = [int]($Bitmap.Height / 2)
    $candidate = -1
    for ($distance = 0; $distance -lt 96; $distance++) {
        foreach ($y in @(($middle - $distance), ($middle + $distance))) {
            if ($y -gt 0 -and $y -lt $Bitmap.Height -and -not (Test-RowOccupied $Bitmap $y $AlphaThreshold)) {
                $candidate = $y
                break
            }
        }
        if ($candidate -ge 0) { break }
    }
    if ($candidate -lt 0) { throw "No transparent separation was found between the two animation rows." }
    $start = $candidate
    $end = $candidate
    while ($start -gt 0 -and -not (Test-RowOccupied $Bitmap ($start - 1) $AlphaThreshold)) { $start-- }
    while ($end + 1 -lt $Bitmap.Height -and -not (Test-RowOccupied $Bitmap ($end + 1) $AlphaThreshold)) { $end++ }
    return [int](($start + $end) / 2)
}

function Get-HorizontalRuns {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Top,
        [int]$Bottom,
        [int]$AlphaThreshold
    )
    $occupied = New-Object bool[] $Bitmap.Width
    for ($x = 0; $x -lt $Bitmap.Width; $x++) {
        for ($y = $Top; $y -le $Bottom; $y++) {
            if ($Bitmap.GetPixel($x, $y).A -gt $AlphaThreshold) {
                $occupied[$x] = $true
                break
            }
        }
    }
    $runs = [System.Collections.Generic.List[object]]::new()
    $start = -1
    for ($x = 0; $x -le $Bitmap.Width; $x++) {
        $on = $x -lt $Bitmap.Width -and $occupied[$x]
        if ($on -and $start -lt 0) { $start = $x }
        if (-not $on -and $start -ge 0) {
            if ($x - $start -ge 24) { $runs.Add(@($start, ($x - 1))) }
            $start = -1
        }
    }
    if ($runs.Count -ne 4) { throw "Expected four separated poses in a row but found $($runs.Count)." }
    return $runs
}

function Get-AlphaBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Left,
        [int]$Top,
        [int]$Right,
        [int]$Bottom,
        [int]$AlphaThreshold
    )
    $minX = $Right
    $minY = $Bottom
    $maxX = $Left
    $maxY = $Top
    for ($y = $Top; $y -le $Bottom; $y++) {
        for ($x = $Left; $x -le $Right; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -le $AlphaThreshold) { continue }
            $minX = [Math]::Min($minX, $x)
            $minY = [Math]::Min($minY, $y)
            $maxX = [Math]::Max($maxX, $x)
            $maxY = [Math]::Max($maxY, $y)
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) { throw "A pose region did not contain visible pixels." }
    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetFullPath($outputDirectory)) | Out-Null
}

$source = [System.Drawing.Bitmap]::FromFile($resolvedInput)
$target = [System.Drawing.Bitmap]::new(2048, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($target)
try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $alphaThreshold = 8
    $rowSplit = Find-TransparentRowSplit $source $alphaThreshold
    $rowRanges = @(@(0, $rowSplit), @(($rowSplit + 1), ($source.Height - 1)))
    for ($row = 0; $row -lt 2; $row++) {
        $top = $rowRanges[$row][0]
        $bottom = $rowRanges[$row][1]
        $runs = Get-HorizontalRuns $source $top $bottom $alphaThreshold
        for ($column = 0; $column -lt 4; $column++) {
            $bounds = Get-AlphaBounds $source $runs[$column][0] $top $runs[$column][1] $bottom $alphaThreshold
            if ($bounds.Width -gt 472 -or $bounds.Height -gt 472) {
                throw "Pose $($row * 4 + $column + 1) is too large for a safe 512px cell ($($bounds.Width)x$($bounds.Height))."
            }
            $destinationX = $column * 512 + [int]((512 - $bounds.Width) / 2)
            $destinationY = $row * 512 + 480 - $bounds.Height
            if ($destinationY -lt $row * 512) { throw "Pose $($row * 4 + $column + 1) exceeds the cell's top margin." }
            $destination = [System.Drawing.Rectangle]::new($destinationX, $destinationY, $bounds.Width, $bounds.Height)
            $graphics.DrawImage($source, $destination, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
        }
    }
    $absoluteOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $target.Save($absoluteOutput, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Normalized animation sheet: $absoluteOutput"
} finally {
    $graphics.Dispose()
    $target.Dispose()
    $source.Dispose()
}
