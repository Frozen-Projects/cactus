import { Platform } from 'react-native'
import type { ContextParams } from './index';

interface TelemetryRecord {
  os: 'iOS' | 'Android';
  os_version: string;
  telemetry_payload?: Record<string, any>;
  error_payload?: Record<string, any>;
  timestamp: string;
  model_filename: string;
  n_ctx?: number;
  n_gpu_layers?: number;
}

interface TelemetryConfig {
  supabaseUrl: string;
  supabaseKey: string;
  table?: string;
  batchSize?: number;
  flushInterval?: number;
  maxRetries?: number;
}

export class Telemetry {
  private static instance: Telemetry | null = null;
  private queue: TelemetryRecord[] = [];
  private config: Required<TelemetryConfig>;
  private timer?: any;
  private retryQueue: TelemetryRecord[] = [];

  private constructor(config: TelemetryConfig) {
    this.config = {
      table: 'telemetry',
      batchSize: 10,
      flushInterval: 1000 * 60,
      maxRetries: 3,
      ...config
    };
    
    this.startTimer();
  }

  static autoInit(): void {
    if (!Telemetry.instance) {
      Telemetry.instance = new Telemetry({
        supabaseUrl: 'https://vlqqczxwyaodtcdmdmlw.supabase.co',
        supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZscXFjenh3eWFvZHRjZG1kbWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MTg2MzIsImV4cCI6MjA2NzA5NDYzMn0.nBzqGuK9j6RZ6mOPWU2boAC_5H9XDs-fPpo5P3WZYbI', // Anon!
      });
    }
  }

  static init(config: TelemetryConfig): void {
    if (!Telemetry.instance) {
      Telemetry.instance = new Telemetry(config);
    }
  }

  static track(payload: Record<string, any>, options: ContextParams): void {
    if (!Telemetry.instance) {
      Telemetry.autoInit();
    }
    Telemetry.instance!.trackInternal(payload, options);
  }

  static error(error: Error, options: ContextParams): void {
    if (!Telemetry.instance) {
      Telemetry.autoInit();
    }
    Telemetry.instance!.errorInternal(error, options);
  }

  static flush(): Promise<void> {
    if (!Telemetry.instance) return Promise.resolve();
    return Telemetry.instance.flushInternal();
  }

  static destroy(): void {
    if (Telemetry.instance) {
      Telemetry.instance.destroyInternal();
      Telemetry.instance = null;
    }
  }

  private trackInternal(payload: Record<string, any>, options: ContextParams): void {
    const record: TelemetryRecord = {
      os: Platform.OS === 'ios' ? 'iOS' : 'Android',
      os_version: Platform.Version.toString(),
      telemetry_payload: payload,
      timestamp: new Date().toISOString(),
      model_filename: options.model,
      n_ctx: options.n_ctx,
      n_gpu_layers: options.n_gpu_layers
    };

    this.queue.push(record);

    if (this.queue.length >= this.config.batchSize) {
      this.flushInternal();
    }
  }

  private errorInternal(error: Error, options: ContextParams): void {
    const errorPayload = {
      message: error.message,
      stack: error.stack,
      name: error.name,
    };

    const record: TelemetryRecord = {
      os: Platform.OS === 'ios' ? 'iOS' : 'Android',
      os_version: Platform.Version.toString(),
      error_payload: errorPayload,
      timestamp: new Date().toISOString(),
      model_filename: options.model,
      n_ctx: options.n_ctx,
      n_gpu_layers: options.n_gpu_layers
    };

    this.queue.push(record);

    if (this.queue.length >= this.config.batchSize) {
      this.flushInternal();
    }
  }

  private async flushInternal(): Promise<void> {
    if (this.queue.length === 0 && this.retryQueue.length === 0) return;

    const records = [...this.retryQueue, ...this.queue];
    this.queue = [];
    this.retryQueue = [];

    try {
      const response = await (globalThis as any).fetch(`${this.config.supabaseUrl}/rest/v1/${this.config.table}`, {
        method: 'POST',
        headers: {
          'apikey': this.config.supabaseKey,
          'Authorization': `Bearer ${this.config.supabaseKey}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify(records)
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      const retriableRecords = records.filter(r => (r as any)._retries < this.config.maxRetries);
      retriableRecords.forEach(r => (r as any)._retries = ((r as any)._retries || 0) + 1);
      this.retryQueue.push(...retriableRecords);
      
      try {
        (globalThis as any).console?.warn('Telemetry failed:', error);
      } catch {}
    }
  }

  private startTimer(): void {
    this.timer = (globalThis as any).setInterval(() => {
      this.flushInternal();
    }, this.config.flushInterval);
  }

  private destroyInternal(): void {
    if (this.timer) {
      (globalThis as any).clearInterval(this.timer);
    }
    this.flushInternal();
  }
}
