cmake_minimum_required(VERSION 3.24)
project(vulkan_renderer
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# --------------------------------------------------------------------------- #
# Build options
# --------------------------------------------------------------------------- #
option(ENABLE_VALIDATION_LAYERS "Enable Vulkan validation layers" ON)

if(ENABLE_VALIDATION_LAYERS)
    add_compile_definitions(ENABLE_VALIDATION_LAYERS)
endif()

# --------------------------------------------------------------------------- #
# Platform detection
# --------------------------------------------------------------------------- #
if(APPLE)
    add_compile_definitions(VK_USE_PLATFORM_MACOS_MVK)
    # MoltenVK requires the portability enumeration extension
    add_compile_definitions(VK_ENABLE_BETA_EXTENSIONS)
elseif(WIN32)
    add_compile_definitions(VK_USE_PLATFORM_WIN32_KHR)
    # Suppress min/max macros from windows.h that conflict with <algorithm>
    add_compile_definitions(NOMINMAX WIN32_LEAN_AND_MEAN)
endif()

# --------------------------------------------------------------------------- #
# Homebrew prefix (macOS) — needed so CMake can find Homebrew-installed libs
# --------------------------------------------------------------------------- #
if(APPLE)
    execute_process(
        COMMAND brew --prefix
        OUTPUT_VARIABLE HOMEBREW_PREFIX
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(HOMEBREW_PREFIX)
        message(STATUS "Homebrew prefix: ${HOMEBREW_PREFIX}")
        list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_PREFIX}")
    endif()

    # Help FindVulkan.cmake locate the Homebrew vulkan-loader & vulkan-headers
    if(NOT DEFINED ENV{VULKAN_SDK})
        # vulkan-loader installs libvulkan.dylib under the Homebrew prefix
        find_library(_VK_LIB vulkan HINTS "${HOMEBREW_PREFIX}/lib" NO_DEFAULT_PATH)
        if(_VK_LIB)
            set(Vulkan_LIBRARY "${_VK_LIB}" CACHE FILEPATH "Vulkan loader library")
        endif()

        # vulkan-headers installs under include/vulkan/
        if(EXISTS "${HOMEBREW_PREFIX}/include/vulkan/vulkan.h")
            set(Vulkan_INCLUDE_DIR "${HOMEBREW_PREFIX}/include" CACHE PATH "Vulkan include dir")
        endif()
    endif()
endif()

# --------------------------------------------------------------------------- #
# Windows — Vulkan SDK discovery
# --------------------------------------------------------------------------- #
if(WIN32)
    # The LunarG Vulkan SDK installer sets VULKAN_SDK in the environment.
    # CMake's FindVulkan uses this automatically, but we add fallback paths
    # in case the env var is missing or the user installed to a custom location.
    if(DEFINED ENV{VULKAN_SDK})
        message(STATUS "Vulkan SDK (env): $ENV{VULKAN_SDK}")
        list(APPEND CMAKE_PREFIX_PATH "$ENV{VULKAN_SDK}")
    else()
        # Common default install locations
        file(GLOB _VK_SDK_DIRS "C:/VulkanSDK/*")
        if(_VK_SDK_DIRS)
            # Pick the latest version (last in sorted glob)
            list(SORT _VK_SDK_DIRS)
            list(GET _VK_SDK_DIRS -1 _VK_SDK_LATEST)
            message(STATUS "Vulkan SDK (auto-detected): ${_VK_SDK_LATEST}")
            list(APPEND CMAKE_PREFIX_PATH "${_VK_SDK_LATEST}")
            set(ENV{VULKAN_SDK} "${_VK_SDK_LATEST}")
        endif()
    endif()
endif()

# --------------------------------------------------------------------------- #
# Dependencies
# --------------------------------------------------------------------------- #

# --- Vulkan SDK (via MoltenVK on macOS, LunarG SDK on Windows) ---
find_package(Vulkan REQUIRED)
message(STATUS "Vulkan found: ${Vulkan_INCLUDE_DIRS}")
message(STATUS "Vulkan library: ${Vulkan_LIBRARIES}")

# --- GLFW ---
# On Windows, if GLFW is not found system-wide, try the Vulkan SDK or
# fall back to FetchContent so the project builds out of the box.
find_package(glfw3 3.3 QUIET)
if(NOT glfw3_FOUND)
    message(STATUS "glfw3 not found via find_package — fetching with FetchContent")
    include(FetchContent)
    FetchContent_Declare(
        glfw
        GIT_REPOSITORY https://github.com/glfw/glfw.git
        GIT_TAG        3.4
    )
    set(GLFW_BUILD_DOCS     OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(glfw)
endif()

# --- GLM (header-only) ---
find_package(glm QUIET)
if(NOT glm_FOUND)
    message(STATUS "glm not found via find_package — fetching with FetchContent")
    include(FetchContent)
    FetchContent_Declare(
        glm
        GIT_REPOSITORY https://github.com/g-truc/glm.git
        GIT_TAG        1.0.1
    )
    FetchContent_MakeAvailable(glm)
endif()

# --------------------------------------------------------------------------- #
# Shader compilation
# --------------------------------------------------------------------------- #
include(cmake/CompileShaders.cmake)

file(GLOB_RECURSE SHADER_SOURCES
    "${CMAKE_SOURCE_DIR}/shaders/*.vert"
    "${CMAKE_SOURCE_DIR}/shaders/*.frag"
    "${CMAKE_SOURCE_DIR}/shaders/*.comp"
    "${CMAKE_SOURCE_DIR}/shaders/*.geom"
    "${CMAKE_SOURCE_DIR}/shaders/*.tesc"
    "${CMAKE_SOURCE_DIR}/shaders/*.tese"
)

compile_shaders(
    TARGET shader_compilation
    SOURCES ${SHADER_SOURCES}
    OUTPUT_DIR "${CMAKE_BINARY_DIR}/shaders"
)

# --------------------------------------------------------------------------- #
# Application target
# --------------------------------------------------------------------------- #
file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS "src/*.cpp" "src/*.h")

add_executable(${PROJECT_NAME} ${APP_SOURCES}
        src/lve_window.cpp
        src/lve_window.hpp
        src/first_app.cpp
        src/first_app.hpp)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${Vulkan_INCLUDE_DIRS}
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Vulkan::Vulkan
    glfw
    glm::glm
)

add_dependencies(${PROJECT_NAME} shader_compilation)

# Pass the shader output directory to C++ so we can locate compiled SPIR-V
target_compile_definitions(${PROJECT_NAME} PRIVATE
    SHADER_DIR="${CMAKE_BINARY_DIR}/shaders"
)

# --------------------------------------------------------------------------- #
# Compiler warnings (production-grade, per-compiler)
# --------------------------------------------------------------------------- #
if(MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE
        /W4             # High warning level
        /permissive-    # Strict standards conformance
        /w14242         # Narrowing conversion
        /w14254         # Operator conversion
        /w14263         # Member function hides base class virtual
        /w14265         # Class has virtual functions but destructor is not virtual
        /w14287         # Unsigned/negative constant mismatch
        /w14296         # Expression is always true/false
        /w14311         # Pointer truncation
        /w14545 /w14546 /w14547 /w14549  # Comma operator before/in expressions
        /w14826         # Conversion is sign-extended
        /w14905         # Wide string literal cast to LPSTR
        /w14906         # String literal cast to LPWSTR
        /w14928         # Illegal copy-initialization
        /we4289         # Loop control variable used outside for-scope
    )
else()
    # GCC / Clang
    target_compile_options(${PROJECT_NAME} PRIVATE
        -Wall -Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor
        -Wold-style-cast -Wcast-align -Woverloaded-virtual
        -Wconversion -Wsign-conversion -Wnull-dereference
        -Wformat=2 -Wimplicit-fallthrough
    )
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    if(MSVC)
        target_compile_options(${PROJECT_NAME} PRIVATE /O2)
    else()
        target_compile_options(${PROJECT_NAME} PRIVATE -O2)
    endif()
elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(MSVC)
        target_compile_options(${PROJECT_NAME} PRIVATE /Zi /Od)
    else()
        target_compile_options(${PROJECT_NAME} PRIVATE -g -O0)
    endif()
endif()
