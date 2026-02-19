# ---------------------------------------------------------------------------
# setup.ps1 -- Bootstrap Vulkan dev environment on Windows
# Usage:  powershell -ExecutionPolicy Bypass -File setup.ps1
# ---------------------------------------------------------------------------
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Helpers -----------------------------------------------------------------
function Write-Info  { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[!!] $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "[XX] $Msg" -ForegroundColor Red; exit 1 }

# Helper: refresh PATH from registry (picks up installs done during this session)
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# -- Require Windows ---------------------------------------------------------
if ($env:OS -ne "Windows_NT") {
    Write-Err "This script is for Windows only. Use setup.sh on macOS."
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Vulkan Renderer -- Windows Setup"      -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# -- 1. Check for Vulkan SDK ------------------------------------------------
Write-Host "-- Checking Vulkan SDK -----------------------------------------------"

$vulkanSdk = $env:VULKAN_SDK

if (-not $vulkanSdk) {
    # Try auto-detect from the default install location
    $sdkCandidates = Get-ChildItem "C:\VulkanSDK" -Directory -ErrorAction SilentlyContinue |
                     Sort-Object Name |
                     Select-Object -Last 1
    if ($sdkCandidates) {
        $vulkanSdk = $sdkCandidates.FullName
        Write-Warn "VULKAN_SDK not set, but found SDK at: $vulkanSdk"
    }
}

if ($vulkanSdk -and (Test-Path (Join-Path $vulkanSdk "Include\vulkan\vulkan.h"))) {
    Write-Info "Vulkan SDK found: $vulkanSdk"
} else {
    Write-Host ""
    Write-Warn "Vulkan SDK not found!"
    Write-Host ""
    Write-Host "  The LunarG Vulkan SDK is REQUIRED. It provides:" -ForegroundColor Yellow
    Write-Host "    - Vulkan headers and loader (vulkan-1.lib)"
    Write-Host "    - Validation layers"
    Write-Host "    - glslc shader compiler"
    Write-Host "    - vulkaninfo diagnostic tool"
    Write-Host ""
    Write-Host "  Download from: https://vulkan.lunarg.com/sdk/home" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  After installation, re-run this script." -ForegroundColor Yellow
    Write-Host ""

    $openBrowser = Read-Host "Open the download page in your browser now? [Y/n]"
    if ($openBrowser -eq "" -or $openBrowser -match "^[Yy]") {
        Start-Process "https://vulkan.lunarg.com/sdk/home#windows"
    }

    Write-Err "Setup cannot continue without the Vulkan SDK."
}

# -- 2. Check for CMake -----------------------------------------------------
Write-Host ""
Write-Host "-- Checking CMake ----------------------------------------------------"

# Also look in common install locations that might not be on PATH yet
$cmakeSearchPaths = @(
    "C:\Program Files\CMake\bin\cmake.exe",
    "C:\Program Files (x86)\CMake\bin\cmake.exe",
    "${env:ProgramFiles}\CMake\bin\cmake.exe"
)

$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake) {
    # Check common install paths
    foreach ($p in $cmakeSearchPaths) {
        if (Test-Path $p) {
            $cmakeDir = Split-Path $p -Parent
            $env:Path = "$env:Path;$cmakeDir"
            $cmake = Get-Command cmake -ErrorAction SilentlyContinue
            if ($cmake) {
                Write-Warn "CMake found at $cmakeDir but it is not in your PATH."
                $addCmakePath = Read-Host "Add CMake to your user PATH permanently? [Y/n]"
                if ($addCmakePath -eq "" -or $addCmakePath -match "^[Yy]") {
                    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
                    if ($currentPath -notlike "*$cmakeDir*") {
                        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$cmakeDir", "User")
                        Write-Info "Added $cmakeDir to user PATH"
                    }
                }
                break
            }
        }
    }
}

if ($cmake) {
    $cmakeVer = & cmake --version | Select-Object -First 1
    Write-Info "CMake found: $cmakeVer"
} else {
    Write-Warn "CMake not found in PATH or common install locations."
    Write-Host ""
    Write-Host "  CMake is required to build the project." -ForegroundColor Yellow
    Write-Host "  Install options:"
    Write-Host "    1. Download from https://cmake.org/download/"
    Write-Host '    2. winget install Kitware.CMake'
    Write-Host "    3. Visual Studio Installer -> Individual Components -> CMake"
    Write-Host ""

    $installChoice = Read-Host "Install CMake via winget now? [Y/n]"
    if ($installChoice -eq "" -or $installChoice -match "^[Yy]") {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Warn "Installing CMake via winget..."
            & winget install Kitware.CMake --accept-package-agreements --accept-source-agreements
            Refresh-Path
            $cmake = Get-Command cmake -ErrorAction SilentlyContinue
            if ($cmake) {
                Write-Info "CMake installed successfully"
            } else {
                Write-Warn "CMake installed but not yet on PATH. You may need to restart your terminal."
            }
        } else {
            Write-Err "winget not available. Please install CMake manually."
        }
    } else {
        Write-Err "CMake is required. Please install it and re-run."
    }
}

# -- 3. Check for a C++ compiler (MSVC or MinGW) ----------------------------
Write-Host ""
Write-Host "-- Checking C++ compiler ---------------------------------------------"

$hasCompiler = $false
$compilerName = ""

# Check for MSVC (cl.exe) -- may not be on PATH unless in Developer Command Prompt
$cl = Get-Command cl -ErrorAction SilentlyContinue
if ($cl) {
    $hasCompiler = $true
    $compilerName = "MSVC (cl.exe)"
}

# Check for GCC/MinGW
if (-not $hasCompiler) {
    $gcc = Get-Command g++ -ErrorAction SilentlyContinue
    if ($gcc) {
        $hasCompiler = $true
        $compilerName = "MinGW (g++)"
    }
}

# Check for Clang
if (-not $hasCompiler) {
    $clang = Get-Command clang++ -ErrorAction SilentlyContinue
    if ($clang) {
        $hasCompiler = $true
        $compilerName = "Clang (clang++)"
    }
}

if ($hasCompiler) {
    Write-Info "C++ compiler found: $compilerName"
} else {
    Write-Warn "No C++ compiler detected on PATH."
    Write-Host ""
    Write-Host "  You need one of:" -ForegroundColor Yellow
    Write-Host "    - Visual Studio 2022 with 'Desktop development with C++' workload (recommended)"
    Write-Host "    - Visual Studio Build Tools (lighter alternative)"
    Write-Host "    - MinGW-w64 / MSYS2"
    Write-Host ""
    Write-Host "  Note: cl.exe may not appear in PATH outside a Developer Command Prompt."
    Write-Host "        If you have Visual Studio installed, this is likely fine -- CMake will find it."
    Write-Host ""
}

# -- 4. Verify critical tools from the Vulkan SDK ---------------------------
Write-Host ""
Write-Host "-- Verification ------------------------------------------------------"

# glslc
$glslc = Get-Command glslc -ErrorAction SilentlyContinue
if (-not $glslc -and $vulkanSdk) {
    $glslcPath = Join-Path $vulkanSdk "Bin\glslc.exe"
    if (Test-Path $glslcPath) {
        $glslc = $glslcPath
    }
}

if ($glslc) {
    Write-Info "glslc found (shader compiler)"
} else {
    Write-Warn "glslc not found -- make sure the Vulkan SDK Bin/ is in your PATH"
}

# vulkaninfo
$vulkaninfo = Get-Command vulkaninfo -ErrorAction SilentlyContinue
if (-not $vulkaninfo -and $vulkanSdk) {
    $vulkaninfoPath = Join-Path $vulkanSdk "Bin\vulkaninfo.exe"
    if (Test-Path $vulkaninfoPath) {
        $vulkaninfo = $vulkaninfoPath
    }
}

if ($vulkaninfo) {
    Write-Info "vulkaninfo found"
} else {
    Write-Warn "vulkaninfo not found -- check that the Vulkan SDK Bin/ is in your PATH"
}

# -- 5. Environment variable check ------------------------------------------
Write-Host ""
Write-Host "-- Environment Variables ---------------------------------------------"

$systemVulkanSdk = [System.Environment]::GetEnvironmentVariable("VULKAN_SDK", "User")
if (-not $systemVulkanSdk) {
    $systemVulkanSdk = [System.Environment]::GetEnvironmentVariable("VULKAN_SDK", "Machine")
}

if ($systemVulkanSdk) {
    Write-Info "VULKAN_SDK is set system-wide: $systemVulkanSdk"
} else {
    Write-Warn "VULKAN_SDK is not set as a persistent environment variable."
    Write-Host ""
    Write-Host "  The LunarG installer usually sets this automatically."
    Write-Host "  If CMake cannot find Vulkan, set it manually:"
    Write-Host ""
    Write-Host "    [System.Environment]::SetEnvironmentVariable('VULKAN_SDK', '$vulkanSdk', 'User')" -ForegroundColor Cyan
    Write-Host ""

    $setEnv = Read-Host "Set VULKAN_SDK for your user account now? [Y/n]"
    if ($setEnv -eq "" -or $setEnv -match "^[Yy]") {
        [System.Environment]::SetEnvironmentVariable("VULKAN_SDK", $vulkanSdk, "User")
        $env:VULKAN_SDK = $vulkanSdk
        Write-Info "VULKAN_SDK set to: $vulkanSdk"
    } else {
        Write-Warn "Skipped. CMake may still auto-detect from C:\VulkanSDK."
    }
}

# Check if Vulkan SDK Bin is in PATH
$sdkBin = Join-Path $vulkanSdk "Bin"
$pathEntries = $env:Path -split ";"
$sdkBinInPath = $pathEntries | Where-Object { $_ -eq $sdkBin }
if ($sdkBinInPath) {
    Write-Info "Vulkan SDK Bin/ is in PATH"
} else {
    Write-Warn "Vulkan SDK Bin/ is not in PATH: $sdkBin"
    Write-Host "  Consider adding it so glslc and vulkaninfo are available globally."
    Write-Host ""

    $addPath = Read-Host "Add Vulkan SDK Bin/ to your user PATH now? [Y/n]"
    if ($addPath -eq "" -or $addPath -match "^[Yy]") {
        $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$sdkBin*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$sdkBin", "User")
            $env:Path = "$env:Path;$sdkBin"
            Write-Info "Added $sdkBin to user PATH"
        } else {
            Write-Info "Already in user PATH"
        }
    }
}

# -- 6. Build instructions ---------------------------------------------------
Write-Host ""
Write-Host "-- Build Instructions ------------------------------------------------"
Write-Host ""
Write-Host "  Option A -- Visual Studio generator (recommended):" -ForegroundColor Cyan
Write-Host "    cmake -B build"
Write-Host "    cmake --build build --config Debug"
Write-Host "    .\build\Debug\vulkan_renderer.exe"
Write-Host ""
Write-Host "  Option B -- Ninja (if installed):" -ForegroundColor Cyan
Write-Host "    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug"
Write-Host "    cmake --build build"
Write-Host "    .\build\vulkan_renderer.exe"
Write-Host ""
Write-Host "  Option C -- Using CMake presets:" -ForegroundColor Cyan
Write-Host "    cmake --preset debug"
Write-Host "    cmake --build --preset debug"
Write-Host ""
Write-Info "Setup complete!"
Write-Host ""
