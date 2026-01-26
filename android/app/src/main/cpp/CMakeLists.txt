# CMake configuration for Gemma inference native library
cmake_minimum_required(VERSION 3.18.1)

project("gemma_inference" LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Compiler flags for optimization
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -DNDEBUG")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -fvisibility=hidden")

# ARM NEON optimizations for Android
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a+simd")
endif()

# Source files
set(SOURCE_FILES
    gemma_inference.cpp
)

# Create shared library
add_library(
    gemma_inference
    SHARED
    ${SOURCE_FILES}
)

# Include directories
target_include_directories(gemma_inference PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Link libraries
target_link_libraries(gemma_inference
    android
    log
)

# Export symbols
set_target_properties(gemma_inference PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# Strip debug info in release
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set_target_properties(gemma_inference PROPERTIES
        LINK_FLAGS "-s"
    )
endif()

# ============================================
# Instructions for integrating gemma.cpp:
# ============================================
#
# 1. Clone gemma.cpp:
#    git clone https://github.com/google/gemma.cpp
#
# 2. Add gemma.cpp as a subdirectory:
#    add_subdirectory(${GEMMA_CPP_PATH} gemma_cpp)
#
# 3. Link against gemma:
#    target_link_libraries(gemma_inference gemma)
#
# 4. Include gemma headers:
#    target_include_directories(gemma_inference PRIVATE
#        ${GEMMA_CPP_PATH}/include
#    )
# ============================================
