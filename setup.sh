#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup.sh — Bootstrap Vulkan dev environment on macOS via Homebrew
# Usage:  chmod +x setup.sh && ./setup.sh
# ---------------------------------------------------------------------------
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ── Require macOS ──────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is for macOS only. On Windows, run:  powershell -ExecutionPolicy Bypass -File setup.ps1"
fi

# ── Require Homebrew ───────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    error "Homebrew not found. Install it: https://brew.sh"
fi

info "Homebrew found at $(brew --prefix)"

# ── Install dependencies ──────────────────────────────────────────────────
DEPS=(
    molten-vk                   # MoltenVK — Vulkan → Metal translation layer
    vulkan-headers              # Vulkan C headers
    vulkan-loader               # libvulkan (ICD loader)
    vulkan-tools                # vkcube, vulkaninfo
    vulkan-validationlayers     # VK_LAYER_KHRONOS_validation
    glfw                        # Windowing / input
    glm                         # Math library (header-only)
    glslang                     # Reference GLSL compiler (includes glslangValidator)
    shaderc                     # Google's glslc shader compiler
)

echo ""
echo "The following packages will be installed/upgraded:"
printf '  • %s\n' "${DEPS[@]}"
echo ""

for dep in "${DEPS[@]}"; do
    if brew list --formula "$dep" &>/dev/null; then
        info "$dep is already installed"
    else
        warn "Installing $dep …"
        brew install "$dep"
        info "$dep installed"
    fi
done

# ── Verify critical tools ─────────────────────────────────────────────────
echo ""
echo "── Verification ──────────────────────────────────────────────"

if command -v vulkaninfo &>/dev/null; then
    info "vulkaninfo found"
else
    warn "vulkaninfo not in PATH — you may need to add Vulkan SDK to PATH"
fi

if command -v glslc &>/dev/null; then
    info "glslc found ($(glslc --version 2>&1 | head -1))"
else
    warn "glslc not in PATH — shader compilation may fail"
fi

# ── Environment hints ─────────────────────────────────────────────────────
BREW_PREFIX="$(brew --prefix)"

echo ""
echo "── Environment Variables ─────────────────────────────────────"
echo "Add these to your shell profile (~/.zshrc):"
echo ""
echo "  export VULKAN_SDK=\"${BREW_PREFIX}/share/vulkan\""
echo "  export VK_ICD_FILENAMES=\"${BREW_PREFIX}/share/vulkan/icd.d/MoltenVK_icd.json\""
echo "  export VK_LAYER_PATH=\"${BREW_PREFIX}/share/vulkan/explicit_layer.d\""
echo ""
echo "VK_LAYER_PATH is REQUIRED for validation layers to work."
echo "VK_ICD_FILENAMES is REQUIRED for MoltenVK to be found by the loader."
echo ""

# ── Auto-apply to current shell (offer to persist) ──────────────────────
echo "── Applying to current shell ─────────────────────────────────"
export VULKAN_SDK="${BREW_PREFIX}/share/vulkan"
export VK_ICD_FILENAMES="${BREW_PREFIX}/share/vulkan/icd.d/MoltenVK_icd.json"
export VK_LAYER_PATH="${BREW_PREFIX}/share/vulkan/explicit_layer.d"
info "Environment variables set for this shell session"
echo ""

# Check if already in .zshrc
if grep -q "VK_LAYER_PATH" ~/.zshrc 2>/dev/null; then
    info "Vulkan env vars already in ~/.zshrc"
else
    read -rp "Add Vulkan environment variables to ~/.zshrc? [Y/n] " reply
    if [[ "${reply:-Y}" =~ ^[Yy]$ ]]; then
        cat >> ~/.zshrc << ZSHEOF

# Vulkan SDK (Homebrew / MoltenVK)
export VULKAN_SDK="${BREW_PREFIX}/share/vulkan"
export VK_ICD_FILENAMES="${BREW_PREFIX}/share/vulkan/icd.d/MoltenVK_icd.json"
export VK_LAYER_PATH="${BREW_PREFIX}/share/vulkan/explicit_layer.d"
ZSHEOF
        info "Added to ~/.zshrc — restart your terminal or run: source ~/.zshrc"
    else
        warn "Skipped. Remember to set these manually."
    fi
fi
echo ""

# ── Build instructions ────────────────────────────────────────────────────
echo "── Build ─────────────────────────────────────────────────────"
echo ""
echo "  cmake -B build -DCMAKE_BUILD_TYPE=Debug"
echo "  cmake --build build -j\$(sysctl -n hw.ncpu)"
echo "  ./build/vulkan_renderer"
echo ""
info "Setup complete!"
