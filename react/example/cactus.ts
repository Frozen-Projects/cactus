import { Platform } from 'react-native';
import { CactusVLM } from 'cactus-react-native';
import type { CactusOAICompatibleMessage } from 'cactus-react-native';
import RNFS from 'react-native-fs';

export type Message = CactusOAICompatibleMessage & {
  images?: string[];
}

const modelUrl = 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf';
const modelFileName = 'SmolVLM-500M-Instruct-Q8_0.gguf';
const mmprojUrl = 'https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf';
const mmprojFileName = 'mmproj-SmolVLM-500M-Instruct-Q8_0.gguf';
const demoImageUrl = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop';

const stopWords = ['<|end_of_text|>', '<|endoftext|>', '</s>', '<end_of_utterance>'];

class CactusManager {
  private vlm: CactusVLM | null = null;
  private isInitialized = false;
  private demoImagePath: string | null = null;

  private async getLocalPathForImage(uri: string): Promise<string> {
    if (uri.startsWith('file://')) {
      return uri.substring(7); // Remove 'file://' prefix for native layer
    }
    const fileName = new Date().getTime() + '.jpg';
    const destinationPath = `${RNFS.DocumentDirectoryPath}/${fileName}`;
    await RNFS.copyFile(uri, destinationPath);
    return destinationPath;
  }

  async downloadFile(url: string, fileName: string, progressCallback: (progress: number, file: string) => void): Promise<string> {
    const documentsPath = RNFS.DocumentDirectoryPath;
    const filePath = `${documentsPath}/${fileName}`;

    if (await RNFS.exists(filePath)) {
      return filePath;
    }

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
      return filePath;
    } else {
      throw new Error(`Failed to download ${fileName}`);
    }
  }

  async downloadDemoImage(): Promise<string> {
    const documentsPath = RNFS.DocumentDirectoryPath;
    const targetPath = `${documentsPath}/demo_image.jpg`;
    
    if (await RNFS.exists(targetPath)) {
      return targetPath;
    }
    
    const { promise } = RNFS.downloadFile({
      fromUrl: demoImageUrl,
      toFile: targetPath,
    });

    const result = await promise;

    if (result.statusCode === 200) {
      return targetPath;
    } else {
      throw new Error(`Failed to download demo image. Status code: ${result.statusCode}`);
    }
  }

  async initialize(progressCallback: (progress: number, file: string) => void): Promise<void> {
    if (this.isInitialized) return;

    const [modelPath, mmprojPath, demoPath] = await Promise.all([
      this.downloadFile(modelUrl, modelFileName, progressCallback),
      this.downloadFile(mmprojUrl, mmprojFileName, progressCallback),
      this.downloadDemoImage()
    ]);

    this.demoImagePath = demoPath;

    const {vlm, error} =  await CactusVLM.init({
      model: modelPath,
      mmproj: mmprojPath,
      n_ctx: 2048,
      n_batch: 32,
      n_gpu_layers: 99,
      n_threads: 4,
    });

    if (error) throw new Error('Error initializing Cactus VLM: ' + error);

    this.vlm = vlm

    this.isInitialized = true;
  }

  async generateResponse(userMessage: Message): Promise<string> {
    if (!this.vlm) {
      throw new Error('Cactus VLM not initialized');
    }

    const startTime = performance.now();
    let firstTokenTime: number | null = null;
    let tokenCount = 0;

    let localImagePaths: string[] | undefined;
    if (userMessage.images && userMessage.images.length > 0) {
      localImagePaths = await Promise.all(
        userMessage.images.map(uri => this.getLocalPathForImage(uri))
      );
    }

    const messages = [{ role: 'user', content: userMessage.content }];
    const params = {
      images: localImagePaths,
      n_predict: 256,
      stop: stopWords,
      temperature: 0.7,
      top_p: 0.9,
      penalty_repeat: 1.05,
    };

    let responseText = '';

    if (params.images && params.images.length > 0) {
       const result = await this.vlm.completion(messages, params);
       responseText = result.text;
    } else {
      const result = await this.vlm.completion(messages, params, (data: any) => {
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
      }
    }
    
    tokenCount = responseText.split(/\s+/).length;
    const endTime = performance.now();
    const totalTime = endTime - startTime;
    const timeToFirstToken = firstTokenTime ? firstTokenTime - startTime : totalTime;
    const tokensPerSecond = tokenCount > 0 ? (tokenCount / (totalTime / 1000)) : 0;
    
    const logPrefix = params.images && params.images.length > 0 ? 'Multimodal' : 'Text';
    console.log(`${logPrefix}: TTFT ${timeToFirstToken.toFixed(0)}ms | Toks/Sec: ${tokensPerSecond.toFixed(0)} | Toks: ${tokenCount}`);

    return responseText;
  }

  clearConversation(): void {
    this.vlm?.rewind();
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
}

export const cactus = new CactusManager();