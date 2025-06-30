import { Platform } from 'react-native';
import { LlamaContext, multimodalCompletion, initLlama, initMultimodal } from 'cactus-react-native';
import type { CactusOAICompatibleMessage } from 'cactus-react-native';
import RNFS from 'react-native-fs';

export interface Message {
  role: 'user' | 'assistant';
  content: string;
  images?: string[];
}

interface ConversationResult {
  text: string;
  time_to_first_token: number;
  total_time: number;
  tokens_generated: number;
}

// VLM Model URLs
const modelUrl = 'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/SmolVLM-256M-Instruct-Q8_0.gguf';
const mmprojUrl = 'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf';
const modelFileName = 'SmolVLM-256M-Instruct-Q8_0.gguf';
const mmprojFileName = 'mmproj-SmolVLM-256M-Instruct-Q8_0.gguf';
const demoImageUrl = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop';

const stopWords = ['<|end_of_text|>', '<|endoftext|>', '</s>', '<end_of_utterance>'];

class CactusManager {
  private context: LlamaContext | null = null;
  private isInitialized = false;
  private demoImagePath: string | null = null;
  private lastInteractionWasMultimodal = false;

  async downloadFile(url: string, fileName: string, progressCallback: (progress: number, file: string) => void): Promise<string> {
    const documentsPath = RNFS.DocumentDirectoryPath;
    const filePath = `${documentsPath}/${fileName}`;

    if (await RNFS.exists(filePath)) {
      console.log(`${fileName} already exists at: ${filePath}`);
      return filePath;
    }

    console.log(`Downloading ${fileName}...`);
    progressCallback(0, fileName);

    const { promise } = RNFS.downloadFile({
      fromUrl: url,
      toFile: filePath,
      progress: (res) => {
        const progress = res.bytesWritten / res.contentLength;
        progressCallback(progress, fileName);
      },
    });

    const result = await promise;
    
    if (result.statusCode === 200) {
      console.log(`${fileName} downloaded successfully`);
      return filePath;
    } else {
      throw new Error(`Failed to download ${fileName}`);
    }
  }

  async downloadDemoImage(): Promise<string> {
    const documentsPath = RNFS.DocumentDirectoryPath;
    const targetPath = `${documentsPath}/demo_image.jpg`;
    
    if (await RNFS.exists(targetPath)) {
      console.log('Demo image already exists at:', targetPath);
      return targetPath;
    }
    
    console.log('Downloading demo image...');
    const { promise } = RNFS.downloadFile({
      fromUrl: demoImageUrl,
      toFile: targetPath,
    });

    const result = await promise;

    if (result.statusCode === 200) {
      console.log('Demo image downloaded to:', targetPath);
      return targetPath;
    } else {
      throw new Error(`Failed to download demo image. Status code: ${result.statusCode}`);
    }
  }

  async initialize(progressCallback: (progress: number, file: string) => void): Promise<void> {
    if (this.isInitialized) return;

    console.log('Downloading VLM model, multimodal projector, and demo image...');

    // Download model, multimodal projector, and demo image
    const [modelPath, mmprojPath, demoPath] = await Promise.all([
      this.downloadFile(modelUrl, modelFileName, progressCallback),
      this.downloadFile(mmprojUrl, mmprojFileName, progressCallback),
      this.downloadDemoImage()
    ]);

    this.demoImagePath = demoPath;

    console.log('Initializing VLM context...');

    // Initialize llama context with VLM model
    this.context = await initLlama({
      model: modelPath,
      n_ctx: 2048,
      n_batch: 32,
      n_gpu_layers: 99, // Use GPU acceleration for main model
      n_threads: 4,
      embedding: false,
    });

    console.log('Initializing multimodal capabilities...');
    console.log('Context ID:', this.context.id);
    console.log('mmproj path:', mmprojPath);
    console.log('mmproj file exists:', await RNFS.exists(mmprojPath));

    // Import the initMultimodal function and initialize multimodal support
    const multimodalSuccess = await initMultimodal(this.context.id, mmprojPath, false); // Disable GPU for iOS simulator compatibility
    console.log('initMultimodal result:', multimodalSuccess);
    
    if (!multimodalSuccess) {
      console.warn('Failed to initialize multimodal capabilities');
    } else {
      console.log('VLM context initialized successfully with multimodal support');
    }

    this.isInitialized = true;
  }

  async generateResponse(userMessage: Message): Promise<string> {
    if (!this.context) {
      throw new Error('Cactus context not initialized');
    }

    const startTime = Date.now();
    console.log('[TIMING] generateResponse called at', new Date().toISOString());

    const isCurrentlyMultimodal = !!(userMessage.images && userMessage.images.length > 0);
    console.log(`[CONTEXT] Mode: ${isCurrentlyMultimodal ? 'multimodal' : 'text'}, conversation active: ${await this.context.isConversationActive()}`);
    
    if (this.lastInteractionWasMultimodal !== isCurrentlyMultimodal) {
      console.log(`[MODE_SWITCH] Switching from ${this.lastInteractionWasMultimodal ? 'multimodal' : 'text'} to ${isCurrentlyMultimodal ? 'multimodal' : 'text'} mode - clearing conversation`);
      await this.context.clearConversation();
    }

    this.lastInteractionWasMultimodal = isCurrentlyMultimodal;

    if (userMessage.images && userMessage.images.length > 0) {
      const localImagePaths = userMessage.images.map(() => this.demoImagePath!).filter(Boolean);
      
      console.log('Using multimodal completion with local images:', localImagePaths);
      
      const conversationHistory: CactusOAICompatibleMessage[] = [{
        role: 'user',
        content: userMessage.content
      }];

      const formattedPrompt = await this.context.getFormattedChat(
        conversationHistory,
        undefined,
        { jinja: true }
      );

      const promptString = typeof formattedPrompt === 'string' ? formattedPrompt : formattedPrompt.prompt;

      console.log('Formatted multimodal prompt:', promptString.substring(0, 100) + '...');

      console.log('[TIMING] Starting multimodal completion...');
      
      const multimodalResult = await multimodalCompletion(
        this.context.id,
        promptString,
        localImagePaths,
        {
          prompt: promptString,
          n_predict: 256,
          stop: stopWords,
          temperature: 0.3,
          top_p: 0.9,
          penalty_repeat: 1.1,
          emit_partial_completion: false,
        }
      );

      const totalTime = Date.now() - startTime;
      console.log(`[TIMING] Total multimodal response time: ${totalTime}ms`);
      
      return multimodalResult.text;
    } else {
      console.log('Using optimized conversation API for text completion');
      
      try {
        console.log('[TIMING] Starting continueConversation...');
        
        const result: ConversationResult = await this.context.continueConversation(userMessage.content, 256);
        
        console.log(`[PERFORMANCE] TTFT: ${result.time_to_first_token}ms`);
        console.log(`[PERFORMANCE] Total generation: ${result.total_time}ms`);
        console.log(`[PERFORMANCE] Tokens generated: ${result.tokens_generated}`);
        console.log(`[PERFORMANCE] Speed: ${(result.tokens_generated / (result.total_time / 1000)).toFixed(1)} tok/s`);

        const totalTime = Date.now() - startTime;
        console.log(`[TIMING] Total text response time: ${totalTime}ms`);
        
        return result.text;
      } catch (error) {
        console.error('Text completion failed:', error);
        throw error;
      }
    }
  }

  async clearConversation(): Promise<void> {
    if (!this.context) return;
    
    const wasActive = await this.context.isConversationActive();
    await this.context.clearConversation();
    this.lastInteractionWasMultimodal = false;
    console.log(`[CLEAR] Conversation cleared (was ${wasActive ? 'active' : 'inactive'}) and interaction mode reset`);
  }

  getDemoImageUri(): string {
    if (this.demoImagePath) {
      return this.demoImagePath.startsWith('file://') ? this.demoImagePath : `file://${this.demoImagePath}`;
    }
    return demoImageUrl; 
  }

  getIsInitialized(): boolean {
    return this.isInitialized;
  }

  async isConversationActive(): Promise<boolean> {
    if (!this.context) return false;
    return await this.context.isConversationActive();
  }
}

// Export singleton instance
export const cactus = new CactusManager(); 