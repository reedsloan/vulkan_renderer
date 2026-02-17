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

    # ── Try glslc first ────────────────────────────────────────────────────
    find_program(GLSLC_EXECUTABLE glslc
        HINTS "$ENV{VULKAN_SDK}/bin" "${HOMEBREW_PREFIX}/bin"
    )

    # ── Fall back to glslangValidator ──────────────────────────────────────
    find_program(GLSLANG_VALIDATOR_EXECUTABLE glslangValidator
        HINTS "$ENV{VULKAN_SDK}/bin" "${HOMEBREW_PREFIX}/bin"
    )

    if(GLSLC_EXECUTABLE)
        set(SHADER_COMPILER "glslc")
        message(STATUS "Shader compiler: glslc (${GLSLC_EXECUTABLE})")
    elseif(GLSLANG_VALIDATOR_EXECUTABLE)
        set(SHADER_COMPILER "glslangValidator")
        message(STATUS "Shader compiler: glslangValidator (${GLSLANG_VALIDATOR_EXECUTABLE})")
    else()
        message(FATAL_ERROR
            "No GLSL → SPIR-V compiler found.\n"
            "  Install one of:\n"
            "    brew install shaderc          # provides glslc (recommended)\n"
            "    brew install glslang          # provides glslangValidator\n"
            "    brew install vulkan-tools     # also provides glslangValidator"
        )
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
                COMMENT "Compiling shader ${SHADER_NAME} → SPIR-V (glslc)"
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
                COMMENT "Compiling shader ${SHADER_NAME} → SPIR-V (glslangValidator)"
                VERBATIM
            )
        endif()

        list(APPEND SPIRV_OUTPUTS ${SPIRV_OUT})
    endforeach()

    add_custom_target(${SHADER_TARGET} DEPENDS ${SPIRV_OUTPUTS})
endfunction()
