import { Injectable, Logger } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export interface ActivityLogEntry {
  userId: string;
  action: string;
  details?: string;
  ipAddress?: string;
  sessionId?: string;
  metadata?: Record<string, unknown>;
}

@Injectable()
export class ActivityLogService {
  private readonly logger = new Logger(ActivityLogService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  async log(entry: ActivityLogEntry): Promise<void> {
    try {
      const { error } = await this.supabaseService.insert('activity_logs', {
        user_id: entry.userId,
        action: entry.action,
        details: entry.details,
        ip_address: entry.ipAddress,
        session_id: entry.sessionId,
        metadata: entry.metadata ? JSON.stringify(entry.metadata) : null,
      });

      if (error) {
        this.logger.error(`Failed to log activity: ${error.message}`, error);
      }
    } catch (error) {
      this.logger.error('Failed to log activity', error);
    }
  }

  async getLogs(options?: {
    userId?: string;
    action?: string;
    limit?: number;
    offset?: number;
  }): Promise<ActivityLogEntry[]> {
    try {
      const logs: ActivityLogEntry[] = [];

      if (options?.userId) {
        const { data, error } = await this.supabaseService.query('activity_logs', {
          eq: { user_id: options.userId },
          order: [{ column: 'created_at', ascending: false }],
          limit: options.limit || 100,
        });

        if (error) {
          this.logger.error(`Failed to get logs: ${error.message}`, error);
          return logs;
        }

        return (data || []).map((row: Record<string, unknown>) => ({
          userId: row.user_id as string,
          action: row.action as string,
          details: row.details as string | undefined,
          ipAddress: row.ip_address as string | undefined,
          sessionId: row.session_id as string | undefined,
        }));
      }

      return logs;
    } catch (error) {
      this.logger.error('Failed to get logs', error);
      return [];
    }
  }
}
