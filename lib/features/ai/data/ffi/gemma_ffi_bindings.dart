import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// FFI bindings for Gemma C++ inference library
///
/// This class provides Dart bindings to the native gemma.cpp library
/// for running Gemma LLM inference on device.
class GemmaFfiBindings {
  GemmaFfiBindings._();

  static GemmaFfiBindings? _instance;
  static GemmaFfiBindings get instance {
    _instance ??= GemmaFfiBindings._();
    return _instance!;
  }

  DynamicLibrary? _lib;
  bool _isInitialized = false;

  // Native function types
  late final _InitModelFunc _initModel;
  late final _FreeModelFunc _freeModel;
  late final _GenerateFunc _generate;
  late final _IsModelLoadedFunc _isModelLoaded;
  late final _GetLastErrorFunc _getLastError;

  /// Initialize FFI bindings
  bool initialize() {
    if (_isInitialized) return true;

    try {
      // Load the native library
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libgemma_inference.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libgemma_inference.so');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libgemma_inference.dylib');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('gemma_inference.dll');
      } else {
        return false;
      }

      // Look up functions
      _initModel = _lib!
          .lookupFunction<_InitModelNative, _InitModelFunc>('gemma_init_model');

      _freeModel = _lib!
          .lookupFunction<_FreeModelNative, _FreeModelFunc>('gemma_free_model');

      _generate =
          _lib!.lookupFunction<_GenerateNative, _GenerateFunc>('gemma_generate');

      _isModelLoaded =
          _lib!.lookupFunction<_IsModelLoadedNative, _IsModelLoadedFunc>(
              'gemma_is_model_loaded');

      _getLastError =
          _lib!.lookupFunction<_GetLastErrorNative, _GetLastErrorFunc>(
              'gemma_get_last_error');

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Check if FFI is available
  bool get isAvailable => _isInitialized && _lib != null;

  /// Initialize model from path
  ///
  /// Returns 0 on success, non-zero on failure
  int initModel(String modelPath, int threads) {
    if (!isAvailable) return -1;

    final pathPtr = modelPath.toNativeUtf8();
    try {
      return _initModel(pathPtr, threads);
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Free loaded model
  void freeModel() {
    if (!isAvailable) return;
    _freeModel();
  }

  /// Generate text from prompt
  ///
  /// Returns generated text or null on failure
  String? generate(
    String prompt,
    int maxTokens,
    double temperature,
    int topK,
    double topP,
  ) {
    if (!isAvailable) return null;

    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = malloc<Uint8>(maxTokens * 4); // Allocate for UTF-8

    try {
      final resultLen = _generate(
        promptPtr,
        maxTokens,
        temperature,
        topK,
        topP,
        resultPtr,
        maxTokens * 4,
      );

      if (resultLen <= 0) return null;

      return resultPtr.cast<Utf8>().toDartString(length: resultLen);
    } finally {
      malloc.free(promptPtr);
      malloc.free(resultPtr);
    }
  }

  /// Check if model is loaded
  bool isModelLoaded() {
    if (!isAvailable) return false;
    return _isModelLoaded() != 0;
  }

  /// Get last error message
  String? getLastError() {
    if (!isAvailable) return 'FFI not initialized';

    final errorPtr = _getLastError();
    if (errorPtr == nullptr) return null;

    return errorPtr.toDartString();
  }
}

// Native function signatures
typedef _InitModelNative = Int32 Function(Pointer<Utf8> modelPath, Int32 threads);
typedef _InitModelFunc = int Function(Pointer<Utf8> modelPath, int threads);

typedef _FreeModelNative = Void Function();
typedef _FreeModelFunc = void Function();

typedef _GenerateNative = Int32 Function(
  Pointer<Utf8> prompt,
  Int32 maxTokens,
  Double temperature,
  Int32 topK,
  Double topP,
  Pointer<Uint8> output,
  Int32 outputSize,
);
typedef _GenerateFunc = int Function(
  Pointer<Utf8> prompt,
  int maxTokens,
  double temperature,
  int topK,
  double topP,
  Pointer<Uint8> output,
  int outputSize,
);

typedef _IsModelLoadedNative = Int32 Function();
typedef _IsModelLoadedFunc = int Function();

typedef _GetLastErrorNative = Pointer<Utf8> Function();
typedef _GetLastErrorFunc = Pointer<Utf8> Function();
