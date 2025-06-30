import { Platform } from 'react-native';
import { LlamaContext, multimodalCompletion, initLlama, initMultimodal } from 'cactus-react-native';
import type { CactusOAICompatibleMessage } from 'cactus-react-native';
import RNFS from 'react-native-fs';

export interface Message {
  role: 'user' | 'assistant';
  content: string;
  images?: string[];
}

const modelUrl = 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf';
const mmprojUrl = 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf';
const modelFileName = 'SmolVLM-500M-Instruct-Q8_0.gguf';
const mmprojFileName = 'mmproj-SmolVLM-500M-Instruct-Q8_0.gguf';
const demoImageUrl = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop';

const stopWords = ['<|end_of_text|>', '<|endoftext|>', '</s>', '<end_of_utterance>'];

class CactusManager {
  private context: LlamaContext | null = null;
  private isInitialized = false;
  private demoImagePath: string | null = null;

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

    const [modelPath, mmprojPath, demoPath] = await Promise.all([
      this.downloadFile(modelUrl, modelFileName, progressCallback),
      this.downloadFile(mmprojUrl, mmprojFileName, progressCallback),
      this.downloadDemoImage()
    ]);

    this.demoImagePath = demoPath;

    console.log('Initializing VLM context...');

    this.context = await initLlama({
      model: modelPath,
      n_ctx: 2048,
      n_batch: 32,
      n_gpu_layers: 99,
      n_threads: 4,
      embedding: false,
    });

    console.log('Initializing multimodal capabilities...');
    console.log('Context ID:', this.context.id);
    console.log('mmproj path:', mmprojPath);
    console.log('mmproj file exists:', await RNFS.exists(mmprojPath));

    const multimodalSuccess = await initMultimodal(this.context.id, mmprojPath, false);
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

    const startTime = performance.now();
    let firstTokenTime: number | null = null;
    let tokenCount = 0;

    const currentMessage: CactusOAICompatibleMessage[] = [{
      role: 'user',
      content: userMessage.content,
    }];

    if (userMessage.images && userMessage.images.length > 0) {
      const localImagePaths = userMessage.images.map(() => this.demoImagePath!).filter(Boolean);

      const formattedPrompt = await this.context.getFormattedChat(
        currentMessage,
        undefined,
        { jinja: true }
      );

      const promptString = typeof formattedPrompt === 'string' ? formattedPrompt : formattedPrompt.prompt;

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

      const endTime = performance.now();
      const totalTime = endTime - startTime;
      
      const responseText = multimodalResult.text || 'No response generated';
      tokenCount = responseText.split(/\s+/).length;
      const tokensPerSecond = tokenCount > 0 ? (tokenCount / (totalTime / 1000)) : 0;

      console.log(`Multimodal: TTFT ${totalTime.toFixed(0)}ms (approx) | Toks/Sec: ${tokensPerSecond.toFixed(0)} | Toks: ${tokenCount}`);
      
      return responseText;
    } else {
      try {
        let responseText = '';
        
        const result = await this.context.completion({
          messages: currentMessage,
          n_predict: 256,
          stop: stopWords,
          temperature: 0.7,
          top_p: 0.9,
          penalty_repeat: 1.05,
        }, (data: any) => {
          if (firstTokenTime === null && data.token) {
            firstTokenTime = performance.now();
          }
          if (data.token) {
            tokenCount++;
            responseText += data.token;
          }
        });

        if (!responseText) {
          responseText = result.text || 'No response generated';
          tokenCount = responseText.split(/\s+/).length;
        }

        const endTime = performance.now();
        const totalTime = endTime - startTime;
        const timeToFirstToken = firstTokenTime ? firstTokenTime - startTime : totalTime;
        const tokensPerSecond = tokenCount > 0 ? (tokenCount / (totalTime / 1000)) : 0;

        console.log(`Text: TTFT ${timeToFirstToken.toFixed(0)}ms | Toks/Sec: ${tokensPerSecond.toFixed(0)} | Toks: ${tokenCount}`);
        
        return responseText;
      } catch (error) {
        console.error('Text completion failed:', error);
        throw error;
      }
    }
  }

  clearConversation(): void {
    (this.context as any)?.rewind();
    console.log('Conversation history cleared.');
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

  getConversationLength(): number {
    return 0;
  }
}

export const cactus = new CactusManager();