import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { AuthService, Profile } from './auth.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current user profile' })
  @ApiResponse({ status: 200, description: 'Current user profile' })
  @ApiUnauthorizedResponse({ description: 'Unauthorized' })
  async getProfile(@CurrentUser() user: { userId: string }) {
    const profile = await this.authService.getProfile(user.userId);
    return profile;
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update current user profile' })
  @ApiResponse({ status: 200, description: 'Updated profile' })
  @ApiUnauthorizedResponse({ description: 'Unauthorized' })
  async updateProfile(
    @CurrentUser() user: { userId: string },
    @Body() updates: { name?: string; phone?: string; avatar_url?: string },
  ): Promise<Profile> {
    return this.authService.updateProfile(user.userId, updates);
  }

  @Get('verify')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Verify token is valid' })
  @ApiResponse({ status: 200, description: 'Token is valid' })
  @ApiUnauthorizedResponse({ description: 'Invalid token' })
  async verifyToken(@CurrentUser() user: { userId: string; email: string; role: string }) {
    return {
      valid: true,
      userId: user.userId,
      email: user.email,
      role: user.role,
    };
  }
}
