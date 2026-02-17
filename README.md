# vulkan-renderer

A Vulkan graphics renderer for macOS, built with C++20 and MoltenVK. Following [Brendan Galea's Vulkan Game Engine Tutorial](https://www.youtube.com/playlist?list=PL8327DO66nu9qYVKLDmdLW_84-yE4auCR) series.

## Features

- **MoltenVK** — Vulkan-to-Metal translation layer for native macOS support
- **CMake build system** — automatic dependency resolution for Vulkan, GLFW, and GLM via Homebrew
- **Shader compilation pipeline** — GLSL → SPIR-V at build time (supports both `glslc` and `glslangValidator`)
- **Validation layers** — enabled in debug builds with graceful fallback when unavailable
- **CMake presets** — Debug (validation on, symbols) and Release (validation off, optimized)

## Prerequisites

- macOS with Apple Silicon or Intel
- [Homebrew](https://brew.sh)
- CMake 3.24+
- A C++20 compiler (Xcode Command Line Tools)

## Quick Start

```bash
# Install all dependencies
chmod +x setup.sh && ./setup.sh

# Build (debug)
cmake --preset debug
cmake --build build/debug

# Run
./build/debug/vulkan_renderer
```

## Project Structure

```
vulkan-renderer/
├── CMakeLists.txt            # Build configuration
├── CMakePresets.json         # Debug/Release presets
├── cmake/
│   └── CompileShaders.cmake  # GLSL → SPIR-V compilation module
├── shaders/
│   ├── triangle.vert         # Vertex shader
│   └── triangle.frag         # Fragment shader
├── src/
│   ├── main.cpp              # Entry point
│   ├── first_app.hpp/cpp     # Application class
│   └── lve_window.hpp/cpp    # GLFW window wrapper
└── setup.sh                  # One-time dependency installer
```

## Dependencies

Installed automatically via `setup.sh`:

| Package | Purpose |
|---------|---------|
| `molten-vk` | Vulkan → Metal translation |
| `vulkan-headers` | Vulkan C headers |
| `vulkan-loader` | `libvulkan` ICD loader |
| `vulkan-tools` | `vulkaninfo`, `vkcube` |
| `vulkan-validationlayers` | `VK_LAYER_KHRONOS_validation` |
| `glfw` | Windowing and input |
| `glm` | Math library (header-only) |
| `glslang` | `glslangValidator` shader compiler |
| `shaderc` | `glslc` shader compiler |

## Environment Variables

Required for MoltenVK and validation layers (`setup.sh` offers to set these):

```bash
export VULKAN_SDK="$(brew --prefix)/share/vulkan"
export VK_ICD_FILENAMES="$(brew --prefix)/share/vulkan/icd.d/MoltenVK_icd.json"
export VK_LAYER_PATH="$(brew --prefix)/share/vulkan/explicit_layer.d"
```

## License

MIT
