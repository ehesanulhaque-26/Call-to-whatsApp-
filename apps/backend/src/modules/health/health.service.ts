import { Injectable } from '@nestjs/common';
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

    return {
      status: allUp ? 'healthy' : allDown ? 'unhealthy' : 'degraded',
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
      return {
        status: 'down',
        message: 'Database connection failed',
      };
    }
  }

  private async checkOpenWA(): Promise<ServiceStatus> {
    const start = Date.now();
    try {
      await this.openWAService.healthCheck();
      const latency = Date.now() - start;
      return {
        status: 'up',
        latency,
      };
    } catch (error) {
      return {
        status: 'down',
        message: 'OpenWA server unavailable',
      };
    }
  }

  async getReadiness(): Promise<{ ready: boolean }> {
    const dbStatus = await this.checkDatabase();
    return {
      ready: dbStatus.status === 'up',
    };
  }

  async getLiveness(): Promise<{ alive: boolean }> {
    return {
      alive: true,
    };
  }
}
