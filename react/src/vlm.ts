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

export type VLMContextParams = ContextParams & {
  mmproj: string
}

export type VLMCompletionParams = Omit<CompletionParams, 'prompt'> & {
  images?: string[]
}

export class CactusVLM {
  private context: LlamaContext

  private constructor(context: LlamaContext) {
    this.context = context
  }

  static async init(
    params: VLMContextParams,
    onProgress?: (progress: number) => void,
  ): Promise<CactusVLM> {
    const context = await initLlama(params, onProgress)

    // Explicitly disable GPU for the multimodal projector for stability.
    await initMultimodal(context.id, params.mmproj, false)

    return new CactusVLM(context)
  }

  async completion(
    messages: CactusOAICompatibleMessage[],
    params: VLMCompletionParams = {},
    callback?: (data: any) => void,
  ): Promise<NativeCompletionResult> {
    if (params.images && params.images.length > 0) {
      const formattedPrompt = await this.context.getFormattedChat(messages)
      const prompt =
        typeof formattedPrompt === 'string'
          ? formattedPrompt
          : formattedPrompt.prompt
      return multimodalCompletion(
        this.context.id,
        prompt,
        params.images,
        { ...params, prompt, emit_partial_completion: !!callback },
      )
    }
    return this.context.completion({ messages, ...params }, callback)
  }

  async rewind(): Promise<void> {
    // @ts-ignore
    return this.context?.rewind()
  }

  async release(): Promise<void> {
    return this.context.release()
  }
} 