export class User {
  id: string;
  email: string;
  name: string;
  password_hash: string;
  role: string;
  avatar_url?: string;
  phone?: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}

export class CreateUserDto {
  name: string;
  email: string;
  password: string;
}

export class UpdateUserDto {
  name?: string;
  email?: string;
  phone?: string;
  avatar_url?: string;
}
