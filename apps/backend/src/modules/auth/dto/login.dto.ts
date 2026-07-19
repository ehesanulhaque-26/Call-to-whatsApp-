import { IsEmail, IsNotEmpty, IsString, MinLength, IsOptional, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'password123' })
  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  password: string;

  @ApiProperty({ example: false, required: false })
  @IsOptional()
  @IsBoolean()
  rememberMe?: boolean;

  @ApiProperty({ example: 'iPhone 15 Pro', required: false })
  @IsOptional()
  @IsString()
  deviceInfo?: string;
}
