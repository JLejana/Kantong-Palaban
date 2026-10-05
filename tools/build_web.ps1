param(
    [string]$GodotExecutable = "godot",
    [switch]$DebugBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$gameDirectory = Join-Path $repositoryRoot "game"
$outputDirectory = Join-Path $repositoryRoot "build\web"
$outputFile = Join-Path $outputDirectory "index.html"
$headersSource = Join-Path $repositoryRoot "hosting\cloudflare\_headers"

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$exportMode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
& $GodotExecutable --headless --path $gameDirectory $exportMode "Web" $outputFile
if ($LASTEXITCODE -ne 0) {
    throw "Godot Web export failed with exit code $LASTEXITCODE. Install the matching Godot export templates and retry."
}

Copy-Item -LiteralPath $headersSource -Destination (Join-Path $outputDirectory "_headers") -Force
$requiredFiles = @("index.html", "index.js", "index.wasm", "index.pck", "_headers")
foreach ($requiredFile in $requiredFiles) {
    $candidate = Join-Path $outputDirectory $requiredFile
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Web export is incomplete: $requiredFile was not generated."
    }
}

Write-Host "Web release ready at $outputDirectory"
Write-Host "Deploy with: npx wrangler pages deploy `"$outputDirectory`" --project-name=bayan-brawl"
