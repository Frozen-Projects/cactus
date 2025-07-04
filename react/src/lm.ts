import { initLlama, LlamaContext } from './index'
import type {
  ContextParams,
  CompletionParams,
  CactusOAICompatibleMessage,
  NativeCompletionResult,
  EmbeddingParams,
  NativeEmbeddingResult,
} from './index'
import { Telemetry } from './telemetry'

interface CactusLMReturn {
  lm: CactusLM | null
  error: Error | null
}

export class CactusLM {
  private context: LlamaContext
  private initParams: ContextParams

  private constructor(context: LlamaContext, initParams: ContextParams) {
    this.context = context
    this.initParams = initParams
  }

  static async init(
    params: ContextParams,
    onProgress?: (progress: number) => void,
  ): Promise<CactusLMReturn> {
    const configs = [
      params,
      { ...params, n_gpu_layers: 0 } 
    ];

    for (const config of configs) {
      try {
        const context = await initLlama(config, onProgress);
        return { lm: new CactusLM(context, config), error: null };
      } catch (e) {
        Telemetry.error(e as Error, config);
        if (configs.indexOf(config) === configs.length - 1) {
          return { lm: null, error: e as Error };
        }
      }
    }
    return { lm: null, error: new Error('Failed to initialize CactusLM') };
  }

  async completion(
    messages: CactusOAICompatibleMessage[],
    params: CompletionParams = {},
    callback?: (data: any) => void,
  ): Promise<NativeCompletionResult> {
    const startTime = Date.now();
    let firstTokenTime: number | null = null;
    
    const wrappedCallback = callback ? (data: any) => {
      if (firstTokenTime === null) firstTokenTime = Date.now();
      callback(data);
    } : undefined;

    const result = await this.context.completion({ messages, ...params }, wrappedCallback);
    
    Telemetry.track({
      event: 'completion',
      tok_per_sec: (result as any).timings?.predicted_per_second,
      toks_generated: (result as any).timings?.predicted_n,
      ttft: firstTokenTime ? firstTokenTime - startTime : null,
    }, this.initParams);

    return result;
  }

  async embedding(
    text: string,
    params?: EmbeddingParams,
  ): Promise<NativeEmbeddingResult> {
    return this.context.embedding(text, params)
  }

  async rewind(): Promise<void> {
    // @ts-ignore
    return this.context?.rewind()
  }

  async release(): Promise<void> {
    return this.context.release()
  }
} 