import 'dart:io';
import 'dart:convert';
import './types.dart';

class TelemetryRecord {
  final String os;
  final String osVersion;
  final String framework;
  // final String frameworkVersion; // commented out until we have a way to dynamically reference the package version
  final Map<String, dynamic>? telemetryPayload;
  final Map<String, dynamic>? errorPayload;
  final String timestamp;
  final String modelFilename;
  final int? nCtx;
  final int? nGpuLayers;

  TelemetryRecord({
    required this.os,
    required this.osVersion,
    required this.framework,
    // required this.frameworkVersion,
    this.telemetryPayload,
    this.errorPayload,
    required this.timestamp,
    required this.modelFilename,
    this.nCtx,
    this.nGpuLayers,
  });

  Map<String, dynamic> toJson() {
    return {
      'os': os,
      'os_version': osVersion,
      'framework': framework,
      // 'framework_version': frameworkVersion,
      if (telemetryPayload != null) 'telemetry_payload': telemetryPayload,
      if (errorPayload != null) 'error_payload': errorPayload,
      'timestamp': timestamp,
      'model_filename': modelFilename,
      if (nCtx != null) 'n_ctx': nCtx,
      if (nGpuLayers != null) 'n_gpu_layers': nGpuLayers,
    };
  }
}

class TelemetryConfig {
  final String supabaseUrl;
  final String supabaseKey;
  final String table;

  TelemetryConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    this.table = 'telemetry',
  });
}

class CactusTelemetry {
  static CactusTelemetry? _instance;
  late TelemetryConfig _config;

  CactusTelemetry._(this._config);

  static String _getFilename(String? path) {
    if (path == null || path.isEmpty) return 'unknown';
    try {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'unknown';
      }
      return path.split(Platform.pathSeparator).last;
    } catch (e) {
      return 'unknown';
    }
  }

  static void autoInit() {
    _instance ??= CactusTelemetry._(TelemetryConfig(
      supabaseUrl: 'https://vlqqczxwyaodtcdmdmlw.supabase.co',
      supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZscXFjenh3eWFvZHRjZG1kbWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MTg2MzIsImV4cCI6MjA2NzA5NDYzMn0.nBzqGuK9j6RZ6mOPWU2boAC_5H9XDs-fPpo5P3WZYbI',
    ));
  }

  static void init(TelemetryConfig config) {
    _instance ??= CactusTelemetry._(config);
  }

  static void track(Map<String, dynamic> payload, CactusInitParams options) {
    autoInit();
    _instance!._trackInternal(payload, options);
  }

  static void error(Object error, CactusInitParams options) {
    autoInit();
    _instance!._errorInternal(error, options);
  }

  void _trackInternal(Map<String, dynamic> payload, CactusInitParams options) {
    final record = TelemetryRecord(
      os: Platform.isIOS ? 'iOS' : 'Android',
      osVersion: Platform.operatingSystemVersion,
      framework: 'flutter',
      // frameworkVersion: null, 
      telemetryPayload: payload,
      timestamp: DateTime.now().toIso8601String(),
      modelFilename: _getFilename(options.modelPath ?? options.modelUrl),
      nCtx: options.contextSize,
      nGpuLayers: options.gpuLayers,
    );

    _sendRecord(record);
  }

  void _errorInternal(Object error, CactusInitParams options) {
    final errorPayload = {
      'message': error.toString(),
      'type': error.runtimeType.toString(),
      if (error is CactusException) 'underlying_error': error.underlyingError?.toString(),
    };

    final record = TelemetryRecord(
      os: Platform.isIOS ? 'iOS' : 'Android',
      osVersion: Platform.operatingSystemVersion,
      framework: 'flutter',
      // frameworkVersion: null, 
      errorPayload: errorPayload,
      timestamp: DateTime.now().toIso8601String(),
      modelFilename: _getFilename(options.modelPath ?? options.modelUrl),
      nCtx: options.contextSize,
      nGpuLayers: options.gpuLayers,
    );

    _sendRecord(record);
  }

  Future<void> _sendRecord(TelemetryRecord record) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('${_config.supabaseUrl}/rest/v1/${_config.table}');
      final request = await client.postUrl(uri);
      
      // Set headers
      request.headers.set('apikey', _config.supabaseKey);
      request.headers.set('Authorization', 'Bearer ${_config.supabaseKey}');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Prefer', 'return=minimal');
      
      // Write body
      final body = jsonEncode([record.toJson()]);
      request.write(body);
      
      // Send request and close
      final response = await request.close();
      await response.drain(); // Consume response to avoid resource leaks
      client.close();
    } catch (e) {
      // Silently fail to avoid disrupting user experience
    }
  }
} 