# Cactus React Native

A powerful React Native library for running Large Language Models (LLMs) and Vision Language Models (VLMs) directly on mobile devices, with full support for chat completions, multimodal inputs, embeddings, text-to-speech and advanced features.

## Installation

```bash
npm install cactus-react-native react-native-fs
# or
yarn add cactus-react-native react-native-fs
```

**Additional Setup:**
- For iOS: `cd ios && npx pod-install` or `yarn pod-install`
- For Android: Ensure your `minSdkVersion` is 24 or higher

> **Important**: `react-native-fs` is required for file system access to download and manage model files locally.

## Quick Start

### Basic Text Completion

```typescript
import { CactusLM } from 'cactus-react-native';

// Initialize a language model
const lm = await CactusLM.init({
  model: '/path/to/your/model.gguf',
  n_ctx: 2048,
  n_threads: 4,
});

// Generate text
const messages = [{ role: 'user', content: 'Hello, how are you?' }];
const params = { n_predict: 100, temperature: 0.7 };

const result = await lm.completion(messages, params);
console.log(result.text);
```

### Complete Chat App Example

```typescript
import React, { useState, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity } from 'react-native';
import { CactusLM } from 'cactus-react-native';
import RNFS from 'react-native-fs';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export default function ChatApp() {
  const [lm, setLM] = useState<CactusLM | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    initializeModel();
  }, []);

  async function initializeModel() {
    try {
      // Download model (example URL)
      const modelUrl = 'https://huggingface.co/Cactus-Compute/Qwen3-600m-Instruct-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf';
      const modelPath = `${RNFS.DocumentDirectoryPath}/model.gguf`;
      
      // Download if not exists
      if (!(await RNFS.exists(modelPath))) {
        await RNFS.downloadFile({
          fromUrl: modelUrl,
          toFile: modelPath,
        }).promise;
      }

      // Initialize language model
      const cactusLM = await CactusLM.init({
        model: modelPath,
        n_ctx: 2048,
        n_threads: 4,
        n_gpu_layers: 99, // Use GPU acceleration
      });

      setLM(cactusLM);
      setLoading(false);
    } catch (error) {
      console.error('Failed to initialize model:', error);
    }
  }

  async function sendMessage() {
    if (!lm || !input.trim()) return;

    const userMessage: Message = { role: 'user', content: input };
    const newMessages = [...messages, userMessage];
    setMessages(newMessages);
    setInput('');

    try {
      const params = {
        n_predict: 256,
        temperature: 0.7,
        stop: ['</s>', '<|end|>'],
      };

      const result = await lm.completion(newMessages, params);

      const assistantMessage: Message = { 
        role: 'assistant', 
        content: result.text 
      };
      setMessages([...newMessages, assistantMessage]);
    } catch (error) {
      console.error('Completion failed:', error);
    }
  }

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <Text>Loading model...</Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, padding: 16 }}>
      {/* Messages */}
      <View style={{ flex: 1 }}>
        {messages.map((msg, index) => (
          <Text key={index} style={{ 
            backgroundColor: msg.role === 'user' ? '#007AFF' : '#f0f0f0',
            color: msg.role === 'user' ? 'white' : 'black',
            padding: 8,
            margin: 4,
            borderRadius: 8,
          }}>
            {msg.content}
          </Text>
        ))}
      </View>

      {/* Input */}
      <View style={{ flexDirection: 'row' }}>
        <TextInput
          style={{ flex: 1, borderWidth: 1, padding: 8, borderRadius: 4 }}
          value={input}
          onChangeText={setInput}
          placeholder="Type a message..."
        />
        <TouchableOpacity 
          onPress={sendMessage}
          style={{ backgroundColor: '#007AFF', padding: 8, borderRadius: 4, marginLeft: 8 }}
        >
          <Text style={{ color: 'white' }}>Send</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}
```

## File Path Requirements

**Critical**: Cactus requires **absolute local file paths**, not Metro bundler URLs or asset references.

### ❌ Won't Work
```typescript
// Metro bundler URLs
'http://localhost:8081/assets/model.gguf'

// React Native asset requires  
require('./assets/model.gguf')

// Relative paths
'./models/model.gguf'
```

### ✅ Will Work
```typescript
import RNFS from 'react-native-fs';

// Absolute paths in app directories
const modelPath = `${RNFS.DocumentDirectoryPath}/model.gguf`;
const imagePath = `${RNFS.DocumentDirectoryPath}/image.jpg`;

// Downloaded/copied files
const downloadModel = async () => {
  const modelUrl = 'https://example.com/model.gguf';
  const localPath = `${RNFS.DocumentDirectoryPath}/model.gguf`;
  
  await RNFS.downloadFile({
    fromUrl: modelUrl,
    toFile: localPath,
  }).promise;
  
  return localPath; // Use this path with Cactus
};
```

### Image Assets
For images, you need to copy them to local storage first:

```typescript
// Copy bundled asset to local storage
const copyAssetToLocal = async (assetName: string): Promise<string> => {
  const assetPath = `${RNFS.MainBundlePath}/${assetName}`;
  const localPath = `${RNFS.DocumentDirectoryPath}/${assetName}`;
  
  if (!(await RNFS.exists(localPath))) {
    await RNFS.copyFile(assetPath, localPath);
  }
  
  return localPath;
};

// Usage
const imagePath = await copyAssetToLocal('demo.jpg');
const params = { images: [imagePath], n_predict: 200 };
const result = await vlm.completion(messages, params);
```

### External Images
Download external images to local storage:

```typescript
const downloadImage = async (imageUrl: string): Promise<string> => {
  const localPath = `${RNFS.DocumentDirectoryPath}/temp_image.jpg`;
  
  await RNFS.downloadFile({
    fromUrl: imageUrl,
    toFile: localPath,
  }).promise;
  
  return localPath;
};
```

## Core APIs

### CactusLM (Language Model)

For text-only language models:

```typescript
import { CactusLM } from 'cactus-react-native';

// Initialize
const lm = await CactusLM.init({
  model: '/path/to/model.gguf',
  n_ctx: 4096,           // Context window size
  n_batch: 512,          // Batch size for processing
  n_threads: 4,          // Number of threads
  n_gpu_layers: 99,      // GPU layers (0 = CPU only)
});

// Text completion
const messages = [
  { role: 'system', content: 'You are a helpful assistant.' },
  { role: 'user', content: 'What is the capital of France?' },
];

const params = {
  n_predict: 200,
  temperature: 0.7,
  top_p: 0.9,
  stop: ['</s>', '\n\n'],
};

const result = await lm.completion(messages, params);

// Embeddings
const embeddingResult = await lm.embedding('Your text here');
console.log('Embedding vector:', embeddingResult.embedding);

// Cleanup
await lm.rewind(); // Clear conversation
await lm.release(); // Release resources
```

### CactusVLM (Vision Language Model)

For multimodal models that can process both text and images:

```typescript
import { CactusVLM } from 'cactus-react-native';

// Initialize with multimodal projector
const vlm = await CactusVLM.init({
  model: '/path/to/vision-model.gguf',
  mmproj: '/path/to/mmproj.gguf',
  n_ctx: 2048,
  n_threads: 4,
  n_gpu_layers: 99, // GPU for main model, CPU for projector
});

// Image + text completion
const messages = [{ role: 'user', content: 'What do you see in this image?' }];
const params = {
  images: ['/path/to/image.jpg'],
  n_predict: 200,
  temperature: 0.3,
};

const result = await vlm.completion(messages, params);

// Text-only completion (same interface)
const textMessages = [{ role: 'user', content: 'Tell me a joke' }];
const textParams = { n_predict: 100 };
const textResult = await vlm.completion(textMessages, textParams);

// Cleanup
await vlm.rewind();
await vlm.release();
```

### CactusTTS (Text-to-Speech)

For text-to-speech generation:

```typescript
import { CactusTTS } from 'cactus-react-native';

// Initialize with vocoder
const tts = await CactusTTS.init({
  model: '/path/to/tts-model.gguf',
  vocoder: '/path/to/vocoder.gguf',
  n_ctx: 1024,
  n_threads: 4,
});

// Generate speech
const text = 'Hello, this is a test of text-to-speech functionality.';
const params = {
  voice_id: 0,
  temperature: 0.7,
  speed: 1.0,
};

const audioResult = await tts.generateSpeech(text, params);
console.log('Audio data:', audioResult.audio_data);

// Advanced token-based generation
const tokens = await tts.getGuideTokens('Your text here');
const audio = await tts.decodeTokens(tokens);

// Cleanup
await tts.release();
```

## Text Completion

### Basic Completion

```typescript
const lm = await CactusLM.init({
  model: '/path/to/model.gguf',
  n_ctx: 2048,
});

const messages = [
  { role: 'user', content: 'Write a short poem about coding' }
];

const params = {
  n_predict: 200,
  temperature: 0.8,
  top_p: 0.9,
  stop: ['</s>', '\n\n'],
};

const result = await lm.completion(messages, params);

console.log(result.text);
console.log(`Tokens: ${result.tokens_predicted}`);
console.log(`Speed: ${result.timings.predicted_per_second.toFixed(2)} tokens/sec`);
```

### Streaming Completion

```typescript
const result = await lm.completion(messages, params, (token) => {
  // Called for each generated token
  console.log('Token:', token.token);
  updateUI(token.token);
});
```

### Advanced Parameters

```typescript
const params = {
  // Generation control
  n_predict: 256,        // Max tokens to generate
  temperature: 0.7,      // Randomness (0.0 - 2.0)
  top_p: 0.9,           // Nucleus sampling
  top_k: 40,            // Top-k sampling
  min_p: 0.05,          // Minimum probability
  
  // Repetition control
  penalty_repeat: 1.1,   // Repetition penalty
  penalty_freq: 0.0,     // Frequency penalty
  penalty_present: 0.0,  // Presence penalty
  
  // Stop conditions
  stop: ['</s>', '<|end|>', '\n\n'],
  ignore_eos: false,
  
  // Sampling methods
  mirostat: 0,          // Mirostat sampling (0=disabled)
  mirostat_tau: 5.0,    // Target entropy
  mirostat_eta: 0.1,    // Learning rate
  
  // Advanced
  seed: -1,             // Random seed (-1 = random)
  n_probs: 0,           // Return token probabilities
};
```

## Multimodal (Vision)

### Setup Vision Model

```typescript
import { CactusVLM } from 'cactus-react-native';

const vlm = await CactusVLM.init({
  model: '/path/to/vision-model.gguf',
  mmproj: '/path/to/mmproj.gguf',  // Multimodal projector
  n_ctx: 4096,
});
```

### Image Analysis

```typescript
// Analyze single image
const messages = [{ role: 'user', content: 'Describe this image in detail' }];
const params = {
  images: ['/path/to/image.jpg'],
  n_predict: 200,
  temperature: 0.3,
};

const result = await vlm.completion(messages, params);
console.log(result.text);
```

### Multi-Image Analysis

```typescript
const imagePaths = [
  '/path/to/image1.jpg',
  '/path/to/image2.jpg',
  '/path/to/image3.jpg'
];

const messages = [{ role: 'user', content: 'Compare these images and explain the differences' }];
const params = {
  images: imagePaths,
  n_predict: 300,
  temperature: 0.4,
};

const result = await vlm.completion(messages, params);
```

### Conversation with Images

```typescript
const conversation = [
  { role: 'user', content: 'What do you see in this image?' }
];

const params = {
  images: ['/path/to/image.jpg'],
  n_predict: 256,
  temperature: 0.3,
};

const result = await vlm.completion(conversation, params);
```

## Embeddings

### Text Embeddings

```typescript
// Enable embeddings during initialization
const lm = await CactusLM.init({
  model: '/path/to/embedding-model.gguf',
  embedding: true,        // Enable embedding mode
  n_ctx: 512,            // Smaller context for embeddings
});

// Generate embeddings
const text = 'Your text here';
const result = await lm.embedding(text);
console.log('Embedding vector:', result.embedding);
console.log('Dimensions:', result.embedding.length);
```

### Batch Embeddings

```typescript
const texts = [
  'The quick brown fox',
  'Machine learning is fascinating',
  'React Native development'
];

const embeddings = await Promise.all(
  texts.map(text => lm.embedding(text))
);

// Calculate similarity
function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, ai, i) => sum + ai * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, ai) => sum + ai * ai, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, bi) => sum + bi * bi, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}

const similarity = cosineSimilarity(
  embeddings[0].embedding,
  embeddings[1].embedding
);
```

## Text-to-Speech (TTS)

Cactus supports text-to-speech through vocoder models, allowing you to generate speech from text.

### Setup TTS Model

```typescript
import { CactusTTS } from 'cactus-react-native';

const tts = await CactusTTS.init({
  model: '/path/to/text-model.gguf',
  vocoder: '/path/to/vocoder-model.gguf',
  n_ctx: 2048,
});
```

### Basic Text-to-Speech

```typescript
const text = 'Hello, this is a test of text-to-speech functionality.';
const params = {
  voice_id: 0,        // Speaker voice ID
  temperature: 0.7,   // Speech variation
  speed: 1.0,         // Speech speed
};

const result = await tts.generateSpeech(text, params);

console.log('Audio data:', result.audio_data);
console.log('Sample rate:', result.sample_rate);
console.log('Audio format:', result.format);
```

### Advanced TTS with Token Control

```typescript
// Get guide tokens for precise control
const tokensResult = await tts.getGuideTokens(
  'This text will be converted to speech tokens.'
);

console.log('Guide tokens:', tokensResult.tokens);
console.log('Token count:', tokensResult.tokens.length);

// Decode tokens to audio
const audioResult = await tts.decodeTokens(tokensResult.tokens);

console.log('Decoded audio:', audioResult.audio_data);
console.log('Duration:', audioResult.duration_seconds);
```

### Complete TTS Example

```typescript
import React, { useState, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity, Alert } from 'react-native';
import { Audio } from 'expo-av';
import RNFS from 'react-native-fs';
import { CactusTTS } from 'cactus-react-native';

export default function TTSDemo() {
  const [tts, setTTS] = useState<CactusTTS | null>(null);
  const [text, setText] = useState('Hello, this is a test of speech synthesis.');
  const [isGenerating, setIsGenerating] = useState(false);
  const [sound, setSound] = useState<Audio.Sound | null>(null);

  useEffect(() => {
    initializeTTS();
    return () => {
      if (sound) {
        sound.unloadAsync();
      }
    };
  }, []);

  async function initializeTTS() {
    try {
      // Download and initialize models
      const modelPath = await downloadModel();
      const vocoderPath = await downloadVocoder();

      const cactusTTS = await CactusTTS.init({
        model: modelPath,
        vocoder: vocoderPath,
        n_ctx: 1024,
        n_threads: 4,
      });

      setTTS(cactusTTS);
    } catch (error) {
      console.error('Failed to initialize TTS:', error);
      Alert.alert('Error', 'Failed to initialize TTS');
    }
  }

  async function generateSpeech() {
    if (!tts || !text.trim()) return;

    setIsGenerating(true);
    try {
      const params = {
        voice_id: 0,
        temperature: 0.7,
        speed: 1.0,
      };

      const result = await tts.generateSpeech(text, params);

      // Save audio to file
      const audioPath = `${RNFS.DocumentDirectoryPath}/speech.wav`;
      await RNFS.writeFile(audioPath, result.audio_data, 'base64');

      // Play audio
      const { sound: audioSound } = await Audio.Sound.createAsync({
        uri: `file://${audioPath}`,
      });
      
      setSound(audioSound);
      await audioSound.playAsync();

      console.log(`Generated speech: ${result.duration_seconds}s`);
    } catch (error) {
      console.error('Speech generation failed:', error);
      Alert.alert('Error', 'Failed to generate speech');
    } finally {
      setIsGenerating(false);
    }
  }

  // Helper functions for downloading models would go here...

  return (
    <View style={{ flex: 1, padding: 16 }}>
      <Text style={{ fontSize: 18, marginBottom: 16 }}>
        Text-to-Speech Demo
      </Text>
      
      <TextInput
        style={{
          borderWidth: 1,
          borderColor: '#ddd',
          borderRadius: 8,
          padding: 12,
          marginBottom: 16,
          minHeight: 100,
        }}
        value={text}
        onChangeText={setText}
        placeholder="Enter text to convert to speech..."
        multiline
      />
      
      <TouchableOpacity
        onPress={generateSpeech}
        disabled={isGenerating || !tts}
        style={{
          backgroundColor: isGenerating ? '#ccc' : '#007AFF',
          padding: 16,
          borderRadius: 8,
          alignItems: 'center',
        }}
      >
        <Text style={{ color: 'white', fontSize: 16, fontWeight: 'bold' }}>
          {isGenerating ? 'Generating...' : 'Generate Speech'}
        </Text>
      </TouchableOpacity>
    </View>
  );
}
```

## Advanced Features

### Session Management

For the low-level API, you can still access session management:

```typescript
import { initLlama } from 'cactus-react-native';

const context = await initLlama({ model: '/path/to/model.gguf' });

// Save session
const tokensKept = await context.saveSession('/path/to/session.bin', {
  tokenSize: 1024  // Number of tokens to keep
});

// Load session
const sessionInfo = await context.loadSession('/path/to/session.bin');
console.log(`Loaded ${sessionInfo.tokens_loaded} tokens`);
```

### LoRA Adapters

```typescript
const context = await initLlama({ model: '/path/to/model.gguf' });

// Apply LoRA adapters
await context.applyLoraAdapters([
  { path: '/path/to/lora1.gguf', scaled: 1.0 },
  { path: '/path/to/lora2.gguf', scaled: 0.8 }
]);

// Get loaded adapters
const adapters = await context.getLoadedLoraAdapters();
console.log('Loaded adapters:', adapters);

// Remove adapters
await context.removeLoraAdapters();
```

### Structured Output (JSON)

```typescript
const messages = [
  { role: 'user', content: 'Extract information about this person: John Doe, 30 years old, software engineer from San Francisco' }
];

const params = {
  response_format: {
    type: 'json_object',
    schema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        age: { type: 'number' },
        profession: { type: 'string' },
        location: { type: 'string' }
      },
      required: ['name', 'age']
    }
  }
};

const result = await lm.completion(messages, params);
const person = JSON.parse(result.text);
console.log(person.name); // "John Doe"
```

### Performance Monitoring

```typescript
const result = await lm.completion(messages, { n_predict: 100 });

console.log('Performance metrics:');
console.log(`Prompt tokens: ${result.timings.prompt_n}`);
console.log(`Generated tokens: ${result.timings.predicted_n}`);
console.log(`Prompt speed: ${result.timings.prompt_per_second.toFixed(2)} tokens/sec`);
console.log(`Generation speed: ${result.timings.predicted_per_second.toFixed(2)} tokens/sec`);
console.log(`Total time: ${(result.timings.prompt_ms + result.timings.predicted_ms).toFixed(0)}ms`);
```

## Best Practices

### Model Management

```typitten
class ModelManager {
  private models = new Map<string, CactusLM | CactusVLM | CactusTTS>();

  async loadLM(name: string, modelPath: string): Promise<CactusLM> {
    if (this.models.has(name)) {
      return this.models.get(name)! as CactusLM;
    }

    const lm = await CactusLM.init({ model: modelPath });
    this.models.set(name, lm);
    return lm;
  }

  async loadVLM(name: string, modelPath: string, mmprojPath: string): Promise<CactusVLM> {
    if (this.models.has(name)) {
      return this.models.get(name)! as CactusVLM;
    }

    const vlm = await CactusVLM.init({ model: modelPath, mmproj: mmprojPath });
    this.models.set(name, vlm);
    return vlm;
  }

  async unloadModel(name: string): Promise<void> {
    const model = this.models.get(name);
    if (model) {
      await model.release();
      this.models.delete(name);
    }
  }

  async unloadAll(): Promise<void> {
    await Promise.all(
      Array.from(this.models.values()).map(model => model.release())
    );
    this.models.clear();
  }
}
```

### Error Handling

```typescript
async function safeCompletion(lm: CactusLM, messages: any[]) {
  try {
    const result = await lm.completion(messages, {
      n_predict: 256,
      temperature: 0.7,
    });
    return { success: true, data: result };
  } catch (error) {
    if (error.message.includes('Context is busy')) {
      // Handle concurrent requests
      await new Promise(resolve => setTimeout(resolve, 100));
      return safeCompletion(lm, messages);
    } else if (error.message.includes('Context not found')) {
      // Handle context cleanup
      throw new Error('Model context was released');
    } else {
      // Handle other errors
      console.error('Completion failed:', error);
      return { success: false, error: error.message };
    }
  }
}
```

### Memory Management

```typescript
// Monitor memory usage
const checkMemory = () => {
  if (Platform.OS === 'android') {
    // Android-specific memory monitoring
    console.log('Memory warning - consider releasing unused models');
  }
};

// Release models when app goes to background
import { AppState } from 'react-native';

AppState.addEventListener('change', (nextAppState) => {
  if (nextAppState === 'background') {
    // Release non-essential models
    modelManager.unloadAll();
  }
});
```

## API Reference

### High-Level APIs

- `CactusLM.init(params: ContextParams): Promise<CactusLM>` - Initialize language model
- `CactusVLM.init(params: VLMContextParams): Promise<CactusVLM>` - Initialize vision language model  
- `CactusTTS.init(params: TTSContextParams): Promise<CactusTTS>` - Initialize text-to-speech model

### CactusLM Methods

- `completion(messages: CactusOAICompatibleMessage[], params: CompletionParams, callback?: (token: TokenData) => void): Promise<NativeCompletionResult>`
- `embedding(text: string, params?: EmbeddingParams): Promise<NativeEmbeddingResult>`
- `rewind(): Promise<void>` - Clear conversation history
- `release(): Promise<void>` - Release resources

### CactusVLM Methods

- `completion(messages: CactusOAICompatibleMessage[], params: VLMCompletionParams, callback?: (token: TokenData) => void): Promise<NativeCompletionResult>`
- `rewind(): Promise<void>` - Clear conversation history
- `release(): Promise<void>` - Release resources

### CactusTTS Methods

- `generateSpeech(text: string, params: TTSSpeechParams): Promise<NativeAudioCompletionResult>`
- `getGuideTokens(text: string): Promise<NativeAudioTokensResult>`
- `decodeTokens(tokens: number[]): Promise<NativeAudioDecodeResult>`
- `release(): Promise<void>` - Release resources

### Low-Level Functions (Advanced)

For advanced use cases, the original low-level API is still available:

- `initLlama(params: ContextParams): Promise<LlamaContext>` - Initialize a model context
- `releaseAllLlama(): Promise<void>` - Release all contexts
- `setContextLimit(limit: number): Promise<void>` - Set maximum contexts
- `toggleNativeLog(enabled: boolean): Promise<void>` - Enable/disable native logging

## Troubleshooting

### Common Issues

**Model Loading Fails**
```typescript
// Check file exists and is accessible
if (!(await RNFS.exists(modelPath))) {
  throw new Error('Model file not found');
}

// Check file size
const stats = await RNFS.stat(modelPath);
console.log('Model size:', stats.size);
```

**Out of Memory**
```typescript
// Reduce context size
const lm = await CactusLM.init({
  model: '/path/to/model.gguf',
  n_ctx: 1024,     // Reduce from 4096
  n_batch: 128,    // Reduce batch size
});
```

**GPU Issues**
```typescript
// Disable GPU if having issues
const lm = await CactusLM.init({
  model: '/path/to/model.gguf',
  n_gpu_layers: 0,  // Use CPU only
});
```

### Performance Tips

1. **Use appropriate context sizes** - Larger contexts use more memory
2. **Optimize batch sizes** - Balance between speed and memory
3. **Cache models** - Don't reload models unnecessarily
4. **Use GPU acceleration** - When available and stable
5. **Monitor memory usage** - Release models when not needed

This documentation covers the essential usage patterns for cactus-react-native. For more examples, check the [example apps](../examples/) in the repository.
