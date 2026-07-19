import { Module } from '@nestjs/common';
import { OpenWAService } from './openwa.service';
import { OpenWAController } from './openwa.controller';

@Module({
  controllers: [OpenWAController],
  providers: [OpenWAService],
  exports: [OpenWAService],
})
export class OpenWAModule {}
