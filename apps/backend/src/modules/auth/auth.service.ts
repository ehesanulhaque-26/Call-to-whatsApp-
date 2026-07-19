import { Injectable, UnauthorizedException, ConflictException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { SupabaseService } from '../supabase/supabase.service';
import { User } from '../users/entities/user.entity';

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
  type: 'access' | 'refresh';
  jti?: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: User;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly accessTokenExpiresIn: string;
  private readonly refreshTokenExpiresIn: string;

  constructor(
    private readonly jwtService: JwtService,
    private readonly supabaseService: SupabaseService,
    private readonly configService: ConfigService,
  ) {
    this.accessTokenExpiresIn = this.configService.get<string>('ACCESS_TOKEN_EXPIRES_IN', '15m');
    this.refreshTokenExpiresIn = this.configService.get<string>('REFRESH_TOKEN_EXPIRES_IN', '7d');
  }

  private parseExpiration(exp: string): number {
    const match = exp.match(/^(\d+)([smhd])$/);
    if (!match) return 900;

    const value = parseInt(match[1], 10);
    const unit = match[2];

    switch (unit) {
      case 's':
        return value;
      case 'm':
        return value * 60;
      case 'h':
        return value * 60 * 60;
      case 'd':
        return value * 60 * 60 * 24;
      default:
        return 900;
    }
  }

  private generateRefreshToken(): string {
    return crypto.randomBytes(64).toString('hex');
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  private async saveRefreshToken(
    userId: string,
    token: string,
    deviceInfo?: string,
    ipAddress?: string,
    userAgent?: string,
  ): Promise<string> {
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    const { error } = await this.supabaseService.insert('refresh_tokens', {
      user_id: userId,
      token_hash: tokenHash,
      device_info: deviceInfo,
      ip_address: ipAddress,
      user_agent: userAgent,
      expires_at: expiresAt.toISOString(),
    });

    if (error) {
      this.logger.error('Failed to save refresh token:', error);
      throw new Error('Failed to save refresh token');
    }

    return token;
  }

  private async validateRefreshToken(
    token: string,
  ): Promise<{ valid: boolean; tokenId?: string; userId?: string }> {
    const tokenHash = this.hashToken(token);

    const { data, error } = await this.supabaseService.query<{
      id: string;
      user_id: string;
      is_revoked: boolean;
      expires_at: string;
    }>('refresh_tokens', {
      eq: { token_hash: tokenHash },
      limit: 1,
    });

    if (error || !data || data.length === 0) {
      return { valid: false };
    }

    const refreshToken = data[0];

    if (refreshToken.is_revoked) {
      return { valid: false };
    }

    if (new Date(refreshToken.expires_at) < new Date()) {
      return { valid: false };
    }

    return {
      valid: true,
      tokenId: refreshToken.id,
      userId: refreshToken.user_id,
    };
  }

  private async revokeRefreshToken(tokenId: string): Promise<void> {
    await this.supabaseService.update('refresh_tokens', tokenId, {
      is_revoked: true,
      revoked_at: new Date().toISOString(),
    });
  }

  async validateUser(email: string, password: string): Promise<User | null> {
    const { data, error } = await this.supabaseService.query<User>('users', {
      eq: { email, deleted_at: 'null' },
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

  async login(
    email: string,
    password: string,
    deviceInfo?: string,
    ipAddress?: string,
    userAgent?: string,
    rememberMe?: boolean,
  ): Promise<AuthResponse> {
    const user = await this.validateUser(email, password);

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const accessPayload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      type: 'access',
    };

    const accessToken = this.jwtService.sign(accessPayload, {
      expiresIn: rememberMe ? '30d' : this.accessTokenExpiresIn,
    });

    const refreshToken = this.generateRefreshToken();
    await this.saveRefreshToken(user.id, refreshToken, deviceInfo, ipAddress, userAgent);

    return {
      accessToken,
      refreshToken,
      expiresIn: this.parseExpiration(this.accessTokenExpiresIn),
      user,
    };
  }

  async register(createUserDto: { name: string; email: string; password: string }): Promise<User> {
    const { data: existingUser } = await this.supabaseService.query('users', {
      eq: { email: createUserDto.email },
      limit: 1,
    });

    if (existingUser && existingUser.length > 0) {
      throw new ConflictException('User with this email already exists');
    }

    const passwordHash = await bcrypt.hash(createUserDto.password, 10);

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

  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    const validation = await this.validateRefreshToken(refreshToken);

    if (!validation.valid || !validation.tokenId || !validation.userId) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    await this.revokeRefreshToken(validation.tokenId);

    const { data: user, error } = await this.supabaseService.findById<User>(
      'users',
      validation.userId,
    );

    if (error || !user || user.deleted_at) {
      throw new UnauthorizedException('User not found');
    }

    const accessPayload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      type: 'access',
    };

    const newAccessToken = this.jwtService.sign(accessPayload, {
      expiresIn: this.accessTokenExpiresIn,
    });

    const newRefreshToken = this.generateRefreshToken();
    await this.saveRefreshToken(user.id, newRefreshToken);

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      expiresIn: this.parseExpiration(this.accessTokenExpiresIn),
    };
  }

  async logout(refreshToken: string): Promise<boolean> {
    const validation = await this.validateRefreshToken(refreshToken);

    if (validation.valid && validation.tokenId) {
      await this.revokeRefreshToken(validation.tokenId);
      return true;
    }

    return false;
  }

  async logoutAll(userId: string): Promise<boolean> {
    const { data: tokens } = await this.supabaseService.query<{ id: string }>('refresh_tokens', {
      eq: { user_id: userId },
    });

    if (tokens) {
      for (const token of tokens) {
        await this.supabaseService.update('refresh_tokens', token.id, {
          is_revoked: true,
          revoked_at: new Date().toISOString(),
        });
      }
    }

    return true;
  }

  async forgotPassword(email: string): Promise<void> {
    const { data } = await this.supabaseService.query<User>('users', {
      eq: { email, deleted_at: 'null' },
      limit: 1,
    });

    if (!data || data.length === 0) {
      this.logger.log(`Password reset requested for non-existent email: ${email}`);
      return;
    }

    this.logger.log(`Password reset requested for: ${email}`);
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async resetPassword(token: string, newPassword: string): Promise<boolean> {
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
