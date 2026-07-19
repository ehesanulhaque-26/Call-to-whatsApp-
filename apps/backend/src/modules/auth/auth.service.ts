import { Injectable, UnauthorizedException, ConflictException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { SupabaseService } from '../supabase/supabase.service';
import { User } from '../users/entities/user.entity';

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
}

export interface AuthResponse {
  accessToken: string;
  user: User;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly supabaseService: SupabaseService,
    private readonly configService: ConfigService,
  ) {}

  async validateUser(email: string, password: string): Promise<User | null> {
    const { data, error } = await this.supabaseService.query<User>('users', {
      eq: { email, 'deleted_at': 'null' },
      limit: 1,
    });

    if (error || !data || data.length === 0) {
      return null;
    }

    const user = data[0];
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      return null;
    }

    return user;
  }

  async login(email: string, password: string): Promise<AuthResponse> {
    const user = await this.validateUser(email, password);

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user,
    };
  }

  async register(createUserDto: { name: string; email: string; password: string }): Promise<User> {
    // Check if user exists
    const { data: existingUser } = await this.supabaseService.query('users', {
      eq: { email: createUserDto.email },
      limit: 1,
    });

    if (existingUser && existingUser.length > 0) {
      throw new ConflictException('User with this email already exists');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(createUserDto.password, 10);

    // Create user
    const { data, error } = await this.supabaseService.insert<User>('users', {
      email: createUserDto.email,
      name: createUserDto.name,
      password_hash: passwordHash,
      role: 'user',
    });

    if (error || !data) {
      this.logger.error('Failed to create user:', error);
      throw new ConflictException('Failed to create user');
    }

    return data;
  }

  async forgotPassword(email: string): Promise<void> {
    // Check if user exists
    const { data } = await this.supabaseService.query<User>('users', {
      eq: { email, 'deleted_at': 'null' },
      limit: 1,
    });

    if (!data || data.length === 0) {
      // Don't reveal if user exists for security
      this.logger.log(`Password reset requested for non-existent email: ${email}`);
      return;
    }

    // In production, send password reset email here
    // For now, just log it
    this.logger.log(`Password reset requested for: ${email}`);
  }

  async resetPassword(token: string, newPassword: string): Promise<boolean> {
    // In production, verify the reset token and reset password
    // This is a placeholder implementation
    this.logger.log(`Password reset attempted with token: ${token}`);
    return true;
  }

  async verifyToken(token: string): Promise<JwtPayload> {
    try {
      return this.jwtService.verify<JwtPayload>(token);
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}
