<#
.SYNOPSIS
    Builds the LeviLamina Server Manager desktop application.

.DESCRIPTION
    Automates prerequisite validation, dependency installation, and Wails build
    for Windows AMD64 binaries and NSIS installers.

.PARAMETER Target
    Build target: 'nsis' (default installer), 'exe' (standalone binary), or 'dev' (live dev mode).

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Target dev
    .\build.ps1 -Target exe
#>
[CmdletBinding()]
param (
    [ValidateSet('nsis', 'exe', 'dev')]
    [string]$Target = 'nsis'
)

$ErrorActionPreference = 'Stop'

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   LeviLamina Server Manager - PowerShell Builder" -ForegroundColor Cyan
Write-Host "   Maintained by yosifdheef313" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Prerequisite Checks
Write-Host "[1/4] Validating build toolchain..." -ForegroundColor Yellow

function Test-CommandAvailable ($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandAvailable "go")) {
    Write-Error "Go compiler not found in PATH. Install Go 1.21+ from https://go.dev/"
    exit 1
}

if (-not (Test-CommandAvailable "node")) {
    Write-Error "Node.js not found in PATH. Install Node.js 18+ from https://nodejs.org/"
    exit 1
}

if (-not (Test-CommandAvailable "wails")) {
    Write-Warning "Wails v2 CLI not found in PATH. Attempting automatic installation..."
    go install github.com/wailsapp/wails/v2/cmd/wails@latest
    if (-not (Test-CommandAvailable "wails")) {
        Write-Error "Failed to install Wails CLI. Please install manually: go install github.com/wailsapp/wails/v2/cmd/wails@latest"
        exit 1
    }
}

Write-Host " Toolchain validated (Go, Node, Wails CLI ready)." -ForegroundColor Green

# 2. Frontend Dependencies
Write-Host "[2/4] Verifying frontend packages..." -ForegroundColor Yellow
Push-Location frontend
try {
    if (-not (Test-Path "node_modules")) {
        Write-Host " Installing npm packages..."
        npm install
    } else {
        Write-Host " Frontend packages already present."
    }
} finally {
    Pop-Location
}

# 3. Backend Modules
Write-Host "[3/4] Verifying Go modules..." -ForegroundColor Yellow
go mod tidy

# 4. Compilation
Write-Host "[4/4] Executing build for target: $Target..." -ForegroundColor Yellow
switch ($Target) {
    'dev' {
        Write-Host " Launching live development server with hot-reload..." -ForegroundColor Cyan
        wails dev
    }
    'exe' {
        Write-Host " Compiling standalone binary..." -ForegroundColor Cyan
        wails build -platform windows/amd64
    }
    'nsis' {
        Write-Host " Compiling NSIS Windows installer..." -ForegroundColor Cyan
        wails build -platform windows/amd64 -nsis
    }
}

if ($LASTEXITCODE -eq 0 -and $Target -ne 'dev') {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "   Build completed successfully!" -ForegroundColor Green
    Write-Host "   Artifacts written to .\build\bin\" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
}
