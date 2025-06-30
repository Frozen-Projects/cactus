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

class CactusVLM {
  CactusContext? _context;
  
  CactusVLM._();

  static Future<CactusVLM> init({
    required String modelUrl,
    required String visionUrl,
    String? modelFilename,
    String? visionFilename,
    String? chatTemplate,
    int contextSize = 2048,
    int gpuLayers = 0,
    int threads = 4,
    CactusProgressCallback? onProgress,
  }) async {
    final vlm = CactusVLM._();
    
    vlm._context = await CactusContext.init(CactusInitParams(
      modelUrl: modelUrl,
      modelFilename: modelFilename,
      mmprojUrl: visionUrl,
      mmprojFilename: visionFilename,
      chatTemplate: chatTemplate,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      threads: threads,
      onInitProgress: onProgress,
    ));
    
    return vlm;
  }

  Future<CactusResult> completion(
    List<ChatMessage> messages, {
    List<String> imagePaths = const [],
    int maxTokens = 256,
    double? temperature,
    int? topK,
    double? topP,
    List<String>? stopSequences,
    CactusTokenCallback? onToken,
    Tools? tools,
  }) async {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    
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
      mediaPaths: imagePaths,
      tools: tools,
    );
  }

  bool get supportsVision {
    if (_context == null) return false;
    return _context!.supportsVision();
  }

  bool get supportsAudio {
    if (_context == null) return false;
    return _context!.supportsAudio();
  }

  bool get isMultimodalEnabled {
    if (_context == null) return false;
    return _context!.isMultimodalEnabled();
  }

  List<int> tokenize(String text) {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    return _context!.tokenize(text);
  }

  String detokenize(List<int> tokens) {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    return _context!.detokenize(tokens);
  }

  void applyLoraAdapters(List<LoraAdapterInfo> adapters) {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    _context!.applyLoraAdapters(adapters);
  }

  void removeLoraAdapters() {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    _context!.removeLoraAdapters();
  }

  List<LoraAdapterInfo> getLoadedLoraAdapters() {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    return _context!.getLoadedLoraAdapters();
  }

  void rewind() {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    _context!.rewind();
  }

  void stopCompletion() {
    if (_context == null) throw CactusException('CactusVLM not initialized');
    _context!.stopCompletion();
  }

  void dispose() {
    _context?.release();
    _context = null;
  }
} 