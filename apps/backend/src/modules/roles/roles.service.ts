import { Injectable } from '@nestjs/common';

// Define available roles
export enum Role {
  ADMIN = 'admin',
  USER = 'user',
}

@Injectable()
export class RolesService {
  private readonly roles: string[] = [Role.ADMIN, Role.USER];

  getRoles(): string[] {
    return this.roles;
  }

  isValidRole(role: string): boolean {
    return this.roles.includes(role);
  }
}
