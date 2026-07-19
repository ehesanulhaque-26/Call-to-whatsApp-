import { Injectable, Inject, Logger } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';

export type SupabaseClientType = 'anon' | 'service';

@Injectable()
export class SupabaseService {
  private readonly logger = new Logger(SupabaseService.name);
  private readonly _anonClient: SupabaseClient;
  private readonly _serviceClient: SupabaseClient;

  constructor(
    @Inject('SUPABASE_ANON_CLIENT') anonClient: SupabaseClient,
    @Inject('SUPABASE_SERVICE_CLIENT') serviceClient: SupabaseClient,
  ) {
    this._anonClient = anonClient;
    this._serviceClient = serviceClient;
  }

  /**
   * Get the appropriate client based on type
   * - 'anon': User-scoped operations (respects RLS policies)
   * - 'service': Admin operations (bypasses RLS policies)
   */
  getClient(type: SupabaseClientType = 'service'): SupabaseClient {
    return type === 'anon' ? this._anonClient : this._serviceClient;
  }

  /**
   * Get the default client (service role - bypasses RLS)
   * @deprecated Use getClient() instead
   */
  get client(): SupabaseClient {
    return this._serviceClient;
  }

  async query<T>(
    table: string,
    options?: {
      select?: string;
      eq?: Record<string, string | number | boolean | null>;
      neq?: Record<string, string | number | boolean>;
      gt?: Record<string, string | number>;
      gte?: Record<string, string | number>;
      lt?: Record<string, string | number>;
      lte?: Record<string, string | number>;
      like?: Record<string, string>;
      ilike?: Record<string, string>;
      in?: Record<string, (string | number)[]>;
      is?: Record<string, null | boolean>;
      order?: { column: string; ascending?: boolean }[];
      range?: { from: number; to: number };
      limit?: number;
    },
  ): Promise<{ data: T[] | null; error: Error | null }> {
    try {
      let query = this.client.from(table).select(options?.select || '*');

      // Apply filters
      if (options?.eq) {
        for (const [key, value] of Object.entries(options.eq)) {
          query = query.eq(key, value);
        }
      }

      if (options?.neq) {
        for (const [key, value] of Object.entries(options.neq)) {
          query = query.neq(key, value);
        }
      }

      if (options?.gt) {
        for (const [key, value] of Object.entries(options.gt)) {
          query = query.gt(key, value);
        }
      }

      if (options?.gte) {
        for (const [key, value] of Object.entries(options.gte)) {
          query = query.gte(key, value);
        }
      }

      if (options?.lt) {
        for (const [key, value] of Object.entries(options.lt)) {
          query = query.lt(key, value);
        }
      }

      if (options?.lte) {
        for (const [key, value] of Object.entries(options.lte)) {
          query = query.lte(key, value);
        }
      }

      if (options?.like) {
        for (const [key, value] of Object.entries(options.like)) {
          query = query.like(key, value);
        }
      }

      if (options?.ilike) {
        for (const [key, value] of Object.entries(options.ilike)) {
          query = query.ilike(key, value);
        }
      }

      if (options?.in) {
        for (const [key, value] of Object.entries(options.in)) {
          query = query.in(key, value);
        }
      }

      if (options?.is) {
        for (const [key, value] of Object.entries(options.is)) {
          query = query.is(key, value);
        }
      }

      // Apply ordering
      if (options?.order) {
        for (const { column, ascending } of options.order) {
          query = query.order(column, { ascending: ascending ?? true });
        }
      }

      // Apply pagination
      if (options?.range) {
        query = query.range(options.range.from, options.range.to);
      }

      if (options?.limit) {
        query = query.limit(options.limit);
      }

      const { data, error } = await query;

      if (error) {
        this.logger.error(`Query error on ${table}: ${error.message}`);
        return { data: null, error };
      }

      return { data: data as T[], error: null };
    } catch (error) {
      this.logger.error(`Unexpected error querying ${table}:`, error);
      return {
        data: null,
        error: error instanceof Error ? error : new Error('Unknown error'),
      };
    }
  }

  async findById<T>(table: string, id: string): Promise<{ data: T | null; error: Error | null }> {
    try {
      const { data, error } = await this.client.from(table).select('*').eq('id', id).single();

      if (error) {
        return { data: null, error };
      }

      return { data: data as T, error: null };
    } catch (error) {
      this.logger.error(`Unexpected error finding by ID in ${table}:`, error);
      return {
        data: null,
        error: error instanceof Error ? error : new Error('Unknown error'),
      };
    }
  }

  async insert<T>(
    table: string,
    data: Partial<T>,
  ): Promise<{ data: T | null; error: Error | null }> {
    try {
      const { data: inserted, error } = await this.client
        .from(table)
        .insert(data as Record<string, unknown>)
        .select()
        .single();

      if (error) {
        this.logger.error(`Insert error on ${table}: ${error.message}`);
        return { data: null, error };
      }

      return { data: inserted as T, error: null };
    } catch (error) {
      this.logger.error(`Unexpected error inserting into ${table}:`, error);
      return {
        data: null,
        error: error instanceof Error ? error : new Error('Unknown error'),
      };
    }
  }

  async update<T>(
    table: string,
    id: string,
    data: Partial<T>,
  ): Promise<{ data: T | null; error: Error | null }> {
    try {
      const { data: updated, error } = await this.client
        .from(table)
        .update({ ...data, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        this.logger.error(`Update error on ${table}: ${error.message}`);
        return { data: null, error };
      }

      return { data: updated as T, error: null };
    } catch (error) {
      this.logger.error(`Unexpected error updating ${table}:`, error);
      return {
        data: null,
        error: error instanceof Error ? error : new Error('Unknown error'),
      };
    }
  }

  async delete(table: string, id: string): Promise<{ success: boolean; error: Error | null }> {
    try {
      const { error } = await this.client.from(table).delete().eq('id', id);

      if (error) {
        this.logger.error(`Delete error on ${table}: ${error.message}`);
        return { success: false, error };
      }

      return { success: true, error: null };
    } catch (error) {
      this.logger.error(`Unexpected error deleting from ${table}:`, error);
      return {
        success: false,
        error: error instanceof Error ? error : new Error('Unknown error'),
      };
    }
  }

  async rpc<T>(
    functionName: string,
    params?: Record<string, unknown>,
  ): Promise<{ data: T | null; error: Error | null }> {
    try {
      const { data, error } = await this.client.rpc(functionName, params);

      if (error) {
        this.logger.error(`RPC error calling ${functionName}: ${error.message}`);
        return { data: null, error };
      }

      return { data: data as T, error: null };
    } catch (error) {
      this.logger.error(`Unexpected error calling RPC ${functionName}:`, error);
      return {
        data: null,
        error: error instanceof Error ? error : new Error('Unknown error'),
      };
    }
  }
}
