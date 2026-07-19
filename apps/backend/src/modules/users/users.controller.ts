import {
  Controller,
  Get,
  Patch,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';
import { UsersService, Profile } from './users.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('profiles')
@ApiBearerAuth()
@Controller('profiles')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @Roles('admin')
  @ApiOperation({ summary: 'Get all profiles (admin only)' })
  @ApiResponse({
    status: 200,
    description: 'List of all profiles',
  })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'role', required: false, type: String })
  async findAll(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('role') role?: string,
  ) {
    return this.usersService.findAll({ page, limit, role });
  }

  @Get(':id')
  @Roles('admin')
  @ApiOperation({ summary: 'Get profile by ID (admin only)' })
  @ApiResponse({
    status: 200,
    description: 'Profile details',
  })
  async findOne(@Param('id') id: string): Promise<Profile> {
    return this.usersService.findById(id);
  }

  @Patch(':id/role')
  @Roles('admin')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update user role (admin only)' })
  @ApiResponse({
    status: 200,
    description: 'Role updated successfully',
  })
  async updateRole(
    @Param('id') id: string,
    @Body('role') role: 'admin' | 'user',
  ): Promise<Profile> {
    return this.usersService.updateRole(id, role);
  }
}
