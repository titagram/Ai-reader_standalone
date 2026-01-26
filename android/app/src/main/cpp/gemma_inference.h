/**
 * Gemma Inference Native Library Header
 *
 * This header defines the C API for the Gemma inference library,
 * which provides native text generation capabilities for Flutter.
 */

#ifndef GEMMA_INFERENCE_H
#define GEMMA_INFERENCE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize the Gemma model from a file path.
 *
 * @param model_path Path to the GGUF model file
 * @param num_threads Number of threads to use for inference
 * @return 0 on success, non-zero error code on failure
 */
int32_t gemma_init_model(const char* model_path, int32_t num_threads);

/**
 * Free the loaded model and release resources.
 */
void gemma_free_model(void);

/**
 * Generate text from a prompt.
 *
 * @param prompt The input prompt text
 * @param max_tokens Maximum number of tokens to generate
 * @param temperature Sampling temperature (0.0 - 2.0)
 * @param top_k Top-K sampling parameter
 * @param top_p Top-P (nucleus) sampling parameter
 * @param output Buffer to store the generated text
 * @param output_size Size of the output buffer
 * @return Number of bytes written to output, or negative error code
 */
int32_t gemma_generate(
    const char* prompt,
    int32_t max_tokens,
    double temperature,
    int32_t top_k,
    double top_p,
    uint8_t* output,
    int32_t output_size
);

/**
 * Check if a model is currently loaded.
 *
 * @return 1 if model is loaded, 0 otherwise
 */
int32_t gemma_is_model_loaded(void);

/**
 * Get the last error message.
 *
 * @return Pointer to error message string, or NULL if no error
 */
const char* gemma_get_last_error(void);

/**
 * Set the callback for streaming token output.
 *
 * @param callback Function pointer for token callback
 */
typedef void (*gemma_token_callback)(const char* token);
void gemma_set_token_callback(gemma_token_callback callback);

/**
 * Cancel ongoing generation.
 */
void gemma_cancel_generation(void);

#ifdef __cplusplus
}
#endif

#endif // GEMMA_INFERENCE_H
