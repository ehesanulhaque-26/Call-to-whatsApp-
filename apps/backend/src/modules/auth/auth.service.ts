import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export interface SupabaseUser {
  id: string;
  email: string;
  role: string;
  name?: string;
}

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
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(private readonly supabaseService: SupabaseService) {}

  /**
   * Verify Supabase JWT token and extract user info
   */
  async verifySupabaseToken(token: string): Promise<SupabaseUser> {
    try {
      // Use Supabase service role client to verify the JWT
      const {
        data: { user },
        error,
      } = await this.supabaseService.getClient('service').auth.getUser(token);

      if (error || !user) {
        this.logger.error('Token verification failed:', error?.message);
        throw new UnauthorizedException('Invalid or expired token');
      }

      return {
        id: user.id,
        email: user.email || '',
        role: 'user', // Default role, will be overridden by profile check
      };
    } catch (error) {
      this.logger.error('Token verification error:', error);
      throw new UnauthorizedException('Invalid or expired token');
    }
  }

  /**
   * Get user profile from database
   */
  async getProfile(userId: string): Promise<Profile | null> {
    const { data, error } = await this.supabaseService.findById<Profile>('profiles', userId);

    if (error || !data) {
      this.logger.warn(`Profile not found for user: ${userId}`);
      return null;
    }

    return data;
  }

  /**
   * Get user with profile (combined user info)
   */
  async getUserWithProfile(
    token: string,
  ): Promise<{ user: SupabaseUser; profile: Profile } | null> {
    const user = await this.verifySupabaseToken(token);
    const profile = await this.getProfile(user.id);

    if (!profile) {
      return null;
    }

    return { user, profile };
  }

  /**
   * Update user profile
   */
  async updateProfile(userId: string, updates: Partial<Profile>): Promise<Profile> {
    const { data, error } = await this.supabaseService.update<Profile>('profiles', userId, updates);

    if (error || !data) {
      this.logger.error('Failed to update profile:', error);
      throw new Error('Failed to update profile');
    }

    return data;
  }

  /**
   * Check if user is admin
   */
  async isAdmin(userId: string): Promise<boolean> {
    const profile = await this.getProfile(userId);
    return profile?.role === 'admin';
  }
}
