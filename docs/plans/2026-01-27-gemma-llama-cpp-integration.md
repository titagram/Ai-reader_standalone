# Gemma 3B via llama.cpp Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the placeholder C++ inference code with a working llama.cpp backend that loads a Gemma 3B GGUF model and generates text on-device.

**Architecture:** The existing C API boundary (`gemma_inference.h`) stays unchanged. We swap the placeholder `.cpp` implementation to call llama.cpp's C API internally. The Dart FFI bindings, repository, and providers remain as-is — they already expect this exact interface. llama.cpp is vendored as a git submodule under `android/app/src/main/cpp/llama.cpp/`.

**Tech Stack:** C++17, llama.cpp (C API), CMake, Android NDK (ARM64), Dart FFI

---

## Task 1: Vendor llama.cpp as a Git Submodule

**Files:**
- Create: `.gitmodules`
- Create: `android/app/src/main/cpp/llama.cpp/` (submodule)

**Step 1: Add llama.cpp submodule**

```bash
cd /home/gabriele/DEV/Ai-reader_standalone
git submodule add https://github.com/ggerganov/llama.cpp.git android/app/src/main/cpp/llama.cpp
```

**Step 2: Pin to a stable release tag**

```bash
cd android/app/src/main/cpp/llama.cpp
git checkout b5220  # or latest stable tag — check https://github.com/ggerganov/llama.cpp/tags
cd /home/gabriele/DEV/Ai-reader_standalone
```

> **Note:** Check the latest stable tag at build time. The tag `b5220` is an example — use whatever is current.

**Step 3: Commit**

```bash
git add .gitmodules android/app/src/main/cpp/llama.cpp
git commit -m "chore: vendor llama.cpp as git submodule"
```

---

## Task 2: Update CMakeLists.txt to Build llama.cpp

**Files:**
- Modify: `android/app/src/main/cpp/CMakeLists.txt`

**Step 1: Rewrite CMakeLists.txt to integrate llama.cpp**

Replace the full contents of `android/app/src/main/cpp/CMakeLists.txt` with:

```cmake
cmake_minimum_required(VERSION 3.18.1)
project("gemma_inference" LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Optimization flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -DNDEBUG")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -fvisibility=hidden")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -ffast-math -DNDEBUG -fPIC")

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
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)

# Enable optimizations
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)  # We set arch flags manually

add_subdirectory(${LLAMA_CPP_DIR} llama_cpp_build)

# --- Our wrapper library ---
add_library(gemma_inference SHARED
    gemma_inference.cpp
)

target_include_directories(gemma_inference PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
)

target_link_libraries(gemma_inference
    llama
    ggml
    common
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
```

**Key decisions:**
- `LLAMA_BUILD_TESTS/EXAMPLES/SERVER OFF` — shrinks the build significantly.
- `GGML_NATIVE OFF` — we control arch flags ourselves for cross-compilation.
- We link `llama`, `ggml`, and `common` from the llama.cpp build.

**Step 2: Verify CMake parses correctly (dry run)**

```bash
cd /home/gabriele/DEV/Ai-reader_standalone/android
# This won't fully build but checks CMake syntax:
# The real build happens via Flutter/Gradle
```

> Full build verification happens in Task 5.

**Step 3: Commit**

```bash
git add android/app/src/main/cpp/CMakeLists.txt
git commit -m "build: configure CMake to build llama.cpp for Android"
```

---

## Task 3: Implement Real Inference in gemma_inference.cpp

**Files:**
- Modify: `android/app/src/main/cpp/gemma_inference.cpp`
- Modify: `android/app/src/main/cpp/gemma_inference.h` (no changes needed, just verify)

**Step 1: Replace gemma_inference.cpp with llama.cpp-backed implementation**

Replace the full contents of `android/app/src/main/cpp/gemma_inference.cpp` with:

```cpp
/**
 * Gemma Inference via llama.cpp
 *
 * Implements the C API defined in gemma_inference.h using llama.cpp
 * to load GGUF models and run inference on Android.
 */

#include "gemma_inference.h"
#include "llama.h"
#include "common.h"

#include <cstring>
#include <string>
#include <vector>
#include <mutex>
#include <atomic>

#include <android/log.h>
#define LOG_TAG "GemmaInference"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global state
static std::string g_last_error;
static std::mutex g_mutex;
static std::atomic<bool> g_model_loaded{false};
static std::atomic<bool> g_cancel_requested{false};
static gemma_token_callback g_token_callback = nullptr;

static llama_model* g_model = nullptr;

extern "C" {

int32_t gemma_init_model(const char* model_path, int32_t num_threads) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_model_loaded) {
        gemma_free_model();
    }

    if (model_path == nullptr || strlen(model_path) == 0) {
        g_last_error = "Invalid model path";
        return -1;
    }

    LOGI("Loading model from: %s with %d threads", model_path, num_threads);

    // Initialize llama backend (safe to call multiple times)
    llama_backend_init();

    // Load model
    llama_model_params model_params = llama_model_default_params();
    // Use mmap for memory efficiency on mobile
    model_params.use_mmap = true;

    g_model = llama_model_load_from_file(model_path, model_params);
    if (g_model == nullptr) {
        g_last_error = "Failed to load model from: " + std::string(model_path);
        LOGE("%s", g_last_error.c_str());
        return -1;
    }

    g_model_loaded = true;
    g_last_error.clear();
    LOGI("Model loaded successfully");

    return 0;
}

void gemma_free_model(void) {
    // Note: caller should hold g_mutex or this is called from gemma_init_model
    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    g_model_loaded = false;
}

int32_t gemma_generate(
    const char* prompt,
    int32_t max_tokens,
    double temperature,
    int32_t top_k,
    double top_p,
    uint8_t* output,
    int32_t output_size
) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (!g_model_loaded || g_model == nullptr) {
        g_last_error = "Model not loaded";
        return -1;
    }

    if (prompt == nullptr || output == nullptr || output_size <= 0) {
        g_last_error = "Invalid parameters";
        return -2;
    }

    g_cancel_requested = false;

    // Create context for this generation
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 8192;
    ctx_params.n_batch = 512;
    ctx_params.n_threads = 4;
    ctx_params.n_threads_batch = 4;

    llama_context* ctx = llama_init_from_model(g_model, ctx_params);
    if (ctx == nullptr) {
        g_last_error = "Failed to create inference context";
        return -3;
    }

    // Tokenize the prompt
    const llama_vocab* vocab = llama_model_get_vocab(g_model);
    const int n_prompt_max = llama_vocab_n_tokens(vocab) > 0 ? 8192 : 0;
    std::vector<llama_token> tokens(n_prompt_max);

    int n_tokens = llama_tokenize(vocab, prompt, strlen(prompt),
                                   tokens.data(), tokens.size(),
                                   true,  // add_special (BOS)
                                   true); // parse_special
    if (n_tokens < 0) {
        g_last_error = "Tokenization failed";
        llama_free(ctx);
        return -4;
    }
    tokens.resize(n_tokens);

    LOGI("Prompt tokenized: %d tokens", n_tokens);

    // Evaluate prompt tokens in batches
    llama_batch batch = llama_batch_init(512, 0, 1);

    for (int i = 0; i < n_tokens; i += 512) {
        int n_eval = std::min(512, n_tokens - i);
        llama_batch_clear(batch);

        for (int j = 0; j < n_eval; j++) {
            llama_batch_add(batch, tokens[i + j], i + j, {0},
                           (i + j == n_tokens - 1)); // logits only for last token
        }

        if (llama_decode(ctx, batch) != 0) {
            g_last_error = "Failed to evaluate prompt";
            llama_batch_free(batch);
            llama_free(ctx);
            return -5;
        }
    }

    // Set up sampling
    llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(static_cast<float>(top_p), 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(static_cast<float>(temperature)));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    // Generate tokens
    std::string result;
    int n_generated = 0;
    const llama_token eos_token = llama_vocab_eos(vocab);

    for (int i = 0; i < max_tokens; i++) {
        if (g_cancel_requested) {
            LOGI("Generation cancelled after %d tokens", n_generated);
            break;
        }

        llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

        // Check for end of generation
        if (llama_vocab_is_eog(vocab, new_token)) {
            break;
        }

        // Convert token to text
        char token_text[256];
        int token_len = llama_token_to_piece(vocab, new_token, token_text,
                                              sizeof(token_text), 0, true);
        if (token_len > 0) {
            std::string piece(token_text, token_len);
            result += piece;

            // Stream callback
            if (g_token_callback != nullptr) {
                g_token_callback(piece.c_str());
            }
        }

        n_generated++;

        // Prepare next batch
        llama_batch_clear(batch);
        llama_batch_add(batch, new_token, n_tokens + n_generated - 1, {0}, true);

        if (llama_decode(ctx, batch) != 0) {
            g_last_error = "Decode failed during generation";
            break;
        }
    }

    LOGI("Generated %d tokens, %zu bytes of text", n_generated, result.size());

    // Copy result to output buffer
    size_t copy_len = result.size();
    if (static_cast<int32_t>(copy_len) >= output_size) {
        copy_len = output_size - 1;
    }
    memcpy(output, result.c_str(), copy_len);
    output[copy_len] = '\0';

    // Cleanup
    llama_sampler_free(sampler);
    llama_batch_free(batch);
    llama_free(ctx);

    return static_cast<int32_t>(copy_len);
}

int32_t gemma_is_model_loaded(void) {
    return g_model_loaded ? 1 : 0;
}

const char* gemma_get_last_error(void) {
    if (g_last_error.empty()) {
        return nullptr;
    }
    return g_last_error.c_str();
}

void gemma_set_token_callback(gemma_token_callback callback) {
    g_token_callback = callback;
}

void gemma_cancel_generation(void) {
    g_cancel_requested = true;
}

} // extern "C"
```

**Key decisions in this implementation:**
- **Context per generation:** We create and destroy a `llama_context` for each `gemma_generate` call. This trades a small setup cost for simplicity and memory efficiency on mobile.
- **Batch processing:** Prompt tokens are evaluated in batches of 512 for efficiency.
- **Sampling chain:** top_k → top_p → temperature → dist (standard ordering).
- **Android logging:** Uses `__android_log_print` for debugging via `adb logcat`.
- **mmap:** Enabled for memory-efficient model loading on Android.

**Step 2: Verify header compatibility**

Read `gemma_inference.h` and confirm all 7 functions match the implementation:
- `gemma_init_model` ✓
- `gemma_free_model` ✓
- `gemma_generate` ✓
- `gemma_is_model_loaded` ✓
- `gemma_get_last_error` ✓
- `gemma_set_token_callback` ✓
- `gemma_cancel_generation` ✓

No changes needed to the header.

**Step 3: Commit**

```bash
git add android/app/src/main/cpp/gemma_inference.cpp
git commit -m "feat: implement Gemma inference using llama.cpp backend"
```

---

## Task 4: Write Dart-Side Unit Tests (Mocked FFI)

**Files:**
- Create: `test/features/ai/data/repositories/ai_model_repository_impl_test.dart`
- Create: `test/features/ai/presentation/providers/ai_providers_test.dart`
- Create: `test/features/ai/mocks/mock_ai_model_repository.dart`

**Step 1: Create mock repository**

Create `test/features/ai/mocks/mock_ai_model_repository.dart`:

```dart
import 'package:ai_reader/core/utils/result.dart';
import 'package:ai_reader/features/ai/domain/entities/inference_config.dart';
import 'package:ai_reader/features/ai/domain/entities/model_info.dart';
import 'package:ai_reader/features/ai/domain/repositories/ai_model_repository.dart';

class MockAiModelRepository implements AiModelRepository {
  ModelInfo? _currentModel;
  bool _isModelReady = false;
  bool shouldFailDownload = false;
  bool shouldFailLoad = false;
  bool shouldFailGenerate = false;
  String generateResult = 'Mock summary of the document.';
  int downloadModelCallCount = 0;
  int loadModelCallCount = 0;
  int generateTextCallCount = 0;

  @override
  ModelInfo? get currentModel => _currentModel;

  @override
  bool get isModelReady => _isModelReady;

  @override
  List<ModelInfo> getAvailableModels() => DefaultModels.availableModels;

  @override
  Future<Result<bool>> isModelDownloaded(String modelName) async {
    return Result.success(_currentModel?.isDownloaded ?? false);
  }

  @override
  Future<Result<ModelInfo>> downloadModel(
    ModelInfo model, {
    DownloadProgressCallback? onProgress,
  }) async {
    downloadModelCallCount++;
    if (shouldFailDownload) {
      return Result.failure('Download failed');
    }
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    final updated = model.copyWith(
      status: ModelStatus.downloaded,
      localPath: '/mock/path/${model.fileName}',
    );
    _currentModel = updated;
    return Result.success(updated);
  }

  @override
  Future<void> cancelDownload() async {}

  @override
  Future<Result<void>> loadModel(String modelPath) async {
    loadModelCallCount++;
    if (shouldFailLoad) {
      return Result.failure('Load failed');
    }
    _isModelReady = true;
    _currentModel = _currentModel?.copyWith(status: ModelStatus.loaded);
    return Result.success(null);
  }

  @override
  Future<Result<void>> unloadModel() async {
    _isModelReady = false;
    _currentModel = _currentModel?.copyWith(status: ModelStatus.downloaded);
    return Result.success(null);
  }

  @override
  Future<Result<String>> generateText(
    String prompt, {
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    generateTextCallCount++;
    if (shouldFailGenerate) {
      return Result.failure('Generation failed');
    }
    return Result.success(generateResult);
  }

  @override
  Future<Result<String>> generateSummary(
    String text, {
    String? language,
    InferenceConfig? config,
    TokenCallback? onToken,
  }) async {
    return generateText(text, config: config, onToken: onToken);
  }

  @override
  Future<Result<void>> deleteModel(String modelName) async {
    _currentModel = null;
    _isModelReady = false;
    return Result.success(null);
  }

  @override
  Future<String?> getLocalModelPath(String modelName) async {
    return _currentModel?.localPath;
  }
}
```

**Step 2: Write provider tests**

Create `test/features/ai/presentation/providers/ai_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_reader/features/ai/domain/entities/model_info.dart';
import 'package:ai_reader/features/ai/presentation/providers/ai_providers.dart';
import '../../mocks/mock_ai_model_repository.dart';

void main() {
  late MockAiModelRepository mockRepo;
  late ModelStateNotifier notifier;

  setUp(() {
    mockRepo = MockAiModelRepository();
    notifier = ModelStateNotifier(mockRepo);
  });

  group('ModelStateNotifier', () {
    test('initial state has no model and is not loading', () {
      expect(notifier.state.currentModel, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isDownloading, isFalse);
    });

    test('checkModelStatus sets notDownloaded when model is absent', () async {
      await notifier.checkModelStatus();
      expect(notifier.state.currentModel, isNotNull);
      expect(
        notifier.state.currentModel!.status,
        ModelStatus.notDownloaded,
      );
    });

    test('downloadModel updates progress and completes', () async {
      await notifier.checkModelStatus();
      await notifier.downloadModel();
      expect(notifier.state.isDownloading, isFalse);
      expect(notifier.state.currentModel!.status, ModelStatus.downloaded);
      expect(mockRepo.downloadModelCallCount, 1);
    });

    test('downloadModel sets error on failure', () async {
      mockRepo.shouldFailDownload = true;
      await notifier.checkModelStatus();
      await notifier.downloadModel();
      expect(notifier.state.isDownloading, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('loadModel transitions to loaded state', () async {
      // First download
      await notifier.checkModelStatus();
      await notifier.downloadModel();
      // Then load
      await notifier.loadModel();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.currentModel!.status, ModelStatus.loaded);
    });

    test('loadModel fails when model not downloaded', () async {
      await notifier.loadModel();
      expect(notifier.state.error, 'Model not downloaded');
    });

    test('unloadModel transitions back to downloaded', () async {
      await notifier.checkModelStatus();
      await notifier.downloadModel();
      await notifier.loadModel();
      await notifier.unloadModel();
      expect(notifier.state.currentModel!.status, ModelStatus.downloaded);
    });
  });

  group('SummarizationNotifier', () {
    late SummarizationNotifier summarizer;

    setUp(() {
      mockRepo = MockAiModelRepository();
      summarizer = SummarizationNotifier(mockRepo);
    });

    test('initial state is not generating', () {
      expect(summarizer.state.isGenerating, isFalse);
      expect(summarizer.state.summary, isNull);
    });

    test('generateSummary produces result', () async {
      // Prepare mock
      mockRepo.generateResult = 'This is a test summary.';
      await summarizer.generateSummary('Some document text');
      expect(summarizer.state.isGenerating, isFalse);
      expect(summarizer.state.summary, 'This is a test summary.');
    });

    test('generateSummary sets error on failure', () async {
      mockRepo.shouldFailGenerate = true;
      await summarizer.generateSummary('Some text');
      expect(summarizer.state.isGenerating, isFalse);
      expect(summarizer.state.error, isNotNull);
    });

    test('clear resets state', () async {
      mockRepo.generateResult = 'Summary';
      await summarizer.generateSummary('Text');
      summarizer.clear();
      expect(summarizer.state.summary, isNull);
      expect(summarizer.state.isGenerating, isFalse);
    });
  });
}
```

**Step 3: Run tests**

```bash
cd /home/gabriele/DEV/Ai-reader_standalone
flutter test test/features/ai/
```

Expected: All tests pass.

**Step 4: Commit**

```bash
git add test/
git commit -m "test: add unit tests for AI model providers with mock repository"
```

---

## Task 5: Remove Mock Fallback from Repository Implementation

**Files:**
- Modify: `lib/features/ai/data/repositories/ai_model_repository_impl.dart` (lines 122-129, 198-205)

**Step 1: Remove mock fallback in loadModel**

In `ai_model_repository_impl.dart`, the `loadModel` method (line 117-154) has a mock fallback when FFI isn't available (lines 122-129). Remove the mock block so that FFI failure is treated as a real error:

Replace lines 120-129:
```dart
      // Initialize FFI bindings if not already
      final ffi = GemmaFfiBindings.instance;
      if (!ffi.initialize()) {
        // FFI not available, use mock implementation for development
        _isModelLoaded = true;
        _currentModel = DefaultModels.gemma3bInt4.copyWith(
          status: ModelStatus.loaded,
          localPath: modelPath,
        );
        return Result.success(null);
      }
```

With:
```dart
      final ffi = GemmaFfiBindings.instance;
      if (!ffi.initialize()) {
        return Result.failure('Native inference library not available');
      }
```

**Step 2: Remove mock fallback in generateText**

Replace lines 198-205:
```dart
      if (!ffi.isAvailable) {
        // Mock implementation for development
        await Future.delayed(const Duration(seconds: 2));
        return Result.success(
          'This is a mock generated response. '
          'The actual inference will work when the native library is available.',
        );
      }
```

With:
```dart
      if (!ffi.isAvailable) {
        return Result.failure('Native inference library not available');
      }
```

**Step 3: Run tests again**

```bash
flutter test test/features/ai/
```

Expected: All tests still pass (tests use mock repo, not the real impl).

**Step 4: Commit**

```bash
git add lib/features/ai/data/repositories/ai_model_repository_impl.dart
git commit -m "feat: remove mock fallbacks, require real native library"
```

---

## Task 6: Build and Verify on Android

**Files:** No file changes — this is a build verification task.

**Step 1: Ensure llama.cpp submodule is initialized**

```bash
cd /home/gabriele/DEV/Ai-reader_standalone
git submodule update --init --recursive
```

**Step 2: Clean and build the Android APK**

```bash
flutter clean
flutter build apk --debug --target-platform android-arm64
```

Expected: Build succeeds. Watch for:
- CMake finding llama.cpp sources
- Native library `libgemma_inference.so` being compiled
- APK containing the .so file

**Step 3: If build fails, check CMake output**

Common issues:
- Missing `common` target: May need to adjust llama.cpp CMake options. Check if `LLAMA_BUILD_COMMON` needs to be `ON`.
- Header path issues: Verify `include` paths match llama.cpp's directory structure (it changed in recent versions — `include/llama.h` vs `llama.h`).
- Link errors: If `llama_backend_init` is not found, the llama target may not be building. Check `add_subdirectory` output.

**Step 4: Verify .so is in the APK**

```bash
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libgemma
```

Expected: `lib/arm64-v8a/libgemma_inference.so` present in the APK.

**Step 5: Commit any build fixes**

```bash
git add -A
git commit -m "fix: resolve build issues for llama.cpp Android integration"
```

> Only commit this step if fixes were needed.

---

## Task 7: On-Device Smoke Test

**Prerequisite:** Android device or emulator with ARM64 and 8GB+ RAM.

**Step 1: Install debug APK**

```bash
flutter install --debug
```

**Step 2: Open the app and navigate to Settings**

- Tap the settings icon
- Look for the model management section
- Tap "Download Model" — this downloads the ~2GB GGUF from HuggingFace

**Step 3: After download, load the model**

- Tap "Load Model"
- Watch `adb logcat -s GemmaInference` for:
  ```
  I/GemmaInference: Loading model from: /data/...
  I/GemmaInference: Model loaded successfully
  ```

**Step 4: Open a PDF/EPUB and trigger summarization**

- Go back to home, open a document
- Select text or trigger "Summarize"
- Watch logcat for token generation:
  ```
  I/GemmaInference: Prompt tokenized: N tokens
  I/GemmaInference: Generated M tokens, X bytes of text
  ```

**Step 5: Verify output appears in the summary screen**

Expected: Real generated text (not the placeholder message).

---

## Summary of Changes

| Task | What | Files |
|------|------|-------|
| 1 | Vendor llama.cpp | `.gitmodules`, submodule |
| 2 | CMake integration | `CMakeLists.txt` |
| 3 | Real C++ inference | `gemma_inference.cpp` |
| 4 | Dart unit tests | `test/features/ai/...` |
| 5 | Remove mock fallbacks | `ai_model_repository_impl.dart` |
| 6 | Build verification | No file changes |
| 7 | On-device smoke test | No file changes |

**Total commits:** 5-6 (Tasks 1-5 each produce a commit, Task 6 conditionally)

**Risk areas:**
- llama.cpp API may differ slightly depending on the version pinned in Task 1. The implementation in Task 3 targets the current (Jan 2026) API. If function signatures don't match, check the llama.cpp `include/llama.h` header.
- Build time: llama.cpp is large. First Android build may be slow (~5-10 min on modern hardware).
- Model download is ~2GB; ensure test device has sufficient storage and bandwidth.
