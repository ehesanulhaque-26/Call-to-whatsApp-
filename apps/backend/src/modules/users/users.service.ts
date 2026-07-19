import { Injectable, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export interface Profile {
  id: string;
  name: string;
  role: string;
  phone?: string;
  avatar_url?: string;
  subscription_plan: string;
  subscription_status: string;
  subscription_expires_at?: string;
  created_at: string;
  updated_at: string;
}

@Injectable()
export class UsersService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async findById(id: string): Promise<Profile> {
    const { data, error } = await this.supabaseService.findById<Profile>('profiles', id);

    if (error || !data) {
      throw new NotFoundException('Profile not found');
    }

    return data;
  }

  async findAll(options?: {
    page?: number;
    limit?: number;
    role?: string;
  }): Promise<{ profiles: Profile[]; total: number }> {
    const page = options?.page || 1;
    const limit = options?.limit || 20;
    const offset = (page - 1) * limit;

    const queryOptions: Parameters<typeof this.supabaseService.query>[1] = {
      order: [{ column: 'created_at', ascending: false }],
      range: { from: offset, to: offset + limit - 1 },
    };

    if (options?.role) {
      queryOptions.eq = { role: options.role };
    }

    const { data, error } = await this.supabaseService.query<Profile>('profiles', queryOptions);

    if (error) {
      throw new Error('Failed to fetch profiles');
    }

    // Get total count
    const { data: countData } = await this.supabaseService.query<{ count: number }>('profiles', {
      select: 'id',
    });

    const total = countData?.length || 0;

    return { profiles: data || [], total };
  }

  async update(id: string, updates: Partial<Profile>): Promise<Profile> {
    const { data, error } = await this.supabaseService.update<Profile>('profiles', id, updates);

    if (error || !data) {
      throw new NotFoundException('Profile not found or update failed');
    }

    return data;
  }

  async updateRole(id: string, role: 'admin' | 'user'): Promise<Profile> {
    return this.update(id, { role });
  }
}
