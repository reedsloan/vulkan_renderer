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
# Dependencies
# --------------------------------------------------------------------------- #

# --- Vulkan SDK (via MoltenVK on macOS) ---
find_package(Vulkan REQUIRED)
message(STATUS "Vulkan found: ${Vulkan_INCLUDE_DIRS}")
message(STATUS "Vulkan library: ${Vulkan_LIBRARIES}")

# --- GLFW ---
find_package(glfw3 3.3 REQUIRED)

# --- GLM (header-only) ---
find_package(glm REQUIRED)

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
# Compiler warnings (production-grade)
# --------------------------------------------------------------------------- #
target_compile_options(${PROJECT_NAME} PRIVATE
    -Wall -Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor
    -Wold-style-cast -Wcast-align -Woverloaded-virtual
    -Wconversion -Wsign-conversion -Wnull-dereference
    -Wformat=2 -Wimplicit-fallthrough
)

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(${PROJECT_NAME} PRIVATE -O2)
elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(${PROJECT_NAME} PRIVATE -g -O0)
endif()
