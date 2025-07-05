# Cactus Flutter

A powerful Flutter plugin for running Large Language Models (LLMs) and Vision Language Models (VLMs) directly on mobile devices, with full support for chat completions, multimodal inputs, embeddings, text-to-speech and advanced features.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cactus: ^0.1.4
```

Then run:
```bash
flutter pub get
```

**Platform Requirements:**
- **iOS**: iOS 12.0+, Xcode 14+
- **Android**: API level 24+, NDK support
- **Flutter**: 3.3.0+, Dart 3.0+

## Quick Start

### Basic Text Completion

```dart
import 'package:cactus/cactus.dart';

Future<String> basicCompletion() async {
  // Initialize language model
  final lm = await CactusLM.init(
    modelUrl: 'https://huggingface.co/Cactus-Compute/Qwen3-600m-Instruct-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf',
    contextSize: 2048,
    threads: 4,
  );

  // Generate response
  final result = await lm.completion([
    ChatMessage(role: 'user', content: 'Hello, how are you?')
  ], maxTokens: 100, temperature: 0.7);

  lm.dispose();
  return result.text;
}
```

### Complete Chat App Example

```dart
import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';

void main() => runApp(ChatApp());

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  CactusLM? _lm;
  List<ChatMessage> _messages = [];
  TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  @override
  void dispose() {
    _lm?.dispose();
    super.dispose();
  }

  Future<void> _initializeModel() async {
    try {
      // Initialize language model using a model URL.
      // The model will be downloaded and cached automatically.
      _lm = await CactusLM.init(
        modelUrl: 'https://huggingface.co/Cactus-Compute/Qwen3-600m-Instruct-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf',
        contextSize: 4096,
        threads: 4,
        gpuLayers: 99,
        onProgress: (progress, status, isError) {
          print('Init: $status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
          // You can update UI here, e.g., using setState or a ValueNotifier
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      print('Failed to initialize: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_lm == null || _controller.text.trim().isEmpty) return;

    final userMessage = ChatMessage(role: 'user', content: _controller.text.trim());
    setState(() {
      _messages.add(userMessage);
      _messages.add(ChatMessage(role: 'assistant', content: ''));
      _isGenerating = true;
    });

    _controller.clear();
    String currentResponse = '';

    try {
      final result = await _lm!.completion(
        List.from(_messages)..removeLast(), // Remove empty assistant message
        maxTokens: 256,
        temperature: 0.7,
        stopSequences: ['<|end|>', '</s>'],
        onToken: (token) {
          currentResponse += token;
          setState(() {
            _messages.last = ChatMessage(role: 'assistant', content: currentResponse);
          });
          return true; // Continue generation
        },
      );

      // Update with final response
      setState(() {
        _messages.last = ChatMessage(role: 'assistant', content: result.text.trim());
      });
    } catch (e) {
      setState(() {
        _messages.last = ChatMessage(role: 'assistant', content: 'Error: $e');
      });
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading model...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cactus Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () => setState(() => _messages.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: _isGenerating 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.send),
                  onPressed: _isGenerating ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

## Core APIs

### CactusLM (Language Model)

For text-only language models:

```dart
import 'package:cactus/cactus.dart';

// Initialize
final lm = await CactusLM.init(
  modelUrl: 'https://huggingface.co/Cactus-Compute/Qwen3-600m-Instruct-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf',
  contextSize: 4096,
  threads: 4,
  gpuLayers: 99, // GPU layers (0 = CPU only)
  generateEmbeddings: true, // Enable embeddings
);

// Text completion
final messages = [
  ChatMessage(role: 'system', content: 'You are a helpful assistant.'),
  ChatMessage(role: 'user', content: 'What is the capital of France?'),
];

final result = await lm.completion(
  messages,
  maxTokens: 200,
  temperature: 0.7,
  topP: 0.9,
  stopSequences: ['</s>', '\n\n'],
);

// Embeddings
final embeddingVector = lm.embedding('Your text here');
print('Embedding dimensions: ${embeddingVector.length}');

// Cleanup
lm.dispose();
```

### CactusVLM (Vision Language Model)

For multimodal models that can process both text and images:

```dart
import 'package:cactus/cactus.dart';

// Initialize with automatic model download
final vlm = await CactusVLM.init(
  modelUrl: 'https://huggingface.co/Cactus-Compute/Gemma3-4B-Instruct-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
  visionUrl: 'https://huggingface.co/Cactus-Compute/Gemma3-4B-Instruct-GGUF/resolve/main/mmproj-model-f16.gguf',
  contextSize: 2048,
  threads: 4,
  gpuLayers: 99,
);

// Image + text completion
final messages = [ChatMessage(role: 'user', content: 'What do you see in this image?')];

final result = await vlm.completion(
  messages,
  imagePaths: ['/path/to/image.jpg'],
  maxTokens: 200,
  temperature: 0.3,
);

// Text-only completion (same interface)
final textResult = await vlm.completion([
  ChatMessage(role: 'user', content: 'Tell me a joke')
], maxTokens: 100);

// Cleanup
vlm.dispose();
```

### CactusTTS (Text-to-Speech)

For text-to-speech generation:

```dart
import 'package:cactus/cactus.dart';

// Initialize with vocoder
final tts = await CactusTTS.init(
  modelUrl: 'https://example.com/tts-model.gguf',
  contextSize: 1024,
  threads: 4,
);

// Generate speech
final text = 'Hello, this is a test of text-to-speech functionality.';

final result = await tts.generate(
  text,
  maxTokens: 256,
  temperature: 0.7,
);

// Cleanup
tts.dispose();
```

## Text Completion

### Basic Generation

```dart
Future<String> generateText(CactusLM lm, String prompt) async {
  final result = await lm.completion([
    ChatMessage(role: 'user', content: prompt)
  ], maxTokens: 200, temperature: 0.8);
  
  return result.text;
}

// Usage
final response = await generateText(lm, 'Write a short poem about Flutter development');
print(response);
```

### Streaming Generation

```dart
class StreamingChatWidget extends StatefulWidget {
  final CactusLM lm;
  
  StreamingChatWidget({required this.lm});
  
  @override
  _StreamingChatWidgetState createState() => _StreamingChatWidgetState();
}

class _StreamingChatWidgetState extends State<StreamingChatWidget> {
  String _currentResponse = '';
  bool _isGenerating = false;

  Future<void> _generateStreaming(String prompt) async {
    setState(() {
      _currentResponse = '';
      _isGenerating = true;
    });

    try {
      await widget.lm.completion([
        ChatMessage(role: 'user', content: prompt)
      ], 
        maxTokens: 500,
        temperature: 0.7,
        onToken: (token) {
          setState(() {
            _currentResponse += token;
          });
          return true; // Continue generation
        },
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Text(
            _currentResponse.isEmpty ? 'No response yet' : _currentResponse,
            style: TextStyle(fontSize: 16),
          ),
        ),
        if (_isGenerating)
          LinearProgressIndicator(),
        ElevatedButton(
          onPressed: _isGenerating ? null : () => _generateStreaming('Tell me a story'),
          child: Text(_isGenerating ? 'Generating...' : 'Generate Story'),
        ),
      ],
    );
  }
}
```

### Advanced Parameter Control

```dart
class AdvancedCompletionService {
  final CactusLM lm;
  
  AdvancedCompletionService(this.lm);

  Future<CactusResult> creativeCompletion(List<ChatMessage> messages) async {
    return await lm.completion(
      messages,
      maxTokens: 512,
      
      // Creative settings
      temperature: 0.9,          // High randomness
      topK: 60,                  // Broader sampling
      topP: 0.95,               // More diverse outputs
      
      stopSequences: ['</story>', '<|end|>'],
    );
  }

  Future<CactusResult> factualCompletion(List<ChatMessage> messages) async {
    return await lm.completion(
      messages,
      maxTokens: 256,
      
      // Focused settings
      temperature: 0.3,          // Low randomness
      topK: 20,                  // Focused sampling
      topP: 0.8,                // Conservative
      
      stopSequences: ['\n\n', '<|end|>'],
    );
  }

  Future<CactusResult> codeCompletion(List<ChatMessage> messages) async {
    return await lm.completion(
      messages,
      maxTokens: 1024,
      
      // Code-optimized settings
      temperature: 0.1,          // Very focused
      topK: 10,                  // Narrow sampling
      topP: 0.7,                // Deterministic
      
      stopSequences: ['```', '\n\n\n'],
    );
  }
}
```

### Conversation Management

```dart
class ConversationManager {
  final CactusLM lm;
  final List<ChatMessage> _history = [];
  
  ConversationManager(this.lm);

  void addSystemMessage(String content) {
    _history.insert(0, ChatMessage(role: 'system', content: content));
  }

  Future<String> sendMessage(String userMessage) async {
    // Add user message
    _history.add(ChatMessage(role: 'user', content: userMessage));
    
    // Generate response
    final result = await lm.completion(
      _history,
      maxTokens: 256,
      temperature: 0.7,
      stopSequences: ['<|end|>', '</s>'],
    );
    
    // Add assistant response
    _history.add(ChatMessage(role: 'assistant', content: result.text));
    
    return result.text;
  }

  void clearHistory() {
    lm.rewind(); // Clear native conversation state
    _history.clear();
  }
  
  List<ChatMessage> get history => List.unmodifiable(_history);
  
  int get messageCount => _history.length;
  
  // Keep only recent messages to manage context size
  void trimHistory({int maxMessages = 20}) {
    if (_history.length > maxMessages) {
      // Keep system message (if first) and recent messages
      final systemMessages = _history.where((m) => m.role == 'system').take(1).toList();
      final recentMessages = _history.where((m) => m.role != 'system').toList();
      
      if (recentMessages.length > maxMessages - systemMessages.length) {
        recentMessages.removeRange(0, recentMessages.length - (maxMessages - systemMessages.length));
      }
      
      _history.clear();
      _history.addAll(systemMessages);
      _history.addAll(recentMessages);
      
      lm.rewind(); // Reset native state for new conversation
    }
  }
}

// Usage
final conversation = ConversationManager(lm);
conversation.addSystemMessage('You are a helpful coding assistant.');

final response1 = await conversation.sendMessage('How do I create a ListView in Flutter?');
final response2 = await conversation.sendMessage('Can you show me a code example?');

print('Conversation has ${conversation.messageCount} messages');
conversation.trimHistory(maxMessages: 10);
```

## Multimodal (Vision)

### Basic Image Analysis

```dart
class VisionAnalyzer {
  final CactusVLM vlm;
  
  VisionAnalyzer(this.vlm);

  Future<String> analyzeImage(String imagePath, String question) async {
    // Ensure multimodal is enabled
    if (!vlm.isMultimodalEnabled) {
      throw Exception('Multimodal support not initialized');
    }

    final result = await vlm.completion([
      ChatMessage(role: 'user', content: question),
    ], 
      imagePaths: [imagePath],
      maxTokens: 300,
      temperature: 0.3, // Lower temperature for more accurate descriptions
    );

    return result.text;
  }

  Future<String> describeImage(String imagePath) async {
    return await analyzeImage(
      imagePath,
      'Describe this image in detail. What do you see?'
    );
  }

  Future<String> answerImageQuestion(String imagePath, String question) async {
    return await analyzeImage(imagePath, question);
  }
}

// Usage
final analyzer = VisionAnalyzer(vlm);
final description = await analyzer.describeImage('/path/to/image.jpg');
final answer = await analyzer.answerImageQuestion(
  '/path/to/chart.png', 
  'What is the trend shown in this chart?'
);
```

### Complete Vision Chat App

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';
import 'package:image_picker/image_picker.dart';

class VisionChatScreen extends StatefulWidget {
  @override
  _VisionChatScreenState createState() => _VisionChatScreenState();
}

class _VisionChatScreenState extends State<VisionChatScreen> {
  CactusVLM? _vlm;
  List<ChatMessage> _messages = [];
  String? _selectedImagePath;
  bool _isLoading = true;
  bool _lastWasMultimodal = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  @override
  void dispose() {
    _vlm?.dispose();
    super.dispose();
  }

  Future<void> _initializeModel() async {
    try {
      _vlm = await CactusVLM.init(
        modelUrl: 'https://huggingface.co/Cactus-Compute/Gemma3-4B-Instruct-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
        visionUrl: 'https://huggingface.co/Cactus-Compute/Gemma3-4B-Instruct-GGUF/resolve/main/mmproj-model-f16.gguf',
        contextSize: 4096,
        onProgress: (progress, status, isError) {
          print('$status ${progress != null ? '${(progress * 100).toInt()}%' : ''}');
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      print('Failed to initialize vision model: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (_vlm == null) return;

    final isMultimodal = _selectedImagePath != null;
    
    // Clear history if switching modes (multimodal ↔ text)
    if (_lastWasMultimodal != isMultimodal) {
      setState(() {
        _messages.clear();
      });
      _vlm!.rewind(); // Reset native conversation state
    }
    _lastWasMultimodal = isMultimodal;

    // Add user message
    final userMessage = ChatMessage(role: 'user', content: text);
    setState(() {
      _messages.add(userMessage);
      _messages.add(ChatMessage(role: 'assistant', content: ''));
    });

    String currentResponse = '';

    try {
      CactusResult result;
      if (isMultimodal && _selectedImagePath != null) {
        result = await _vlm!.completion(
          List.from(_messages)..removeLast(),
          imagePaths: [_selectedImagePath!],
          maxTokens: 400,
          temperature: 0.3, // Lower temp for vision
          onToken: (token) {
            currentResponse += token;
            setState(() {
              _messages.last = ChatMessage(role: 'assistant', content: currentResponse);
            });
            return true;
          },
        );
      } else {
        result = await _vlm!.completion(
          List.from(_messages)..removeLast(),
          maxTokens: 400,
          temperature: 0.7,
          onToken: (token) {
            currentResponse += token;
            setState(() {
              _messages.last = ChatMessage(role: 'assistant', content: currentResponse);
            });
            return true;
          },
        );
      }

      setState(() {
        _messages.last = ChatMessage(role: 'assistant', content: result.text.trim());
        _selectedImagePath = null; // Clear image after use
      });

    } catch (e) {
      setState(() {
        _messages.last = ChatMessage(role: 'assistant', content: 'Error: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Vision Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              setState(() => _messages.clear());
              _vlm?.rewind();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected image preview
          if (_selectedImagePath != null)
            Container(
              height: 100,
              margin: EdgeInsets.all(8),
              child: Row(
                children: [
                  Image.file(
                    File(_selectedImagePath!),
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Image selected for next message'),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => setState(() => _selectedImagePath = null),
                  ),
                ],
              ),
            ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Input field
          _MessageInput(
            onSendMessage: _sendMessage,
            hasImage: _selectedImagePath != null,
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool hasImage;

  _MessageInput({required this.onSendMessage, required this.hasImage});

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.hasImage 
                  ? 'Ask about the image...'
                  : 'Type a message...',
                border: OutlineInputBorder(),
                prefixIcon: widget.hasImage ? Icon(Icons.image, color: Colors.blue) : null,
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  widget.onSendMessage(text.trim());
                  _controller.clear();
                }
              },
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isNotEmpty) {
                widget.onSendMessage(text);
                _controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

### Image Processing Utilities

> **Note**: The following example uses the [image](https://pub.dev/packages/image) package for image processing. You'll need to add it to your `pubspec.yaml` to run this code.

```dart
import 'dart:io';
import 'dart:convert';
import 'package:cactus/cactus.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  static Future<String> resizeImageIfNeeded(String imagePath) async {
    final file = File(imagePath);
    final image = img.decodeImage(await file.readAsBytes());
    
    if (image == null) throw Exception('Invalid image format');
    
    // Resize if too large (optional optimization)
    if (image.width > 1024 || image.height > 1024) {
      final resized = img.copyResize(
        image,
        width: image.width > image.height ? 1024 : null,
        height: image.height > image.width ? 1024 : null,
      );
      
      final resizedPath = '${file.parent.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(resizedPath).writeAsBytes(img.encodeJpg(resized));
      
      return resizedPath;
    }
    
    return imagePath;
  }

  static Future<List<String>> extractTextFromImage(
    CactusVLM vlm, 
    String imagePath
  ) async {
    final result = await vlm.completion([
      ChatMessage(
        role: 'user',
        content: 'Extract all text visible in this image. List each text element on a new line.',
      ),
    ], 
      imagePaths: [imagePath],
      maxTokens: 500,
      temperature: 0.1,
    );

    return result.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static Future<Map<String, dynamic>> analyzeImageStructure(
    CactusVLM vlm,
    String imagePath
  ) async {
    final result = await vlm.completion([
      ChatMessage(
        role: 'user',
        content: '''Analyze this image and provide a structured description in JSON format:
{
  "main_objects": ["object1", "object2"],
  "colors": ["color1", "color2"],
  "setting": "description of setting",
  "people_count": number,
  "text_present": true/false,
  "mood_or_atmosphere": "description"
}''',
      ),
    ], 
      imagePaths: [imagePath],
      maxTokens: 400,
      temperature: 0.2,
    );

    try {
      return jsonDecode(result.text);
    } catch (e) {
      return {'error': 'Failed to parse JSON', 'raw_response': result.text};
    }
  }
}
```

## Embeddings

### Text Embeddings

```dart
class EmbeddingService {
  final CactusLM lm;
  
  EmbeddingService(this.lm);

  List<double> getEmbedding(String text) {
    return lm.embedding(text);
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) throw ArgumentError('Vectors must have same length');
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<DocumentMatch> findSimilarDocuments(
    String query,
    List<String> documents,
    {double threshold = 0.7}
  ) {
    final queryEmbedding = getEmbedding(query);
    final matches = <DocumentMatch>[];
    
    for (int i = 0; i < documents.length; i++) {
      final docEmbedding = getEmbedding(documents[i]);
      final similarity = cosineSimilarity(queryEmbedding, docEmbedding);
      
      if (similarity >= threshold) {
        matches.add(DocumentMatch(
          document: documents[i],
          similarity: similarity,
          index: i,
        ));
      }
    }
    
    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches;
  }
}

class DocumentMatch {
  final String document;
  final double similarity;
  final int index;
  
  DocumentMatch({
    required this.document,
    required this.similarity,
    required this.index,
  });
}

// Usage
final embeddingService = EmbeddingService(lm);
final matches = embeddingService.findSimilarDocuments(
  'machine learning algorithms',
  [
    'Deep learning neural networks',
    'Cooking recipes and food preparation',
    'Supervised learning techniques',
    'Weather forecast data',
  ],
  threshold: 0.6,
);

for (final match in matches) {
  print('${match.similarity.toStringAsFixed(3)}: ${match.document}');
}
```

## Text-to-Speech (TTS)

Cactus provides powerful text-to-speech capabilities, allowing you to generate high-quality audio directly from text.

> **Note**: To play the generated audio, you'll need an audio player package like [just_audio](https://pub.dev/packages/just_audio) or [audioplayers](https://pub.dev/packages/audioplayers).

### Basic Speech Generation

```dart
import 'package:cactus/cactus.dart';

class SpeechGenerator {
  final CactusTTS tts;

  SpeechGenerator(this.tts);

  Future<CactusResult> speak(String text) async {
    try {
      final result = await tts.generate(
        text,
        maxTokens: 1024,
        temperature: 0.7,
      );

      print("Speech generation completed for: '$text'");
      return result;
    } catch (e) {
      print('Error generating speech: $e');
      rethrow;
    }
  }
}
```

### Complete TTS Example Widget

```dart
import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';

class TTSDemoWidget extends StatefulWidget {
  @override
  _TTSDemoWidgetState createState() => _TTSDemoWidgetState();
}

class _TTSDemoWidgetState extends State<TTSDemoWidget> {
  CactusTTS? _tts;
  final TextEditingController _controller = TextEditingController(
    text: 'Hello, this is a test of the text-to-speech system in Flutter.'
  );
  bool _isGenerating = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  @override
  void dispose() {
    _tts?.dispose();
    super.dispose();
  }

  Future<void> _initializeTTS() async {
    try {
      _tts = await CactusTTS.init(
        modelUrl: 'https://example.com/tts-model.gguf',
        contextSize: 1024,
        threads: 4,
      );
      
      setState(() => _isInitializing = false);
    } catch (e) {
      print('Failed to initialize TTS: $e');
      setState(() => _isInitializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize TTS: $e'))
      );
    }
  }

  Future<void> _generateSpeech() async {
    if (_tts == null || _controller.text.trim().isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final result = await _tts!.generate(
        _controller.text.trim(),
        maxTokens: 512,
        temperature: 0.7,
      );

      print("Speech generated successfully: ${result.text.length} characters");
      
      // In a real app, you would process the audio result here
      // and use an audio player to play the generated speech

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating speech: $e'))
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing TTS...'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Text-to-Speech', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Enter text to speak',
            ),
            maxLines: 3,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_isGenerating || _tts == null) ? null : _generateSpeech,
            icon: _isGenerating 
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Icons.volume_up),
            label: Text(_isGenerating ? 'Generating...' : 'Generate Speech'),
          ),
        ],
      ),
    );
  }
}
```

## Advanced Features

### Best Practices

```dart
class CactusManager {
  CactusLM? _lm;
  CactusVLM? _vlm;
  CactusTTS? _tts;
  
  Future<void> initializeLM() async {
    _lm = await CactusLM.init(/* params */);
  }
  
  Future<void> initializeVLM() async {
    _vlm = await CactusVLM.init(/* params */);
  }
  
  Future<void> initializeTTS() async {
    _tts = await CactusTTS.init(/* params */);
  }
  
  Future<void> dispose() async {
    _lm?.dispose();
    _vlm?.dispose(); 
    _tts?.dispose();
    _lm = null;
    _vlm = null;
    _tts = null;
  }
  
  bool get isLMInitialized => _lm != null;
  bool get isVLMInitialized => _vlm != null;
  bool get isTTSInitialized => _tts != null;
}

// In your app
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final CactusManager _cactusManager = CactusManager();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cactusManager.initializeLM();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cactusManager.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Optionally pause/save state
    } else if (state == AppLifecycleState.resumed) {
      // Resume operations
    }
  }
}
```

### Error Handling

```dart
class RobustChatService {
  final CactusLM lm;
  
  RobustChatService(this.lm);

  Future<String> generateWithRetry(
    String prompt, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final result = await lm.completion([
          ChatMessage(role: 'user', content: prompt)
        ], maxTokens: 256);
        
        if (result.text.trim().isNotEmpty) {
          return result.text;
        }
        
        throw Exception('Empty response generated');
        
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        print('Attempt ${attempt + 1} failed: $e');
        await Future.delayed(retryDelay);
      }
    }
    
    throw Exception('All retry attempts failed');
  }
}
```

## Troubleshooting

### Common Issues

**Model Loading Fails**
```dart
// Check model download and initialization
Future<bool> validateModel(String modelUrl) async {
  try {
    final lm = await CactusLM.init(
      modelUrl: modelUrl,
      contextSize: 1024, // Start small
    );
    lm.dispose();
    return true;
  } catch (e) {
    print('Model validation failed: $e');
    return false;
  }
}
```

**Out of Memory Errors**
```dart
// Reduce memory usage
final lm = await CactusLM.init(
  modelUrl: modelUrl,
  contextSize: 2048,     // Reduce from 4096
  gpuLayers: 0,          // Use CPU only if GPU memory limited
);
```

**Slow Generation**
```dart
// Optimize for speed
final result = await lm.completion(
  messages,
  maxTokens: 100,  // Reduce output length
  temperature: 0.3, // Lower temperature = faster
  topK: 20,        // Reduce sampling space
);
```

For more examples and advanced usage, check out the [example app](examples/flutter/) in the repository.
