import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, Matches, MinLength, MaxLength } from 'class-validator';

/**
 * DTO for requesting a pairing code for phone number authentication
 */
export class RequestPairingCodeDto {
  @ApiProperty({
    description: 'Phone number in international format (e.g., +919876543210)',
    example: '+919876543210',
    pattern: '^\\+?\\d{10,15}$',
    minLength: 10,
    maxLength: 16,
  })
  @IsString()
  @IsNotEmpty({ message: 'Phone number is required' })
  @MinLength(10, { message: 'Phone number must be at least 10 digits' })
  @MaxLength(16, { message: 'Phone number must not exceed 16 digits' })
  @Matches(/^\+?\d{10,15}$/, {
    message: 'Phone number must be in international format (e.g., +919876543210)',
  })
  phoneNumber: string;
}
