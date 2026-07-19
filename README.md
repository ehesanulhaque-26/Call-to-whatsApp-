# OpenWA SaaS (Android First)

A production-ready SaaS platform built around OpenWA for WhatsApp automation.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Android)                  │
│                 Material 3, Riverpod, GoRouter           │
└─────────────────────────────┬───────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                    NestJS Backend                        │
│              TypeScript, JWT, Swagger, RLS              │
└─────────────────────────────┬───────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       ┌──────────┐    ┌──────────┐   ┌──────────┐
       │ Supabase │    │  OpenWA  │   │ Railway  │
       │ PostgreSQL│    │ REST API │   │ (Hosting)│
       └──────────┘    └──────────┘   └──────────┘
```

## Project Structure

```
openwa-saas/
├── apps/
│   ├── flutter_app/           # Flutter Android application
│   │   ├── lib/
│   │   │   ├── core/         # Core utilities
│   │   │   │   ├── constants/ # Environment variables
│   │   │   │   ├── router/    # GoRouter configuration
│   │   │   │   ├── services/  # API client, secure storage
│   │   │   │   ├── theme/     # Material 3 theme, tokens
│   │   │   │   └── widgets/    # Reusable components
│   │   │   ├── features/       # Feature modules
│   │   │   │   ├── auth/       # Authentication screens
│   │   │   │   └── home/       # Home screen
│   │   │   └── main.dart       # Entry point
│   │   └── android/            # Android configuration
│   │
│   └── backend/               # NestJS API server
│       ├── src/
│       │   ├── config/         # Configuration module
│       │   ├── common/          # Guards, filters, decorators
│       │   └── modules/
│       │       ├── auth/        # Authentication
│       │       ├── users/       # User management
│       │       ├── roles/       # Role management
│       │       ├── openwa/       # OpenWA integration
│       │       ├── health/      # Health checks
│       │       └── supabase/     # Database service
│       └── supabase/
│           └── migrations/     # Database schema
│
└── packages/                  # Shared packages (Phase 2+)
    └── shared/
```

## Features (Phase 1 - Complete)

### Flutter App
- ✅ Splash screen with animations
- ✅ Login screen with email/password
- ✅ Registration screen with validation
- ✅ Forgot password flow
- ✅ Home dashboard with placeholder stats
- ✅ Material 3 design system with dark/light mode
- ✅ GoRouter navigation with auth guards
- ✅ Riverpod state management
- ✅ Dio API client with interceptors
- ✅ Flutter Secure Storage for tokens

### Backend
- ✅ Config module with environment validation
- ✅ Supabase module for database access
- ✅ JWT authentication with Passport
- ✅ User management with CRUD operations
- ✅ Role-based access control (admin/user)
- ✅ OpenWA service wrapper
- ✅ Health check endpoints
- ✅ Swagger documentation
- ✅ Validation pipes
- ✅ Global exception filter

### Database Schema
- ✅ Users table with soft delete
- ✅ Profiles table
- ✅ Subscriptions table
- ✅ Sessions table (WhatsApp)
- ✅ Automations table
- ✅ Campaigns table
- ✅ Contacts table
- ✅ Notifications table
- ✅ Activity logs table
- ✅ Settings table
- ✅ Row Level Security policies
- ✅ Indexes and constraints

## Environment Variables

### Backend (.env)
```bash
# Server
PORT=3000
NODE_ENV=development

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key



# OpenWA
OPENWA_URL=http://localhost:8080
OPENWA_API_KEY=your-openwa-key
```

### Flutter App
```bash
API_BASE_URL=https://your-api.com/api/v1
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## Getting Started

### Prerequisites
- Node.js 18+
- Flutter 3.x
- Supabase account
- OpenWA instance deployed

### Backend Setup

```bash
cd apps/backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env
# Edit .env with your values

# Run database migrations
# (Apply the SQL in supabase/migrations/ to your Supabase project)

# Start development server
npm run start:dev

# Build for production
npm run build
npm run start:prod
```

### Flutter Setup

```bash
cd apps/flutter_app

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build release APK
flutter build apk --release
```

## API Endpoints

All endpoints are prefixed with `/api/v1`

### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/logout` - User logout

### Users
- `GET /users/me` - Get current user profile
- `PATCH /users/me` - Update current user profile
- `GET /users` - List all users (admin)
- `GET /users/:id` - Get user by ID (admin)
- `PATCH /users/:id` - Update user (admin)
- `DELETE /users/:id` - Delete user (admin)

### OpenWA
- `GET /openwa/health` - Check OpenWA server health
- `POST /openwa/sessions` - Create WhatsApp session
- `GET /openwa/sessions/:id` - Get session details
- `GET /openwa/sessions/:id/status` - Get session status
- `GET /openwa/sessions/:id/qr` - Get QR code
- `POST /openwa/sessions/:id/send-text` - Send text message
- `GET /openwa/sessions/:id/chats` - Get all chats
- `GET /openwa/sessions/:id/contacts` - Get all contacts

### Health
- `GET /health` - Full health status
- `GET /health/ready` - Readiness probe
- `GET /health/live` - Liveness probe

## Swagger Documentation

When the backend is running, access Swagger at:
```
http://localhost:3000/docs
```

## Remaining Work (Phase 2+)

- Campaign management screens
- Automation builder UI
- Contact management
- Analytics dashboard
- Notification system
- Webhook integration
- Payment processing
- Email templates
- Push notifications
- Multi-language support

## License

MIT
