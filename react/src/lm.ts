import { initLlama, LlamaContext } from './index'
import type {
  ContextParams,
  CompletionParams,
  CactusOAICompatibleMessage,
  NativeCompletionResult,
} from './index'

export class CactusLM {
  private context: LlamaContext

  private constructor(context: LlamaContext) {
    this.context = context
  }

  static async init(
    params: ContextParams,
    onProgress?: (progress: number) => void,
  ): Promise<CactusLM> {
    const context = await initLlama(params, onProgress)
    return new CactusLM(context)
  }

  async completion(
    messages: CactusOAICompatibleMessage[],
    params: CompletionParams = {},
    callback?: (data: any) => void,
  ): Promise<NativeCompletionResult> {
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