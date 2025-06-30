import {
  LlamaContext,
  initVocoder,
  getFormattedAudioCompletion,
  decodeAudioTokens,
  releaseVocoder,
} from './index'
import type { NativeAudioDecodeResult } from './index'

export class CactusTTS {
  private context: LlamaContext

  private constructor(context: LlamaContext) {
    this.context = context
  }

  static async init(
    context: LlamaContext,
    vocoderModelPath: string,
  ): Promise<CactusTTS> {
    await initVocoder(context.id, vocoderModelPath)
    return new CactusTTS(context)
  }

  async generate(
    textToSpeak: string,
    speakerJsonStr: string,
  ): Promise<NativeAudioDecodeResult> {
    const { formatted_prompt } = await getFormattedAudioCompletion(
      this.context.id,
      speakerJsonStr,
      textToSpeak,
    )
    // This part is simplified. In a real scenario, the tokens from 
    // the main model would be generated and passed to decodeAudioTokens.
    // For now, we are assuming a direct path which may not be fully functional
    // without the main model's token output for TTS.
    const tokens = (await this.context.tokenize(formatted_prompt)).tokens
    return decodeAudioTokens(this.context.id, tokens)
  }

  async release(): Promise<void> {
    return releaseVocoder(this.context.id)
  }
} 