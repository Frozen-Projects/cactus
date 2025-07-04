import { Platform } from 'react-native'
import type { ContextParams } from './index';
// Import package.json to get version
const packageJson = require('../package.json');

interface TelemetryRecord {
  os: 'iOS' | 'Android';
  os_version: string;
  framework: string;
  framework_version: string;
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
}

export class Telemetry {
  private static instance: Telemetry | null = null;
  private config: Required<TelemetryConfig>;

  private constructor(config: TelemetryConfig) {
    this.config = {
      table: 'telemetry',
      ...config
    };
  }

  private static getFilename(path: string): string {
    try {
      return path.split('/').pop() || path.split('\\').pop() || 'unknown';
    } catch {
      return 'unknown';
    }
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

  private trackInternal(payload: Record<string, any>, options: ContextParams): void {
    const record: TelemetryRecord = {
      os: Platform.OS === 'ios' ? 'iOS' : 'Android',
      os_version: Platform.Version.toString(),
      framework: 'react-native',
      framework_version: packageJson.version,
      telemetry_payload: payload,
      timestamp: new Date().toISOString(),
      model_filename: Telemetry.getFilename(options.model),
      n_ctx: options.n_ctx,
      n_gpu_layers: options.n_gpu_layers
    };

    this.sendRecord(record).catch(() => {});
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
      framework: 'react-native',
      framework_version: packageJson.version,
      error_payload: errorPayload,
      timestamp: new Date().toISOString(),
      model_filename: Telemetry.getFilename(options.model),
      n_ctx: options.n_ctx,
      n_gpu_layers: options.n_gpu_layers
    };

    this.sendRecord(record).catch(() => {});
  }

  private async sendRecord(record: TelemetryRecord): Promise<void> {
    await (globalThis as any).fetch(`${this.config.supabaseUrl}/rest/v1/${this.config.table}`, {
      method: 'POST',
      headers: {
        'apikey': this.config.supabaseKey,
        'Authorization': `Bearer ${this.config.supabaseKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify([record])
    });
  }
}
