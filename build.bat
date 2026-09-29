@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo    LeviLamina Server Manager - Build Script
echo    Maintained by yosifdheef313
echo =======================================================
echo.

:: Check prerequisites
where go >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Go compiler not found in PATH. Please install Go 1.21+ from https://go.dev/
    exit /b 1
)

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found in PATH. Please install Node.js 18+ from https://nodejs.org/
    exit /b 1
)

where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] npm not found in PATH.
    exit /b 1
)

where wails >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] Wails v2 CLI not found in PATH.
    echo Attempting to install Wails CLI via Go...
    go install github.com/wailsapp/wails/v2/cmd/wails@latest
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to install Wails CLI. Please install it manually:
        echo go install github.com/wailsapp/wails/v2/cmd/wails@latest
        exit /b 1
    )
)

:: Install frontend dependencies
echo [1/3] Checking frontend dependencies...
cd frontend
if not exist node_modules (
    echo Installing node dependencies...
    call npm install
) else (
    echo Node dependencies up to date.
)
cd ..

:: Tidy backend Go modules
echo [2/3] Verifying backend Go dependencies...
go mod tidy
if %errorlevel% neq 0 (
    echo [ERROR] go mod tidy failed.
    exit /b 1
)

:: Build options
set BUILD_TARGET=%1
if "%BUILD_TARGET%"=="" set BUILD_TARGET=nsis

echo [3/3] Compiling application (Target: %BUILD_TARGET%)...
if /i "%BUILD_TARGET%"=="nsis" (
    echo Building NSIS Windows Installer...
    wails build -platform windows/amd64 -nsis
) else if /i "%BUILD_TARGET%"=="dev" (
    echo Starting live development environment...
    wails dev
    exit /b 0
) else (
    echo Building standalone Windows AMD64 executable...
    wails build -platform windows/amd64
)

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed! Check compiler output above.
    exit /b %errorlevel%
)

echo.
echo =======================================================
echo    Build Succeeded!
echo    Outputs are located in: build\bin\
echo =======================================================
exit /b 0
