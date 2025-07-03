import {
  initLlama,
  initMultimodal,
  multimodalCompletion,
  LlamaContext,
} from './index'
import type {
  ContextParams,
  CompletionParams,
  CactusOAICompatibleMessage,
  NativeCompletionResult,
} from './index'
import { Telemetry } from './telemetry'

interface CactusVLMReturn {
  vlm: CactusVLM | null
  error: Error | null
}

export type VLMContextParams = ContextParams & {
  mmproj: string
}

export type VLMCompletionParams = Omit<CompletionParams, 'prompt'> & {
  images?: string[]
}

export class CactusVLM {
  private context: LlamaContext
  private initParams: VLMContextParams

  private constructor(context: LlamaContext, initParams: VLMContextParams) {
    this.context = context
    this.initParams = initParams
  }

  static async init(
    params: VLMContextParams,
    onProgress?: (progress: number) => void,
  ): Promise<CactusVLMReturn> {
    const configs = [
      params,
      { ...params, n_gpu_layers: 0 } 
    ];

    for (const config of configs) {
      try {
        const context = await initLlama(config, onProgress)
        // Explicitly disable GPU for the multimodal projector for stability.
        await initMultimodal(context.id, params.mmproj, false)
        return {vlm: new CactusVLM(context, params), error: null}
      } catch (e) {
        Telemetry.error(e as Error, config);
        if (configs.indexOf(config) === configs.length - 1) {
          return {vlm: null, error: e as Error}
        }
      }
    }

    return {vlm: null, error: new Error('Failed to initialize CactusVLM')}
  }

  async completion(
    messages: CactusOAICompatibleMessage[],
    params: VLMCompletionParams = {},
    callback?: (data: any) => void,
  ): Promise<NativeCompletionResult> {
    const startTime = Date.now();
    let firstTokenTime: number | null = null;
    
    const wrappedCallback = callback ? (data: any) => {
      if (firstTokenTime === null) firstTokenTime = Date.now();
      callback(data);
    } : undefined;

    let result: NativeCompletionResult;
    if (params.images && params.images.length > 0) {
      const formattedPrompt = await this.context.getFormattedChat(messages)
      const prompt =
        typeof formattedPrompt === 'string'
          ? formattedPrompt
          : formattedPrompt.prompt
      result = await multimodalCompletion(
        this.context.id,
        prompt,
        params.images,
        { ...params, prompt, emit_partial_completion: !!callback },
      )
    } else {
      result = await this.context.completion({ messages, ...params }, wrappedCallback)
    }
    
    Telemetry.track({
      event: 'completion',
      tok_per_sec: (result as any).timings?.predicted_per_second,
      toks_generated: (result as any).timings?.predicted_n,
      ttft: firstTokenTime ? firstTokenTime - startTime : null,
      num_images: params.images?.length,
    }, this.initParams);

    return result;
  }

  async rewind(): Promise<void> {
    // @ts-ignore
    return this.context?.rewind()
  }

  async release(): Promise<void> {
    return this.context.release()
  }
} 