import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';
import { OpenWAModule } from '../openwa/openwa.module';

@Module({
  imports: [OpenWAModule],
  controllers: [HealthController],
  providers: [HealthService],
})
export class HealthModule {}
