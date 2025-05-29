import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../utils/timer.dart';
import '../services/inference.dart';
import '../widgets/debug_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCapturing = false;
  bool _showDebug = false;
  String _analysisResult = '';
  bool _isNewAnalysisSession = true; // Flag to track new analysis session
  final CameraService _cameraService = CameraService();
  final InferenceService _inferenceService = InferenceService();

  @override
  void initState() {
    super.initState();
    timer.log('Starting app initialization');
    _initializeServices();
    timer.log('App initialization complete');
  }

  Future<void> _initializeServices() async {
    await _cameraService.initialize(initialCameraIndex: 0);
    if (mounted) {
      setState(() {});
    }
    timer.log('Camera initialized');
    await _inferenceService.initialize();
    _inferenceService.onCompleteResult = (result) {
      if (mounted) { // Ensure widget is still in the tree
        setState(() {
          _analysisResult = result;
          _isNewAnalysisSession = true; // Prepare for the next session
        });
      }
    };
    _inferenceService.onPartialResult = (result) {
      if (mounted) { // Ensure widget is still in the tree
        setState(() {
          if (_isNewAnalysisSession) {
            _analysisResult = ''; // Clear previous result on first partial token
            _isNewAnalysisSession = false; // Subsequent partials for this session will append
          }
          _analysisResult += result;
        });
      }
    };
    timer.log('Inference initialized');
  }

  @override
  void dispose() {
    _cameraService.dispose();
    timer.log('Camera disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus CCTV',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            Column(
          children: [
            Expanded(
              flex: 75,
              child: _cameraService.controller?.value.isInitialized == true
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraService.controller!.value.previewSize!.height,
                          height: _cameraService.controller!.value.previewSize!.width,
                          child: CameraPreview(_cameraService.controller!),
                        ),
                      ),
                      Positioned(
                        bottom: 16.0,
                        right: 16.0,
                        child: FloatingActionButton.small(
                          onPressed: () async {
                            if (!_cameraService.isReady || _cameraService.controller == null) {
                               print("Camera service not fully ready or no controller available to flip.");
                               return;
                            }
                            await _cameraService.flipCamera();
                            if (mounted) {
                              setState(() {}); 
                            }
                          },
                          backgroundColor: Colors.black.withValues(alpha: .5),
                          child: Icon(Icons.flip_camera_ios, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : const Center(child: Text('No camera')),
            ),
            
            Expanded(
              flex: 25, // 25% of available height
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.black87,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Camera Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _analysisResult,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                        Row(
                          children: [
                    _isCapturing
                    ? FloatingActionButton.small(
                      onPressed: () async {
                        await _cameraService.endCapture();
                        setState(() => _isCapturing = !_isCapturing);
                      },
                      backgroundColor: Colors.red,
                      child: Icon(Icons.stop),
                    )
                    : FloatingActionButton.small(
                      onPressed: () async {
                        setState(() {
                          _isCapturing = true;
                          _isNewAnalysisSession = true; // Mark start of a new analysis session
                        });
                        await _cameraService.beginCapture(_inferenceService.analyzeFrame);
                      },
                      backgroundColor: Colors.green,
                      child: Icon(Icons.play_arrow),
                            ),
                            SizedBox(width: 8),
                            FloatingActionButton.small(
                              onPressed: () => setState(() => _showDebug = !_showDebug),
                              backgroundColor: _showDebug ? Colors.blue : Colors.grey,
                              child: Icon(Icons.bug_report),
                            ),
                          ],
                    ),
                  ],
                ),
                  ),
                ),
              ],
            ),
            if (_showDebug && _inferenceService.getLastProcessedImage() != null)
              Positioned(
                top: 20,
                right: 20,
                child: DebugOverlay(
                  imageFile: _inferenceService.getLastProcessedImage(),
                  stats: "Frame size: ${_inferenceService.getLastProcessedImage()!.lengthSync() ~/ 1024}KB",
              ),
            ),
          ],
        ),
      ),
    );
  }
} 