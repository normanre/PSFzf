param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $false)]
  [bool]$IsPrerelease = $false
)

$ErrorActionPreference = "Stop"

$repoRoot = $env:GITHUB_WORKSPACE
if (-not $repoRoot) { throw "GITHUB_WORKSPACE not set." }

$outDir = Join-Path $repoRoot "out"
$zipPath = Join-Path $outDir ("PSFzf-{0}.zip" -f $Version)

# Versioned module layout: <ModulesRoot>\PSFzf\<Version>\...
$moduleVersionDir = Join-Path $outDir (Join-Path "PSFzf" $Version)
$moduleRootDir = Split-Path -Parent $moduleVersionDir

Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $moduleVersionDir | Out-Null

# Copy only the files needed to run the module
New-Item -ItemType Directory -Force -Path (Join-Path $moduleVersionDir "helpers") | Out-Null
Copy-Item (Join-Path $repoRoot "helpers\*") (Join-Path $moduleVersionDir "helpers") -Recurse -Force

# Module core files
Copy-Item (Join-Path $repoRoot "PSFzf.psd1") $moduleVersionDir -Force
Copy-Item (Join-Path $repoRoot "PSFzf.psm1") $moduleVersionDir -Force -ErrorAction Stop
Copy-Item (Join-Path $repoRoot "PSFzf.dll")  $moduleVersionDir -Force -ErrorAction Stop

# Optional: localized help
$docDir = Join-Path $moduleVersionDir "en-US"
New-Item -ItemType Directory -Force -Path $docDir | Out-Null

Import-Module platyPS -ErrorAction Stop
platyPS\New-ExternalHelp (Join-Path $repoRoot "docs") -Force -OutputPath $docDir

# Keep existing about_*.help.txt if present
if (Test-Path (Join-Path $repoRoot "en-US")) {
  Copy-Item (Join-Path $repoRoot "en-US\*.txt") $docDir -Force -ErrorAction SilentlyContinue
}

# Update manifest version (and prerelease flag if requested)
$psdPath = Join-Path $moduleVersionDir "PSFzf.psd1"
Update-ModuleManifest -Path $psdPath -ModuleVersion $Version

if ($IsPrerelease) {
  $psdText = Get-Content -Raw -Path $psdPath
  # Ensure Prerelease is enabled (uncomment a line like '# Prerelease =')
  $psdText = $psdText -replace "(?m)^\s*#\s*Prerelease\s*=", "  Prerelease ="
  Set-Content -Path $psdPath -Value $psdText -Encoding UTF8
}

# Create zip that contains PSFzf\<Version>\...
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Compress-Archive -Path $moduleRootDir -DestinationPath $zipPath -Force

Write-Host "Created: $zipPath"
