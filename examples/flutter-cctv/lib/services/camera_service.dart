import 'package:camera/camera.dart';

class CameraService {
  late CameraController _controller;
  List<CameraDescription> _cameras = [];
  bool _ready = false;
  int _currentCameraIndex = 0;
  Function(CameraImage image)? _lastOnImageCaptured;
  
  CameraController? get controller => _ready ? _controller : null;
  bool get isReady => _ready;
  
  Future<void> initialize({int initialCameraIndex = 0}) async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    
    _controller = CameraController(
      _cameras[_currentCameraIndex], 
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888
    );
    await _controller.initialize();
    _ready = true;
  }

  Future<void> flipCamera() async {
    _ready = false;
    _currentCameraIndex = (_currentCameraIndex + 1) % 2;
    await initialize();
    _ready = true;
  }

  Future<void> beginCapture(Function(CameraImage image) onImageCaptured) async {
    await _controller.startImageStream((image) {
      onImageCaptured(image);
    });
  }

  Future<void> endCapture() async {
    await _controller.stopImageStream();
  }
  
  void dispose() {
    _controller.dispose();
  }
} 