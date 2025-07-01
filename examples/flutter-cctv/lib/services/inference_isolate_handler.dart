import 'package:cactus/cactus.dart';
import 'dart:isolate';
import 'cactus_initializer.dart';
import 'package:flutter/services.dart'; // Import this for ServicesBinding

void inferenceIsolateEntry(Map<String, dynamic> message) async {
  final SendPort mainSendPort = message['sendPort'] as SendPort;
  final RootIsolateToken rootToken = message['rootToken'] as RootIsolateToken;

  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

  final ReceivePort isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort); // Send its SendPort to main

  CactusContext? _cactusContext;

  try {
    print('[Isolate] Initializing Cactus model...');
    // You'll need to handle how 'onStatus' logging works from an isolate.
    // It could send log messages back to the main isolate or use simple print for dev.
    _cactusContext = await CactusInit.init(onStatus: (log) => print('[Isolate Init] $log'));
    print('[Isolate] Cactus model initialized successfully.');
    mainSendPort.send({'type': 'INITIALIZED'}); // Notify main isolate of success
  } catch (e, s) {
    print('[Isolate] FATAL: Error initializing Cactus model: $e\n$s');
    mainSendPort.send({'type': 'ERROR_INIT', 'error': e.toString(), 'stack': s.toString()});
    Isolate.exit(); // Exit if model initialization fails
  }

  await for (final dynamic message in isolateReceivePort) {
    if (message is Map<String, dynamic>) { // Expecting a map with data
      final String imagePath = message['imagePath'] as String;
      print('[Isolate] Received image path for inference: $imagePath');

      if (_cactusContext == null) {
        mainSendPort.send({'type': 'ERROR', 'message': 'Model not ready in isolate.'});
        continue;
      }

      try {
        print('Isolate received: $message');
        // TODO: Implement inference

        final CactusCompletionParams completionParams = CactusCompletionParams(
          messages: [
            ChatMessage(role: 'system', content: 'Your job is to provide very short, concise, succinct descriptions of what you see in the image. Provide the description directly; do not start with "Here is what I see" or anything like that. Just give the description.'),
            ChatMessage(role: 'user', content: '<__image__>What do you see?'),
          ],
          imagePath: imagePath,
          maxPredictedTokens: 50,
          stopSequences: ['<end_of_utterance>'],
          onNewToken: (token) {
            mainSendPort.send({'type': 'INFERENCE_PARTIAL', 'data': token});
            return true;
          }
        );

        final result = await _cactusContext!.completion(
          completionParams,
        );
        print('Inference complete: ${result.text}');

        mainSendPort.send({'type': 'INFERENCE_COMPLETE', 'data': result.text});
      } catch (e, s) {
        print('[Isolate] FATAL: Error processing message: $e\n$s');
        mainSendPort.send({'type': 'ERROR_INFERENCE', 'error': e.toString(), 'stack': s.toString()});
      }
    } else if (message == 'CLOSE') {
      isolateReceivePort.close();
      break;
    }
  }
  print('[Isolate] Exiting isolate...');
  Isolate.exit(); // Important to exit the isolate properly
}