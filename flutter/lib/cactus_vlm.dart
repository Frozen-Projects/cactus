import 'dart:async';

import './types.dart';
import './tools.dart';
import './cactus_context.dart';
import './cactus_telemetry.dart';

class CactusVLM {
  CactusContext? _context;
  CactusInitParams? _initParams;
  
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
    
    final initParams = CactusInitParams(
      modelUrl: modelUrl,
      modelFilename: modelFilename,
      mmprojUrl: visionUrl,
      mmprojFilename: visionFilename,
      chatTemplate: chatTemplate,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      threads: threads,
      onInitProgress: onProgress,
    );
    
    try {
      vlm._context = await CactusContext.init(initParams);
      vlm._initParams = initParams;
    } catch (e) {
      CactusTelemetry.error(e, initParams);
      rethrow;
    }
    
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
    
    final startTime = DateTime.now();
    bool firstTokenReceived = false;
    DateTime? firstTokenTime;
    
    // Wrap the callback to capture first token timing
    CactusTokenCallback? wrappedCallback;
    if (onToken != null) {
      wrappedCallback = (String token) {
        if (!firstTokenReceived) {
          firstTokenTime = DateTime.now();
          firstTokenReceived = true;
        }
        return onToken(token);
      };
    }
    
    final result = await _context!.completion(
      CactusCompletionParams(
        messages: messages,
        maxPredictedTokens: maxTokens,
        temperature: temperature,
        topK: topK,
        topP: topP,
        stopSequences: stopSequences,
        onNewToken: wrappedCallback,
      ),
      mediaPaths: imagePaths,
      tools: tools,
    );
    
    // Track telemetry after completion
    if (_initParams != null) {
      final endTime = DateTime.now();
      final totalTime = endTime.difference(startTime).inMilliseconds;
      final tokPerSec = totalTime > 0 ? (result.tokensPredicted * 1000.0) / totalTime : null;
      final ttft = firstTokenTime != null ? firstTokenTime!.difference(startTime).inMilliseconds : null;
      
      CactusTelemetry.track({
        'event': 'completion',
        'tok_per_sec': tokPerSec,
        'toks_generated': result.tokensPredicted,
        'ttft': ttft,
        'num_images': imagePaths.length,
      }, _initParams!);
    }
    
    return result;
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