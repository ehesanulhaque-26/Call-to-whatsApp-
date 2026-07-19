import { Injectable, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { User } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async findById(id: string): Promise<User> {
    const { data, error } = await this.supabaseService.findById<User>('users', id);

    if (error || !data) {
      throw new NotFoundException('User not found');
    }

    return data;
  }

  async findByEmail(email: string): Promise<User | null> {
    const { data, error } = await this.supabaseService.query<User>('users', {
      eq: { email, 'deleted_at': 'null' },
      limit: 1,
    });

    if (error || !data || data.length === 0) {
      return null;
    }

    return data[0];
  }

  async findAll(options?: {
    page?: number;
    limit?: number;
    role?: string;
  }): Promise<{ users: User[]; total: number }> {
    const page = options?.page || 1;
    const limit = options?.limit || 20;
    const offset = (page - 1) * limit;

    const queryOptions: Parameters<typeof this.supabaseService.query>[1] = {
      eq: { 'deleted_at': 'null' },
      order: [{ column: 'created_at', ascending: false }],
      range: { from: offset, to: offset + limit - 1 },
    };

    if (options?.role) {
      queryOptions.eq = { ...queryOptions.eq, role: options.role };
    }

    const { data, error } = await this.supabaseService.query<User>('users', queryOptions);

    if (error) {
      throw new Error('Failed to fetch users');
    }

    // Get total count
    const { data: countData } = await this.supabaseService.query<{ count: number }>(
      'users',
      {
        eq: { 'deleted_at': 'null' },
        select: 'id',
      },
    );

    const total = countData?.length || 0;

    return { users: data || [], total };
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const { data, error } = await this.supabaseService.update<User>('users', id, updateUserDto);

    if (error || !data) {
      throw new NotFoundException('User not found or update failed');
    }

    return data;
  }

  async delete(id: string): Promise<void> {
    // Soft delete
    const { error } = await this.supabaseService.update('users', id, {
      deleted_at: new Date().toISOString(),
    });

    if (error) {
      throw new Error('Failed to delete user');
    }
  }
}
