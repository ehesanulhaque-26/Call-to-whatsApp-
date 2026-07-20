# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files from apps/backend
COPY apps/backend/package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY apps/backend/ ./

# Build the NestJS application
RUN npm run build

# Production stage
FROM node:22-alpine AS production

WORKDIR /app

# Copy package files
COPY apps/backend/package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Copy TypeScript config
COPY apps/backend/tsconfig.json ./

# Expose port (Railway will set PORT env var)
EXPOSE 3000

# Start the application
# Railway sets PORT env var, backend defaults to 3000
CMD ["node", "dist/main"]
