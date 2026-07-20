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
    
    this.logger.log(`Health check: ${status} - DB: ${dbStatus.status}, OpenWA: ${openwaStatus.status}`);

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
      await this.supabaseService.query('users', { limit: 1 });
      const latency = Date.now() - start;
      return {
        status: 'up',
        latency,
      };
    } catch (error) {
      this.logger.error(`Database health check failed: ${error}`);
      return {
        status: 'down',
        message: 'Database connection failed',
      };
    }
  }

  private async checkOpenWA(): Promise<ServiceStatus> {
    const start = Date.now();
    const openwaUrl = this.configService.get<string>('OPENWA_URL') || 'http://openwa.railway.internal';
    
    try {
      this.logger.debug(`Checking OpenWA connectivity at ${openwaUrl}/api/health`);
      const result = await this.openWAService.healthCheck();
      const latency = Date.now() - start;
      
      this.logger.log(`OpenWA health check successful - Status: ${result.status}, Latency: ${latency}ms`);
      
      return {
        status: 'up',
        latency,
        message: `OpenWA Operational - ${openwaUrl}`,
      };
    } catch (error) {
      const latency = Date.now() - start;
      this.logger.error(`OpenWA health check failed after ${latency}ms: ${error}`);
      
      return {
        status: 'down',
        latency,
        message: `OpenWA unreachable at ${openwaUrl}`,
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
