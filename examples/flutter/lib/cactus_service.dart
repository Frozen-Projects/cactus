import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cactus/cactus.dart';

class CactusService {
  CactusContext? _context;
  
  final ValueNotifier<List<ChatMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<String> status = ValueNotifier('Initializing...');
  final ValueNotifier<String?> error = ValueNotifier(null);
  
  String? _stagedImagePath;

  Future<void> initialize() async {
    try {
      _context = await CactusContext.init(CactusInitParams(
        modelUrl: 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf',
        mmprojUrl: 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf',
        onInitProgress: (progress, statusText, isError) {
          status.value = statusText;
          if (isError) error.value = statusText;
        },
      ));
      
      status.value = 'Ready!';
      isLoading.value = false;
    } on CactusException catch (e) {
      error.value = e.message;
      isLoading.value = false;
    }
  }

  Future<void> sendMessage(String text) async {
    if (_context == null) return;
    
    isLoading.value = true;
    
    // Add user message
    final userMsg = ChatMessage(role: 'user', content: text);
    messages.value = [...messages.value, userMsg, ChatMessage(role: 'assistant', content: '')];
    
    try {
      String response = '';
      
      final result = await _context!.completion(
        CactusCompletionParams(
          messages: messages.value.where((m) => m.content.isNotEmpty).toList(),
          maxPredictedTokens: 200,
          onNewToken: (token) {
            response += token;
            _updateLastMessage(response);
            return true;
          },
        ),
        mediaPaths: _stagedImagePath != null ? [_stagedImagePath!] : [],
      );
      
      _updateLastMessage(result.text.isNotEmpty ? result.text : response);
      _stagedImagePath = null; // Clear after use
      
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
    _context?.rewind();
  }

  void dispose() {
    _context?.release();
    messages.dispose();
    isLoading.dispose();
    status.dispose();
    error.dispose();
  }
} 