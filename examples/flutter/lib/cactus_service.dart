import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cactus/cactus.dart';

class CactusService {
  CactusContext? _cactusContext;

  // ValueNotifiers for UI updates
  final ValueNotifier<List<ChatMessage>> chatMessages = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<bool> isBenchmarking = ValueNotifier(false);
  final ValueNotifier<String> statusMessage = ValueNotifier('Initializing...');
  final ValueNotifier<String?> initError = ValueNotifier(null);
  final ValueNotifier<double?> downloadProgress = ValueNotifier(null);
  final ValueNotifier<BenchResult?> benchResult = ValueNotifier(null);
  final ValueNotifier<String?> imagePathForNextMessage = ValueNotifier(null);
  final ValueNotifier<String?> stagedAssetPath = ValueNotifier(null); // For image picker display
  


  Future<void> initialize() async {
    isLoading.value = true;
    initError.value = null;
    statusMessage.value = 'Initializing plugin...';
    downloadProgress.value = null; 

    // Cactus usage 
    try {
      final params = CactusInitParams(
        modelUrl: 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf',
        mmprojUrl: 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf',

        onInitProgress: (progress, status, isError) {
          statusMessage.value = status; 
          downloadProgress.value = progress; 

          if (isError) {
            initError.value = status;
            isLoading.value = false;
          }
        },
      );

      _cactusContext = await CactusContext.init(params);
      
      if (initError.value == null) { 
        isLoading.value = false;
        statusMessage.value = 'Cactus initialized successfully!';
        await runBenchmark();
      } else {
        statusMessage.value = 'Initialization failed: ${initError.value}';
      }

    } on CactusException catch (e) {
      initError.value = "Initialization Error: ${e.message}";
      statusMessage.value = 'Failed to initialize context: ${e.message}';
      isLoading.value = false;
      debugPrint("Cactus Initialization Exception: ${e.toString()}");
    } catch (e) {
      initError.value ??= "An unexpected error occurred: ${e.toString()}";
      statusMessage.value = 'Initialization failed: ${initError.value}';
      isLoading.value = false;
      debugPrint("Generic Exception during Cactus Init: ${e.toString()}");
    }
  }

  Future<void> sendMessage(String message) async {
    if (_cactusContext == null || isLoading.value) return;

    isLoading.value = true;
    statusMessage.value = 'Generating response...';

    final userMessage = ChatMessage(role: 'user', content: message);
    chatMessages.value = [...chatMessages.value, userMessage, ChatMessage(role: 'assistant', content: '')];

    final stopwatch = Stopwatch()..start();
    int? ttft;
    String streaming = '';

    try {
      CactusCompletionResult result;
      
      // Check if we have a staged image
      if (imagePathForNextMessage.value != null) {
        // Use multimodal completion with image
        final params = CactusCompletionParams(
          messages: [ChatMessage(role: 'user', content: message)],
          maxPredictedTokens: 250,
          temperature: 0.7,
          onNewToken: (tok) {
            if (tok == '<|im_end|>' || tok == '</s>') return false;
            ttft ??= stopwatch.elapsedMilliseconds;
            if (tok.isNotEmpty) {
              streaming += tok;
              final msgs = List<ChatMessage>.from(chatMessages.value);
              msgs[msgs.length - 1] = ChatMessage(role: 'assistant', content: streaming);
              chatMessages.value = msgs;
            }
            return true;
          },
        );
        
        result = await _cactusContext!.completion(
          params,
          mediaPaths: [imagePathForNextMessage.value!],
        );
        
        // Clear the staged image after use
        clearStagedImage();
      } else {
        // Use regular conversation continuation
        final firstTurn = chatMessages.value.where((m) => m.role == 'user').length == 1;
        
        result = await _cactusContext!.continueConversation(
          message,
          firstTurn: firstTurn,
          maxPredictedTokens: 250,
          temperature: 0.7,
          onNewToken: (tok) {
            if (tok == '<|im_end|>' || tok == '</s>') return false;
            ttft ??= stopwatch.elapsedMilliseconds;
            if (tok.isNotEmpty) {
              streaming += tok;
              final msgs = List<ChatMessage>.from(chatMessages.value);
              msgs[msgs.length - 1] = ChatMessage(role: 'assistant', content: streaming);
              chatMessages.value = msgs;
            }
            return true;
          },
        );
      }

      stopwatch.stop();
      final total = stopwatch.elapsedMilliseconds;
      final tokens = result.tokensPredicted;
      final tps = tokens > 0 && total > 0 ? tokens * 1000 / total : 0;
      debugPrint('[PERF] TTFT:${ttft ?? 'N/A'}ms total:$total tokens:$tokens speed:${tps.toStringAsFixed(1)}');

      final text = result.text.trim().isEmpty ? streaming.trim() : result.text.trim();
      final msgs = List<ChatMessage>.from(chatMessages.value);
      msgs[msgs.length - 1] = ChatMessage(role: 'assistant', content: text.isEmpty ? '(No response generated)' : text);
      chatMessages.value = msgs;

    } on CactusException catch (e) {
      _addErrorMessageToChat(e.message);
    } finally {
      isLoading.value = false;
    }
  }

  void _addErrorMessageToChat(String errorMessage) {
      final List<ChatMessage> errorMessages = List.from(chatMessages.value);
      if (errorMessages.isNotEmpty && errorMessages.last.role == 'assistant') {
        errorMessages[errorMessages.length - 1] = ChatMessage(
          role: 'assistant',
          content: errorMessage,
        );
      } else {
        errorMessages.add(ChatMessage(role: 'system', content: errorMessage));
      }
      chatMessages.value = errorMessages;
  }

  Future<void> runBenchmark() async {
    if (_cactusContext == null) return;
    isBenchmarking.value = true;
    statusMessage.value = 'Running benchmark...';
    try {
      final result = _cactusContext!.bench();
      benchResult.value = result;
      statusMessage.value = 'Benchmark complete.';
    } catch (e) {
      debugPrint("Benchmark Error: ${e.toString()}");
      statusMessage.value = 'Benchmark failed: ${e.toString()}';
    } finally {
      isBenchmarking.value = false;
    }
  }

  void stageImageFromAsset(String assetPath, String tempFilename) async {
      try {
        final ByteData assetData = await rootBundle.load(assetPath); 
        final Directory tempDir = await getTemporaryDirectory();
        final String tempFilePath = '${tempDir.path}/$tempFilename'; 
        final File tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(assetData.buffer.asUint8List(), flush: true);
        imagePathForNextMessage.value = tempFilePath;
        stagedAssetPath.value = assetPath;
      } catch (e) {
        debugPrint("Error staging image from asset: $e");
        statusMessage.value = "Error staging image: $e";
      }
  }

  void clearStagedImage() {
    imagePathForNextMessage.value = null;
    stagedAssetPath.value = null;
  }

  void clearConversation() {
    chatMessages.value = [];
    if (_cactusContext != null) {
      try {
        _cactusContext!.rewind();
        debugPrint("Native conversation state cleared via rewind()");
      } catch (e) {
        debugPrint("Error clearing native state: $e");
      }
    }
    debugPrint("Conversation history cleared");
  }

  void dispose() {
    _cactusContext?.release();
    chatMessages.dispose();
    isLoading.dispose();
    isBenchmarking.dispose();
    statusMessage.dispose();
    initError.dispose();
    downloadProgress.dispose();
    benchResult.dispose();
    imagePathForNextMessage.dispose();
    stagedAssetPath.dispose();
  }
} 