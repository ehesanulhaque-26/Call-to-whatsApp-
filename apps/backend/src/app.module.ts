import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './modules/health/health.module';
import { SupabaseModule } from './modules/supabase/supabase.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { RolesModule } from './modules/roles/roles.module';
import { OpenWAModule } from './modules/openwa/openwa.module';
import { SessionManagerModule } from './modules/session-manager/session-manager.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '.env.local', '.env.production'],
    }),
    SupabaseModule,
    HealthModule,
    AuthModule,
    UsersModule,
    RolesModule,
    OpenWAModule,
    SessionManagerModule,
  ],
})
export class AppModule {}
