cmake_minimum_required(VERSION 3.10)
project(cactus_core)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CACTUS_CORE_SOURCES
    cactus_context.cpp
    cactus_loader.cpp
    cactus_completion.cpp
    cactus_utils.cpp
    cactus_embedding.cpp
    cactus_lora.cpp
    cactus_ffi.cpp
    cactus_tokenization.cpp
    cactus_multimodal.cpp
    cactus_tts.cpp
    cactus_bench.cpp
    cactus_chat.cpp
    ggml.c
    ggml-alloc.c
    ggml-backend.cpp
    ggml-backend-reg.cpp
    ggml-opt.cpp
    ggml-threading.cpp
    ggml-quants.c
    gguf.cpp
    ggml-cpu/ggml-cpu.c
    ggml-cpu/ggml-cpu.cpp
    ggml-cpu/ggml-cpu-aarch64.cpp
    ggml-cpu/ggml-cpu-quants.c
    ggml-cpu/ggml-cpu-traits.cpp
    ggml-cpu/amx/amx.cpp
    ggml-cpu/amx/mmq.cpp
    ggml-cpu/unary-ops.cpp
    ggml-cpu/binary-ops.cpp
    ggml-cpu/sgemm.cpp
    ggml-cpu/vec.cpp
    ggml-cpu/ops.cpp
    log.cpp
    llama-impl.cpp
    llama-grammar.cpp
    llama-sampling.cpp
    llama-vocab.cpp
    llama-adapter.cpp
    llama-chat.cpp
    llama-context.cpp
    llama-kv-cache.cpp
    llama-arch.cpp
    llama-batch.cpp
    llama-cparams.cpp
    llama-hparams.cpp
    llama.cpp
    llama-model.cpp
    llama-model-loader.cpp
    llama-model-saver.cpp
    llama-mmap.cpp
    llama-memory.cpp
    llama-io.cpp
    llama-graph.cpp
    sampling.cpp
    unicode-data.cpp
    unicode.cpp
    common.cpp
    chat.cpp
    json-schema-to-grammar.cpp
    minja/minja.hpp
    minja/chat-template.hpp
    json.hpp
    tools/mtmd/mtmd.cpp
    tools/mtmd/mtmd-audio.cpp
    tools/mtmd/clip.cpp
    tools/mtmd/mtmd-helper.cpp
)

if(APPLE)
    list(APPEND CACTUS_CORE_SOURCES ggml-metal.m)
endif()

add_library(cactus_core_lib OBJECT ${CACTUS_CORE_SOURCES})

target_include_directories(cactus_core_lib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ggml-cpu>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/minja>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/tools/mtmd>
)

if(NOT MSVC)
    target_compile_options(cactus_core_lib PRIVATE -Wno-cast-qual)
endif()

target_compile_definitions(cactus_core_lib PUBLIC
    LM_GGML_USE_CPU
    CACTUS_VERBOSE=0
)

if (MSVC)
	target_compile_definitions(cactus_core_lib PUBLIC
		_CRT_SECURE_NO_DEPRECATE
		_USE_MATH_DEFINES
	)
endif()

if(APPLE)
    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(ACCELERATE_FRAMEWORK Accelerate)
    find_library(METAL_LIBRARY Metal)
    find_library(METALKIT_LIBRARY MetalKit)

    if(FOUNDATION_LIBRARY AND ACCELERATE_FRAMEWORK)
        target_link_libraries(cactus_core_lib PUBLIC
            ${FOUNDATION_LIBRARY}
            ${ACCELERATE_FRAMEWORK}
        )
        target_compile_definitions(cactus_core_lib PUBLIC
            LM_GGML_USE_ACCELERATE
        )
    endif()
    
    if(METAL_LIBRARY AND METALKIT_LIBRARY)
        target_link_libraries(cactus_core_lib PUBLIC
            ${METAL_LIBRARY}
            ${METALKIT_LIBRARY}
        )
        target_compile_definitions(cactus_core_lib PUBLIC
            LM_GGML_USE_METAL
            LM_GGML_METAL_USE_BF16
        )
    endif()
endif()

# ---- Install rules, only on Windows ----
if(WIN32)
    # Create a static library from the object files
    add_library(cactus_core_static STATIC $<TARGET_OBJECTS:cactus_core_lib>)
    target_include_directories(cactus_core_static PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/ggml-cpu>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/minja>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/tools/mtmd>
    )

    install(TARGETS cactus_core_static
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
    )

    # Install headers, excluding build, example, and patches
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
        DESTINATION include
        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
        PATTERN "build" EXCLUDE
        PATTERN "example" EXCLUDE
        PATTERN "patches" EXCLUDE
    )
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ggml-cpu/
        DESTINATION include/ggml-cpu
        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
        PATTERN "build" EXCLUDE
        PATTERN "example" EXCLUDE
        PATTERN "patches" EXCLUDE
    )
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/minja/
        DESTINATION include/minja
        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
        PATTERN "build" EXCLUDE
        PATTERN "example" EXCLUDE
        PATTERN "patches" EXCLUDE
    )
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tools/mtmd/
        DESTINATION include/tools/mtmd
        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
        PATTERN "build" EXCLUDE
        PATTERN "example" EXCLUDE
        PATTERN "patches" EXCLUDE
    )
endif()