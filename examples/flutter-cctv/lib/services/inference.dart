import 'package:camera/camera.dart';
import '../utils/timer.dart';
import 'image_converter.dart';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'inference_isolate_handler.dart';
import 'package:flutter/services.dart';

class InferenceService {
  Isolate? _inferenceIsolate;
  SendPort? _isolateSendPort;
  final ReceivePort _mainReceivePort = ReceivePort();
  Function(String)? onCompleteResult;
  Function(String)? onPartialResult;

  bool _isFirstPartialResult = true;
  bool _isProcessing = false;
  bool _isIsolateReady = false;
  
  final int _framesToSkip = 0;
  int _frameCount = 0;

  File? _lastProcessedImageFile;

  get isProcessing => _isProcessing;
  File? getLastProcessedImage() => _lastProcessedImageFile;

  /// Initialize the Cactus framework
  Future<void> initialize() async {
    if (_inferenceIsolate != null) return; // Already initialized

    final RootIsolateToken? rootToken = RootIsolateToken.instance;
    if (rootToken == null) {
      timer.log('[Main] CRITICAL: RootIsolateToken is null. Cannot spawn isolate correctly.');
      return;
    }

    final Map<String, dynamic> isolateArgs = {
      'sendPort': _mainReceivePort.sendPort,
      'rootToken': rootToken,
    };

    timer.log('[Main] Spawning inference isolate...');
    _inferenceIsolate = await Isolate.spawn(
      inferenceIsolateEntry, // Correct entry point
      isolateArgs,
      onError: _mainReceivePort.sendPort,
      onExit: _mainReceivePort.sendPort,
      debugName: "InferenceIsolate"
    );

    _mainReceivePort.listen((dynamic message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        print('InferenceService: Isolate SendPort received.');
      } else if (message is Map<String, dynamic>) {
        final type = message['type'];
        if (type == 'INITIALIZED') {
          _isIsolateReady = true;
          timer.log('[Main] Inference isolate reported: MODEL INITIALIZED.');
        } else if (type == 'INFERENCE_COMPLETE') {
          final String resultData = message['data'] as String;
          timer.log('Received inference result from isolate: $resultData');
          onCompleteResult?.call(resultData);
          _isFirstPartialResult = true;
          _isProcessing = false; // Ready for next frame
        } else if (type == 'INFERENCE_PARTIAL') {
          final String resultData = message['data'] as String;
          onPartialResult?.call(resultData);
        } else if (type.contains('ERROR')) {
          if(type == 'ERROR_INIT') _isIsolateReady = false; // Model init failed
          final String errorMsg = message['error']?.toString() ?? message['message']?.toString() ?? 'Unknown error';
          timer.log('Error from isolate: $errorMsg');
          _isProcessing = false; // Reset processing flag
        }
      } else if (message == null) {
        print('[Main] Inference isolate exited.');
        _isIsolateReady = false;
        _inferenceIsolate = null; // Clear the isolate instance
      } else {
        print('[Main] Received unknown message from isolate: $message');
      }
    });
  }

  Future<File> convertImageToFile(CameraImage image) async {
    final tempDir = await getTemporaryDirectory();
    final imagePath = ImageConverter.getUniqueImagePath(tempDir.path);
    return await ImageConverter.convertImageToFile(image, imagePath);
  }

  Future<void> analyzeFrame(CameraImage image) async {
    if (!_isIsolateReady || _isolateSendPort == null) {
      // timer.log('Skipping frame: isolate not ready for inference.');
      return;
    }

    if (_isProcessing) {
      // timer.log('Skipping frame: inference in progress');
      return;
    }

    if (_frameCount < _framesToSkip) {
      _frameCount++;
      // timer.log('Skipping frame $_frameCount');
      return;
    }

    _isProcessing = true;
    _frameCount = 0;

    try {
      final imageFile = await convertImageToFile(image);
      _lastProcessedImageFile = imageFile;
      timer.log('Image converted and saved (${imageFile.lengthSync() / 1024 / 1024} Mb)');

      _isolateSendPort!.send({'imagePath': imageFile.path});
    } catch (e, s) {
      timer.log('Error analyzing frame: $e\n$s');
      _isProcessing = false;
    }

  }

  void dispose() {
    print('[Main] Disposing InferenceService.');
    _isolateSendPort?.send('CLOSE'); // Gracefully ask isolate to close
    _mainReceivePort.close(); // Close main isolate's port
    // Give it a moment to close, then kill if necessary, though Isolate.exit() should handle it.
    Future.delayed(Duration(milliseconds: 500), () {
       _inferenceIsolate?.kill(priority: Isolate.immediate);
       _inferenceIsolate = null;
    });
    _isIsolateReady = false;
  }
}