# cmake/CompileShaders.cmake
# ---------------------------------------------------------------------------
# Provides compile_shaders() — finds glslc or glslangValidator and
# compiles every GLSL source into SPIR-V at build time.
#
# Preference order:
#   1. glslc        (Google shaderc — best error messages, clang-like flags)
#   2. glslangValidator  (Khronos reference compiler — ships with vulkan-tools)
# ---------------------------------------------------------------------------

function(compile_shaders)
    set(oneValueArgs TARGET OUTPUT_DIR)
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(SHADER "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT SHADER_TARGET)
        message(FATAL_ERROR "compile_shaders: TARGET is required")
    endif()

    # ── Build a list of hint directories per platform ──────────────────────
    set(_SHADER_HINTS "$ENV{VULKAN_SDK}/bin")

    if(APPLE AND HOMEBREW_PREFIX)
        list(APPEND _SHADER_HINTS "${HOMEBREW_PREFIX}/bin")
    endif()

    if(WIN32)
        # LunarG SDK keeps tools in Bin/ (and Bin32/ for 32-bit)
        list(APPEND _SHADER_HINTS "$ENV{VULKAN_SDK}/Bin")
        # Also check common default install if VULKAN_SDK is unset
        file(GLOB _VK_BIN_DIRS "C:/VulkanSDK/*/Bin")
        if(_VK_BIN_DIRS)
            list(SORT _VK_BIN_DIRS)
            list(GET _VK_BIN_DIRS -1 _VK_BIN_LATEST)
            list(APPEND _SHADER_HINTS "${_VK_BIN_LATEST}")
        endif()
    endif()

    # ── Try glslc first ────────────────────────────────────────────────────
    find_program(GLSLC_EXECUTABLE glslc
        HINTS ${_SHADER_HINTS}
    )

    # ── Fall back to glslangValidator ──────────────────────────────────────
    find_program(GLSLANG_VALIDATOR_EXECUTABLE glslangValidator
        HINTS ${_SHADER_HINTS}
    )

    if(GLSLC_EXECUTABLE)
        set(SHADER_COMPILER "glslc")
        message(STATUS "Shader compiler: glslc (${GLSLC_EXECUTABLE})")
    elseif(GLSLANG_VALIDATOR_EXECUTABLE)
        set(SHADER_COMPILER "glslangValidator")
        message(STATUS "Shader compiler: glslangValidator (${GLSLANG_VALIDATOR_EXECUTABLE})")
    else()
        if(APPLE)
            message(FATAL_ERROR
                "No GLSL -> SPIR-V compiler found.\n"
                "  Install one of:\n"
                "    brew install shaderc          # provides glslc (recommended)\n"
                "    brew install glslang          # provides glslangValidator\n"
                "    brew install vulkan-tools     # also provides glslangValidator"
            )
        elseif(WIN32)
            message(FATAL_ERROR
                "No GLSL -> SPIR-V compiler found.\n"
                "  glslc ships with the LunarG Vulkan SDK.\n"
                "  Download it from: https://vulkan.lunarg.com/sdk/home\n"
                "  Make sure VULKAN_SDK is set or the SDK is in C:\\VulkanSDK\\."
            )
        else()
            message(FATAL_ERROR
                "No GLSL -> SPIR-V compiler found.\n"
                "  Install the Vulkan SDK or the shaderc / glslang package for your distro."
            )
        endif()
    endif()

    set(SPIRV_OUTPUTS "")

    foreach(SHADER_SRC ${SHADER_SOURCES})
        get_filename_component(SHADER_NAME ${SHADER_SRC} NAME)
        set(SPIRV_OUT "${SHADER_OUTPUT_DIR}/${SHADER_NAME}.spv")

        if(SHADER_COMPILER STREQUAL "glslc")
            add_custom_command(
                OUTPUT  ${SPIRV_OUT}
                COMMAND ${CMAKE_COMMAND} -E make_directory "${SHADER_OUTPUT_DIR}"
                COMMAND ${GLSLC_EXECUTABLE}
                        -O
                        --target-env=vulkan1.3
                        -o ${SPIRV_OUT}
                        ${SHADER_SRC}
                DEPENDS ${SHADER_SRC}
                COMMENT "Compiling shader ${SHADER_NAME} -> SPIR-V (glslc)"
                VERBATIM
            )
        else()
            add_custom_command(
                OUTPUT  ${SPIRV_OUT}
                COMMAND ${CMAKE_COMMAND} -E make_directory "${SHADER_OUTPUT_DIR}"
                COMMAND ${GLSLANG_VALIDATOR_EXECUTABLE}
                        -V                              # compile to SPIR-V
                        --target-env vulkan1.3
                        -o ${SPIRV_OUT}
                        ${SHADER_SRC}
                DEPENDS ${SHADER_SRC}
                COMMENT "Compiling shader ${SHADER_NAME} -> SPIR-V (glslangValidator)"
                VERBATIM
            )
        endif()

        list(APPEND SPIRV_OUTPUTS ${SPIRV_OUT})
    endforeach()

    add_custom_target(${SHADER_TARGET} DEPENDS ${SPIRV_OUTPUTS})
endfunction()
