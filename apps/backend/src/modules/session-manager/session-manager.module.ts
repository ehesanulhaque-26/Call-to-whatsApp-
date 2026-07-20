import { Module } from '@nestjs/common';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { SessionManagerService } from './session-manager.service';
import { SessionManagerGateway } from './session-manager.gateway';
import { SessionManagerController, AdminSessionController } from './session-manager.controller';
import { ActivityLogService } from './activity-log.service';
import { SupabaseModule } from '../supabase/supabase.module';

@Module({
  imports: [EventEmitterModule.forRoot(), SupabaseModule],
  controllers: [SessionManagerController, AdminSessionController],
  providers: [SessionManagerService, SessionManagerGateway, ActivityLogService],
  exports: [SessionManagerService, ActivityLogService],
})
export class SessionManagerModule {}
