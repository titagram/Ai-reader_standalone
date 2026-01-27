/**
 * Gemma Inference Native Library Implementation
 *
 * Implements the C API defined in gemma_inference.h using llama.cpp as the
 * inference backend. Supports GGUF model loading, batched prompt evaluation,
 * token-by-token generation with streaming callbacks, and cancellation.
 */

#include "gemma_inference.h"
#include "llama.h"

#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include <mutex>
#include <atomic>

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "GemmaInference"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOGI(...) do { fprintf(stdout, __VA_ARGS__); fprintf(stdout, "\n"); } while(0)
#define LOGW(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#define LOGE(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#endif

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------
static struct llama_model * g_model          = nullptr;
static int32_t              g_num_threads    = 4;
static std::string          g_last_error;
static std::mutex           g_mutex;
static std::atomic<bool>    g_cancel_requested{false};
static std::atomic<gemma_token_callback> g_token_callback{nullptr};
static bool                 g_backend_initialized = false;

// ---------------------------------------------------------------------------
// Helper: set the last error string (caller must hold g_mutex or be safe)
// ---------------------------------------------------------------------------
static void set_error(const std::string & msg) {
    g_last_error = msg;
    LOGE("%s", msg.c_str());
}

// ---------------------------------------------------------------------------
// C API implementation
// ---------------------------------------------------------------------------

extern "C" {

int32_t gemma_init_model(const char * model_path, int32_t num_threads) {
    std::lock_guard<std::mutex> lock(g_mutex);

    // Free any previously loaded model
    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }

    if (model_path == nullptr || model_path[0] == '\0') {
        set_error("Invalid model path: path is null or empty");
        return -1;
    }

    if (num_threads <= 0) {
        num_threads = 4;
    }
    g_num_threads = num_threads;

    // Initialize the llama backend once
    if (!g_backend_initialized) {
        llama_backend_init();
        g_backend_initialized = true;
        LOGI("llama backend initialized");
    }

    // Set up model parameters
    struct llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0; // CPU-only on Android
    model_params.use_mmap     = true;

    LOGI("Loading model from: %s (threads=%d)", model_path, num_threads);

    g_model = llama_model_load_from_file(model_path, model_params);
    if (g_model == nullptr) {
        set_error(std::string("Failed to load model from: ") + model_path);
        return -2;
    }

    LOGI("Model loaded successfully");
    g_last_error.clear();
    return 0;
}

void gemma_free_model(void) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
        LOGI("Model freed");
    }
}

int32_t gemma_generate(
    const char * prompt,
    int32_t      max_tokens,
    double       temperature,
    int32_t      top_k,
    double       top_p,
    uint8_t    * output,
    int32_t      output_size
) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_model == nullptr) {
        set_error("Model not loaded");
        return -1;
    }
    if (prompt == nullptr || output == nullptr || output_size <= 0) {
        set_error("Invalid parameters: null prompt, output, or non-positive output_size");
        return -2;
    }

    g_cancel_requested = false;

    // ------------------------------------------------------------------
    // 1. Create a context for this generation call
    // ------------------------------------------------------------------
    const struct llama_vocab * vocab = llama_model_get_vocab(g_model);

    struct llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx           = 4096;
    ctx_params.n_batch         = 512;
    ctx_params.n_ubatch        = 512;
    ctx_params.n_threads       = g_num_threads;
    ctx_params.n_threads_batch = g_num_threads;
    ctx_params.no_perf         = true;

    struct llama_context * ctx = llama_init_from_model(g_model, ctx_params);
    if (ctx == nullptr) {
        set_error("Failed to create llama context");
        return -3;
    }

    // ------------------------------------------------------------------
    // 2. Tokenize the prompt
    // ------------------------------------------------------------------
    const int prompt_len = static_cast<int>(strlen(prompt));

    // First call to get the number of tokens needed (negative value)
    int n_tokens = llama_tokenize(vocab, prompt, prompt_len, nullptr, 0, true, true);
    if (n_tokens < 0) {
        n_tokens = -n_tokens;
    }

    std::vector<llama_token> tokens(n_tokens);
    int n_prompt_tokens = llama_tokenize(vocab, prompt, prompt_len,
                                         tokens.data(), static_cast<int32_t>(tokens.size()),
                                         true, true);
    if (n_prompt_tokens < 0) {
        set_error("Tokenization failed");
        llama_free(ctx);
        return -4;
    }
    tokens.resize(n_prompt_tokens);

    LOGI("Prompt tokenized: %d tokens", n_prompt_tokens);

    // Check that the prompt fits in the context
    const int n_ctx = static_cast<int>(llama_n_ctx(ctx));
    if (n_prompt_tokens + max_tokens > n_ctx) {
        // Clamp max_tokens to fit
        max_tokens = n_ctx - n_prompt_tokens;
        if (max_tokens <= 0) {
            set_error("Prompt too long for context window");
            llama_free(ctx);
            return -5;
        }
        LOGW("Clamped max_tokens to %d to fit context", max_tokens);
    }

    // ------------------------------------------------------------------
    // 3. Evaluate the prompt in batches
    // ------------------------------------------------------------------
    const int n_batch = static_cast<int>(llama_n_batch(ctx));

    for (int i = 0; i < n_prompt_tokens; i += n_batch) {
        if (g_cancel_requested.load()) {
            LOGI("Generation cancelled during prompt evaluation");
            llama_free(ctx);
            return 0;
        }

        int n_eval = n_prompt_tokens - i;
        if (n_eval > n_batch) {
            n_eval = n_batch;
        }

        struct llama_batch batch = llama_batch_get_one(tokens.data() + i, n_eval);
        int rc = llama_decode(ctx, batch);
        if (rc != 0) {
            set_error("llama_decode failed during prompt evaluation (rc=" + std::to_string(rc) + ")");
            llama_free(ctx);
            return -6;
        }
    }

    // ------------------------------------------------------------------
    // 4. Set up the sampler chain
    // ------------------------------------------------------------------
    struct llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    sparams.no_perf = true;

    struct llama_sampler * smpl = llama_sampler_chain_init(sparams);

    if (top_k > 0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(top_k));
    }
    if (top_p > 0.0 && top_p < 1.0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(static_cast<float>(top_p), 1));
    }
    if (temperature > 0.0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(static_cast<float>(temperature)));
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    } else {
        // temperature <= 0 means greedy
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
    }

    // ------------------------------------------------------------------
    // 5. Token generation loop
    // ------------------------------------------------------------------
    int total_bytes = 0;
    bool generation_error = false;
    char piece_buf[256];

    for (int i = 0; i < max_tokens; ++i) {
        if (g_cancel_requested.load()) {
            LOGI("Generation cancelled at token %d", i);
            break;
        }

        // Sample the next token from the last logits
        llama_token new_token = llama_sampler_sample(smpl, ctx, -1);

        // Check for end-of-generation
        if (llama_vocab_is_eog(vocab, new_token)) {
            LOGI("End-of-generation token at step %d", i);
            break;
        }

        // Convert token to text piece
        int piece_len = llama_token_to_piece(vocab, new_token, piece_buf,
                                              sizeof(piece_buf) - 1, 0, false);
        if (piece_len < 0) {
            // Buffer too small for this token; skip it
            LOGW("Token to piece buffer too small, skipping token");
            continue;
        }
        piece_buf[piece_len] = '\0';

        // Stream callback
        gemma_token_callback cb = g_token_callback.load();
        if (cb != nullptr) {
            cb(piece_buf);
        }

        // Copy to output buffer (reserve 1 byte for null terminator)
        if (total_bytes + piece_len + 1 <= output_size) {
            memcpy(output + total_bytes, piece_buf, piece_len);
            total_bytes += piece_len;
        } else {
            // Output buffer full
            int remaining = output_size - 1 - total_bytes;
            if (remaining > 0) {
                memcpy(output + total_bytes, piece_buf, remaining);
                total_bytes += remaining;
            }
            LOGW("Output buffer full at token %d", i);
            break;
        }

        // Prepare and decode the new token for the next iteration
        struct llama_batch batch = llama_batch_get_one(&new_token, 1);
        int rc = llama_decode(ctx, batch);
        if (rc != 0) {
            set_error("llama_decode failed during generation (rc=" + std::to_string(rc) + ")");
            generation_error = true;
            break;
        }
    }

    // Null-terminate the output
    if (total_bytes < output_size) {
        output[total_bytes] = '\0';
    } else {
        output[output_size - 1] = '\0';
    }

    // ------------------------------------------------------------------
    // 6. Cleanup
    // ------------------------------------------------------------------
    llama_sampler_free(smpl);
    llama_free(ctx);

    if (generation_error) {
        LOGE("Generation finished with error after %d bytes", total_bytes);
        return -7;
    }

    LOGI("Generation complete: %d bytes", total_bytes);
    g_last_error.clear();
    return total_bytes;
}

int32_t gemma_is_model_loaded(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return (g_model != nullptr) ? 1 : 0;
}

const char * gemma_get_last_error(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_last_error.empty()) {
        return nullptr;
    }
    return g_last_error.c_str();
}

void gemma_set_token_callback(gemma_token_callback callback) {
    g_token_callback.store(callback);
}

void gemma_cancel_generation(void) {
    g_cancel_requested = true;
}

} // extern "C"
