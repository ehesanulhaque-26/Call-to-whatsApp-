import { Module, Global } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { SupabaseService } from './supabase.service';

@Global()
@Module({
  providers: [
    // Anon client - used for user-scoped operations (respects RLS)
    {
      provide: 'SUPABASE_ANON_CLIENT',
      useFactory: (configService: ConfigService): SupabaseClient => {
        const supabaseUrl = configService.get<string>('SUPABASE_URL');
        const supabaseKey = configService.get<string>('SUPABASE_ANON_KEY');

        if (!supabaseUrl || !supabaseKey) {
          throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY must be defined');
        }

        return createClient(supabaseUrl, supabaseKey, {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
          },
        });
      },
      inject: [ConfigService],
    },
    // Service role client - used for admin operations (bypasses RLS)
    {
      provide: 'SUPABASE_SERVICE_CLIENT',
      useFactory: (configService: ConfigService): SupabaseClient => {
        const supabaseUrl = configService.get<string>('SUPABASE_URL');
        // Use SUPABASE_SERVICE_ROLE_KEY if available, otherwise fall back to ANON_KEY
        const supabaseKey =
          configService.get<string>('SUPABASE_SERVICE_KEY') ||
          configService.get<string>('SUPABASE_ANON_KEY');

        if (!supabaseUrl || !supabaseKey) {
          throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY must be defined');
        }

        return createClient(supabaseUrl, supabaseKey, {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
          },
        });
      },
      inject: [ConfigService],
    },
    SupabaseService,
  ],
  exports: [SupabaseService],
})
export class SupabaseModule {}
