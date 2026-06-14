<#
.SYNOPSIS
  kena-skills installer for Windows (PowerShell wrapper)

.DESCRIPTION
  Detects the best available bash runtime on Windows:
  1. Git Bash (bash.exe in PATH) — preferred
  2. WSL (wsl.exe in PATH) — fallback
  3. None found — clear error with install instructions

  Then delegates to installer/install.sh which is the same script
  used on Linux and macOS.

.EXAMPLE
  PS> .\installer\install.ps1
  PS> iex (irm https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.ps1)
#>

[CmdletBinding()]
param(
  [string]$InstallDir = "$env:LOCALAPPDATA\kena-skills",
  [string]$BinDir = "$env:LOCALAPPDATA\kena-skills\bin",
  [string]$RepoUrl = "https://github.com/KenaBot/kena-skills.git",
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

# ---- Help ----
if ($Help) {
  @"
kena-skills installer (Windows PowerShell wrapper)

Usage:
  .\installer\install.ps1                    # Install to default location
  .\installer\install.ps1 -InstallDir C:\k   # Custom install dir
  .\installer\install.ps1 -Help              # Show this help

Environment variables (override defaults):
  KENA_SKILLS_INSTALL_DIR  Default: `$env:LOCALAPPDATA\kena-skills
  KENA_SKILLS_BIN_DIR      Default: `$env:LOCALAPPDATA\kena-skills\bin
  KENA_SKILLS_REPO         Default: https://github.com/KenaBot/kena-skills.git

Runtime detection (in order):
  1. Git Bash (bash.exe)   — required for full kena-skills functionality
  2. WSL (wsl.exe)         — Linux compatibility layer
  3. Error                 — clear install instructions

Without Git Bash or WSL, kena-skills cannot install (it is bash-based).
Install one of:
  - Git for Windows:    https://git-scm.com/download/win
  - WSL:                wsl --install  (in admin PowerShell)
"@
  exit 0
}

# ---- Env var overrides ----
if ($env:KENA_SKILLS_INSTALL_DIR) { $InstallDir = $env:KENA_SKILLS_INSTALL_DIR }
if ($env:KENA_SKILLS_BIN_DIR)     { $BinDir = $env:KENA_SKILLS_BIN_DIR }
if ($env:KENA_SKILLS_REPO)        { $RepoUrl = $env:KENA_SKILLS_REPO }

# ---- Detect bash runtime ----
function Find-BashRuntime {
  # 1. Git Bash
  $bash = Get-Command bash.exe -ErrorAction SilentlyContinue
  if ($bash) {
    return @{
      Type = 'git-bash'
      Path = $bash.Source
      ShellArgs = @('-c')
    }
  }
  # 2. WSL
  $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
  if ($wsl) {
    return @{
      Type = 'wsl'
      Path = $wsl.Source
      ShellArgs = @('bash', '-c')
    }
  }
  return $null
}

function ConvertTo-WindowsPath {
  param([string]$Path)
  # Use Git Bash's cygpath if available, otherwise replace /c/... with C:\...
  $cygpath = Get-Command cygpath.exe -ErrorAction SilentlyContinue
  if ($cygpath) {
    return (& cygpath.exe -w $Path)
  }
  if ($Path -match '^/([a-zA-Z])/(.*)$') {
    $drive = $Matches[1].ToUpper()
    $rest = $Matches[2] -replace '/', '\'
    return "${drive}:\$rest"
  }
  return $Path
}

function ConvertTo-BashPath {
  param([string]$Path)
  $cygpath = Get-Command cygpath.exe -ErrorAction SilentlyContinue
  if ($cygpath) {
    return (& cygpath.exe -u $Path)
  }
  if ($Path -match '^([A-Z]):\\(.*)$') {
    $drive = $Matches[1].ToLower()
    $rest = $Matches[2] -replace '\\', '/'
    return "/$drive/$rest"
  }
  return $Path
}

# ---- Main ----
Write-Host ""
Write-Host "==> kena-skills Windows installer" -ForegroundColor Cyan
Write-Host ""

$runtime = Find-BashRuntime
if (-not $runtime) {
  Write-Host "✗ No bash runtime found on this system." -ForegroundColor Red
  Write-Host ""
  Write-Host "kena-skills is a bash-based installer and requires either:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  1. Git for Windows (bash.exe):  https://git-scm.com/download/win" -ForegroundColor White
  Write-Host "  2. WSL (wsl.exe):               wsl --install" -ForegroundColor White
  Write-Host ""
  Write-Host "After installing one of these, re-run this script." -ForegroundColor Yellow
  exit 1
}

Write-Host "✓ Detected runtime: $($runtime.Type) at $($runtime.Path)" -ForegroundColor Green
Write-Host ""

# Convert Windows paths to bash paths (Git Bash uses /c/...; WSL uses /mnt/c/...)
$installDirBash = ConvertTo-BashPath $InstallDir
$binDirBash = ConvertTo-BashPath $BinDir

# Build the bash invocation that runs the standard install.sh
# We pipe install.sh through stdin OR download from RAW_URL if not local
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$localInstallSh = Join-Path $scriptDir 'install.sh'

if (Test-Path $localInstallSh) {
  Write-Host "==> Running local installer: $localInstallSh" -ForegroundColor Cyan
  $installShBash = ConvertTo-BashPath $localInstallSh
  $bashCmd = "INSTALL_DIR='$installDirBash' BIN_DIR='$binDirBash' KENA_SKILLS_REPO='$RepoUrl' bash '$installShBash'"
} else {
  $rawUrl = "https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.sh"
  Write-Host "==> Downloading installer from: $rawUrl" -ForegroundColor Cyan
  $bashCmd = "INSTALL_DIR='$installDirBash' BIN_DIR='$binDirBash' KENA_SKILLS_REPO='$RepoUrl' curl -fsSL '$rawUrl' | bash"
}

Write-Host "==> Bash command:" -ForegroundColor Cyan
Write-Host "    $bashCmd" -ForegroundColor DarkGray
Write-Host ""

try {
  if ($runtime.Type -eq 'git-bash') {
    & $runtime.Path @($runtime.ShellArgs[0]) $bashCmd
  } elseif ($runtime.Type -eq 'wsl') {
    # WSL: run inside default distro
    & $runtime.Path @($runtime.ShellArgs[0]) $runtime.ShellArgs[1] $bashCmd
  }
  $exitCode = $LASTEXITCODE
} catch {
  Write-Host "✗ Installation failed: $_" -ForegroundColor Red
  exit 1
}

if ($exitCode -eq 0) {
  Write-Host ""
  Write-Host "✓ kena-skills installed successfully." -ForegroundColor Green
  Write-Host ""
  Write-Host "Add to your PATH (PowerShell, current user):" -ForegroundColor Cyan
  Write-Host "  `$env:Path = '$BinDir;' + `$env:Path" -ForegroundColor White
  Write-Host ""
  Write-Host "To make it permanent:" -ForegroundColor Cyan
  Write-Host "  [Environment]::SetEnvironmentVariable('Path', '$BinDir;' + [Environment]::GetEnvironmentVariable('Path', 'User'), 'User')" -ForegroundColor White
  Write-Host ""
  Write-Host "Then run:" -ForegroundColor Cyan
  Write-Host "  kena-skills --list" -ForegroundColor White
  Write-Host "  kena-skills --help" -ForegroundColor White
  Write-Host ""
} else {
  Write-Host "✗ Installer exited with code $exitCode" -ForegroundColor Red
  exit $exitCode
}
