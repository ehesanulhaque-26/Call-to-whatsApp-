import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../supabase/supabase.service';
import { OpenWAService } from '../openwa/openwa.service';

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  version: string;
  uptime: number;
  services: {
    database: ServiceStatus;
    openwa: ServiceStatus;
  };
}

export interface ServiceStatus {
  status: 'up' | 'down';
  latency?: number;
  message?: string;
}

@Injectable()
export class HealthService {
  private readonly logger = new Logger(HealthService.name);
  private readonly startTime = Date.now();

  constructor(
    private readonly configService: ConfigService,
    private readonly supabaseService: SupabaseService,
    private readonly openWAService: OpenWAService,
  ) {}

  async getHealth(): Promise<HealthStatus> {
    const dbStatus = await this.checkDatabase();
    const openwaStatus = await this.checkOpenWA();

    const allUp = dbStatus.status === 'up' && openwaStatus.status === 'up';
    const allDown = dbStatus.status === 'down' && openwaStatus.status === 'down';

    const status = allUp ? 'healthy' : allDown ? 'unhealthy' : 'degraded';

    this.logger.log(
      `Health check: ${status} - DB: ${dbStatus.status}, OpenWA: ${openwaStatus.status}`,
    );

    return {
      status,
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      uptime: Math.floor((Date.now() - this.startTime) / 1000),
      services: {
        database: dbStatus,
        openwa: openwaStatus,
      },
    };
  }

  private async checkDatabase(): Promise<ServiceStatus> {
    const start = Date.now();
    try {
      // Verify actual database connectivity by querying the profiles table
      // The profiles table is guaranteed to exist per the database migration
      const client = this.supabaseService.getClient();
      if (!client) {
        throw new Error('Supabase client not initialized');
      }

      // Perform a lightweight query to verify actual database connectivity
      const { error } = await client.from('profiles').select('id').limit(1);

      if (error) {
        throw new Error(`Database query failed: ${error.message}`);
      }

      const latency = Date.now() - start;
      this.logger.log(`Database health check passed - Supabase connected (${latency}ms)`);
      return {
        status: 'up',
        latency,
        message: 'Supabase connected',
      };
    } catch (error) {
      const latency = Date.now() - start;
      this.logger.error(`Database health check failed: ${error}`);
      return {
        status: 'down',
        latency,
        message: `Database connection failed: ${error instanceof Error ? error.message : String(error)}`,
      };
    }
  }

  private async checkOpenWA(): Promise<ServiceStatus> {
    const start = Date.now();
    const openwaUrl =
      this.configService.get<string>('OPENWA_URL') ||
      process.env.OPENWA_URL ||
      'https://openwa-production-d8f8.up.railway.app';

    this.logger.warn(`[Health] Starting OpenWA check using URL: ${openwaUrl}`);

    try {
      this.logger.warn(`[Health] Calling OpenWAService.healthCheck()...`);
      const result = await this.openWAService.healthCheck();
      const latency = Date.now() - start;

      this.logger.warn(
        `[Health] OpenWA check SUCCESS - Response: ${JSON.stringify(result)}, Latency: ${latency}ms`,
      );

      return {
        status: 'up',
        latency,
        message: `OpenWA Operational - ${openwaUrl}`,
      };
    } catch (error) {
      const latency = Date.now() - start;
      const errorMessage = error instanceof Error ? error.message : String(error);
      this.logger.error(`[Health] OpenWA check FAILED after ${latency}ms: ${errorMessage}`);

      return {
        status: 'down',
        latency,
        message: `OpenWA unreachable at ${openwaUrl}: ${errorMessage}`,
      };
    }
  }

  async getReadiness(): Promise<{ ready: boolean }> {
    const dbStatus = await this.checkDatabase();
    const openwaStatus = await this.checkOpenWA();

    return {
      ready: dbStatus.status === 'up' && openwaStatus.status === 'up',
    };
  }

  async getLiveness(): Promise<{ alive: boolean }> {
    return {
      alive: true,
    };
  }
}
