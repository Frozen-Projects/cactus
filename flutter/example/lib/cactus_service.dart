import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cactus/cactus.dart';

class CactusService {
  CactusVLM? model;
  
  final ValueNotifier<List<ChatMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<String> status = ValueNotifier('Initializing...');
  final ValueNotifier<String?> error = ValueNotifier(null);
  
  String? _stagedImagePath;

  Future<void> initialize() async {
    try {
      model = await CactusVLM.init(
        modelUrl: 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf',
        visionUrl: 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf',
        onProgress: (progress, statusText, isError) {
          status.value = statusText;
          if (isError) error.value = statusText;
        },
      );
      
      status.value = 'Ready!';
      isLoading.value = false;
    } on CactusException catch (e) {
      error.value = e.message;
      isLoading.value = false;
    }
  }

  Future<void> sendMessage(String text) async {
    if (model == null) return;
    
    isLoading.value = true;
    
    final userMsg = ChatMessage(role: 'user', content: text);
    messages.value = [...messages.value, userMsg, ChatMessage(role: 'assistant', content: '')];
    
    final stopwatch = Stopwatch()..start();
    int? ttft;
    String response = '';
    
    try {
      final result = await model!.completion(
        messages.value.where((m) => m.content.isNotEmpty).toList(),
        imagePaths: _stagedImagePath != null ? [_stagedImagePath!] : [],
        maxTokens: 200,
        onToken: (token) {
          if (token == '<|im_end|>' || token == '</s>') return false;
          ttft ??= stopwatch.elapsedMilliseconds;
          response += token;
          _updateLastMessage(response);
          return true;
        },
      );
      
      stopwatch.stop();
      final totalMs = stopwatch.elapsedMilliseconds;
      final tokens = result.tokensPredicted;
      final tps = tokens > 0 && totalMs > 0 ? tokens * 1000 / totalMs : 0;
      
      debugPrint('[PERF] TTFT: ${ttft ?? 'N/A'}ms | Total: ${totalMs}ms | Tokens: $tokens | Speed: ${tps.toStringAsFixed(1)} tok/s');
      
      _updateLastMessage(result.text.isNotEmpty ? result.text : response);
      _stagedImagePath = null;
      
    } on CactusException catch (e) {
      _updateLastMessage('Error: ${e.message}');
    }
    
    isLoading.value = false;
  }
  
  void _updateLastMessage(String content) {
    final msgs = List<ChatMessage>.from(messages.value);
    if (msgs.isNotEmpty && msgs.last.role == 'assistant') {
      msgs[msgs.length - 1] = ChatMessage(role: 'assistant', content: content);
      messages.value = msgs;
    }
  }

  Future<void> addImage() async {
    final assetData = await rootBundle.load('assets/image.jpg');
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/demo_image.jpg');
    await file.writeAsBytes(assetData.buffer.asUint8List());
    _stagedImagePath = file.path;
  }

  void clearConversation() {
    messages.value = [];
    model?.rewind();
  }

  void dispose() {
    model?.dispose();
    messages.dispose();
    isLoading.dispose();
    status.dispose();
    error.dispose();
  }
} 