import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import './ffi_bindings.dart' as bindings;
import './types.dart';
import './tools.dart';
import './cactus_context.dart';

class CactusLM {
  CactusContext? _context;
  
  CactusLM._();

  static Future<CactusLM> init({
    required String modelUrl,
    String? modelFilename,
    String? chatTemplate,
    int contextSize = 2048,
    int gpuLayers = 0,
    int threads = 4,
    bool generateEmbeddings = false,
    CactusProgressCallback? onProgress,
  }) async {
    final lm = CactusLM._();
    
    lm._context = await CactusContext.init(CactusInitParams(
      modelUrl: modelUrl,
      modelFilename: modelFilename,
      chatTemplate: chatTemplate,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      threads: threads,
      generateEmbeddings: generateEmbeddings,
      onInitProgress: onProgress,
    ));
    
    return lm;
  }

  Future<CactusResult> completion(
    List<ChatMessage> messages, {
    int maxTokens = 256,
    double? temperature,
    int? topK,
    double? topP,
    List<String>? stopSequences,
    CactusTokenCallback? onToken,
    Tools? tools,
  }) async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    
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
      tools: tools,
    );
  }

  List<double> embedding(String text) {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return _context!.embedding(text);
  }

  List<int> tokenize(String text) {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return _context!.tokenize(text);
  }

  String detokenize(List<int> tokens) {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return _context!.detokenize(tokens);
  }

  void applyLoraAdapters(List<LoraAdapterInfo> adapters) {
    if (_context == null) throw CactusException('CactusLM not initialized');
    _context!.applyLoraAdapters(adapters);
  }

  void removeLoraAdapters() {
    if (_context == null) throw CactusException('CactusLM not initialized');
    _context!.removeLoraAdapters();
  }

  List<LoraAdapterInfo> getLoadedLoraAdapters() {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return _context!.getLoadedLoraAdapters();
  }

  void rewind() {
    if (_context == null) throw CactusException('CactusLM not initialized');
    _context!.rewind();
  }

  void stopCompletion() {
    if (_context == null) throw CactusException('CactusLM not initialized');
    _context!.stopCompletion();
  }

  void dispose() {
    _context?.release();
    _context = null;
  }
} 