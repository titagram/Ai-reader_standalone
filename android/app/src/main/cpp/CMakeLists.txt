cmake_minimum_required(VERSION 3.18.1)
project("gemma_inference" LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Global flags (apply to all targets including llama.cpp)
# NOTE: Do NOT use -ffast-math here — llama.cpp requires non-finite math (NaN, Infinity)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG -fPIC")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -DNDEBUG -fPIC")

# ARM NEON for Android ARM64
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a+simd")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a+simd")
endif()

# --- llama.cpp configuration ---
set(LLAMA_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp)

# Disable features we don't need to reduce binary size
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_HTTPLIB OFF CACHE BOOL "" FORCE)

# Build optimizations
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)  # We set arch flags manually
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)  # Android NDK doesn't ship libomp

add_subdirectory(${LLAMA_CPP_DIR} llama_cpp_build)

# --- Our wrapper library ---
add_library(gemma_inference SHARED
    gemma_inference.cpp
)

# Our wrapper gets additional flags
target_compile_options(gemma_inference PRIVATE -fvisibility=hidden)

target_include_directories(gemma_inference PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
)

target_link_libraries(gemma_inference
    llama
    ggml
    android
    log
)

set_target_properties(gemma_inference PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set_target_properties(gemma_inference PROPERTIES
        LINK_FLAGS "-s"
    )
endif()
