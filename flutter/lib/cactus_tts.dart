import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import './ffi_bindings.dart' as bindings;
import './types.dart';
import './cactus_context.dart';

class CactusTTS {
  CactusContext? _context;
  
  CactusTTS._();

  static Future<CactusTTS> init({
    required String modelUrl,
    String? modelFilename,
    int contextSize = 2048,
    int gpuLayers = 0,
    int threads = 4,
    CactusProgressCallback? onProgress,
  }) async {
    final tts = CactusTTS._();
    
    tts._context = await CactusContext.init(CactusInitParams(
      modelUrl: modelUrl,
      modelFilename: modelFilename,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      threads: threads,
      onInitProgress: onProgress,
    ));
    
    return tts;
  }

  Future<CactusResult> generate(
    String text, {
    int maxTokens = 256,
    double? temperature,
    int? topK,
    double? topP,
    List<String>? stopSequences,
    CactusTokenCallback? onToken,
  }) async {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    
    final messages = [
      ChatMessage(role: 'user', content: text),
    ];
    
    return await _context!.completion(
      CactusCompletionParams(
        messages: messages,
        maxPredictedTokens: maxTokens,
        temperature: temperature,
        topK: topK,
        topP: topP,
        stopSequences: stopSequences,
        onNewToken: onToken,
      ),
    );
  }

  bool get supportsAudio {
    if (_context == null) return false;
    return _context!.supportsAudio();
  }

  List<int> tokenize(String text) {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    return _context!.tokenize(text);
  }

  String detokenize(List<int> tokens) {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    return _context!.detokenize(tokens);
  }

  void applyLoraAdapters(List<LoraAdapterInfo> adapters) {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    _context!.applyLoraAdapters(adapters);
  }

  void removeLoraAdapters() {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    _context!.removeLoraAdapters();
  }

  List<LoraAdapterInfo> getLoadedLoraAdapters() {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    return _context!.getLoadedLoraAdapters();
  }

  void rewind() {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    _context!.rewind();
  }

  void stopCompletion() {
    if (_context == null) throw CactusException('CactusTTS not initialized');
    _context!.stopCompletion();
  }

  void dispose() {
    _context?.release();
    _context = null;
  }
} 