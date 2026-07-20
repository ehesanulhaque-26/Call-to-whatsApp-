import { Module, forwardRef } from '@nestjs/common';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { SessionManagerService } from './session-manager.service';
import { SessionManagerGateway } from './session-manager.gateway';
import { SessionManagerController, AdminSessionController } from './session-manager.controller';
import { ActivityLogService } from './activity-log.service';
import { SupabaseModule } from '../supabase/supabase.module';

@Module({
  imports: [
    EventEmitterModule.forRoot(),
    SupabaseModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: '7d' },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [SessionManagerController, AdminSessionController],
  providers: [
    SessionManagerService,
    SessionManagerGateway,
    ActivityLogService,
  ],
  exports: [SessionManagerService, ActivityLogService],
})
export class SessionManagerModule {}
