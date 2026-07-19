import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { HealthService, HealthStatus } from './health.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOperation({ summary: 'Get application health status' })
  @ApiResponse({
    status: 200,
    description: 'Health status',
    type: Object,
  })
  async getHealth(): Promise<HealthStatus> {
    return this.healthService.getHealth();
  }

  @Get('ready')
  @ApiOperation({ summary: 'Readiness probe' })
  @ApiResponse({
    status: 200,
    description: 'Readiness status',
  })
  async getReadiness(): Promise<{ ready: boolean }> {
    return this.healthService.getReadiness();
  }

  @Get('live')
  @ApiOperation({ summary: 'Liveness probe' })
  @ApiResponse({
    status: 200,
    description: 'Liveness status',
  })
  async getLiveness(): Promise<{ alive: boolean }> {
    return this.healthService.getLiveness();
  }
}
