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
  
  bool _lastInteractionWasMultimodal = false;

  Future<void> initialize() async {
    isLoading.value = true;
    initError.value = null;
    statusMessage.value = 'Initializing plugin...';
    downloadProgress.value = null; 

    // Cactus usage 
    try {
      final params = CactusInitParams(
        modelUrl: 'https://huggingface.co/QuantFactory/SmolLM-360M-Instruct-GGUF/resolve/main/SmolLM-360M-Instruct.Q6_K.gguf',

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

    } on CactusInitializationException catch (e) {
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

  Future<void> sendMessage(String userInput) async {
    if (_cactusContext == null) {
      chatMessages.value = [...chatMessages.value, ChatMessage(role: 'system', content: 'Error: CactusContext not initialized.')];
      return;
    }

    final userMessage = ChatMessage(role: 'user', content: userInput);
    final String? imagePathToSend = imagePathForNextMessage.value;
    final bool isCurrentlyMultimodal = imagePathToSend != null;

    imagePathForNextMessage.value = null;
    stagedAssetPath.value = null;

    if (_lastInteractionWasMultimodal != isCurrentlyMultimodal) {
      debugPrint("Mode switch: ${_lastInteractionWasMultimodal ? 'multimodal' : 'text'} -> ${isCurrentlyMultimodal ? 'multimodal' : 'text'}, clearing conversation state");
      chatMessages.value = [];
    }
    _lastInteractionWasMultimodal = isCurrentlyMultimodal;

    List<ChatMessage> workingHistory = List.from(chatMessages.value);
    workingHistory.add(userMessage);
    workingHistory.add(ChatMessage(role: 'assistant', content: ''));
    chatMessages.value = workingHistory;
    isLoading.value = true;

    String currentAssistantResponse = "";
    final stopwatch = Stopwatch()..start();
    int? ttft;

    try {
      List<ChatMessage> messagesToSend;
      if (chatMessages.value.length <= 2) { // First turn (user + assistant placeholder)
          messagesToSend = List.from(chatMessages.value);
          if (messagesToSend.isNotEmpty && messagesToSend.last.role == 'assistant') {
            messagesToSend.removeLast(); // Don't send placeholder
          }
      } else {
          // Subsequent turns, only send the latest user message.
          messagesToSend = [userMessage];
      }
      
      final completionParams = CactusCompletionParams(
        messages: messagesToSend,
        maxPredictedTokens: 256,
        stopSequences: ['<|im_end|>', '</s>'],
        temperature: 0.7,
        onNewToken: (String token) {
          if (!isLoading.value) return false; 
          if (ttft == null) {
            ttft = stopwatch.elapsedMilliseconds;
          }
          if (token == '<|im_end|>' || token == '</s>') return false;

          if (token.isNotEmpty) {
            currentAssistantResponse += token;
            final List<ChatMessage> streamingMessages = List.from(chatMessages.value);
            if (streamingMessages.isNotEmpty && streamingMessages.last.role == 'assistant') {
              streamingMessages[streamingMessages.length - 1] = ChatMessage(
                role: 'assistant',
                content: currentAssistantResponse,
              );
              chatMessages.value = streamingMessages;
            }
          }
          return true;
        },
      );

      final CactusCompletionResult result;
      if (isCurrentlyMultimodal) {
        debugPrint("Using multimodal completion");
        result = await _cactusContext!.multimodalCompletion(completionParams, [imagePathToSend!]);
      } else {
        debugPrint("Using text completion");
        result = await _cactusContext!.completion(completionParams);
      }
      
      stopwatch.stop();

      // Performance logging
      final totalTime = stopwatch.elapsedMilliseconds;
      final tokensGenerated = result.tokensPredicted;
      final tps = (tokensGenerated > 0 && totalTime > 0) ? (tokensGenerated * 1000.0 / totalTime) : 0.0;
      debugPrint("[PERFORMANCE] TTFT: ${ttft ?? 'N/A'}ms, "
                 "Total: ${totalTime}ms, "
                 "Tokens: $tokensGenerated, "
                 "Speed: ${tps.toStringAsFixed(1)} tok/s");

      // Update UI with final result
      String finalCleanText = result.text.trim();
      if (finalCleanText.isEmpty && currentAssistantResponse.trim().isNotEmpty) {
        finalCleanText = currentAssistantResponse.trim();
      }

      final List<ChatMessage> finalMessages = List.from(chatMessages.value);
      if (finalMessages.isNotEmpty && finalMessages.last.role == 'assistant') {
        finalMessages[finalMessages.length - 1] = ChatMessage(
          role: 'assistant',
          content: finalCleanText.isNotEmpty ? finalCleanText : "(No response generated)",
        );
        chatMessages.value = finalMessages;
      }

    } on CactusCompletionException catch (e) {
      _addErrorMessageToChat("Completion Error: ${e.message}");
      debugPrint("Cactus Completion Exception: ${e.toString()}");
    } catch (e) {
      _addErrorMessageToChat("An unexpected error occurred during completion: ${e.toString()}");
      debugPrint("Generic Exception during completion: ${e.toString()}");
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
        final ByteData assetData = await rootBundle.load(assetPath); // Requires services.dart
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
    _lastInteractionWasMultimodal = false;
    debugPrint("Conversation history cleared, interaction mode reset");
  }

  void dispose() {
    _cactusContext?.free();
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