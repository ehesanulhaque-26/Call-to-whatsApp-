import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

// Backend version info - update with each deploy
const BACKEND_VERSION = process.env.BACKEND_VERSION || 'dev-local';
const BUILD_TIME = process.env.BUILD_TIME || new Date().toISOString();

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  // Print startup info for debugging deployment status
  console.log('═'.repeat(60));
  console.log('BACKEND STARTUP INFO');
  console.log('═'.repeat(60));
  console.log(`VERSION:        ${BACKEND_VERSION}`);
  console.log(`BUILD TIME:     ${BUILD_TIME}`);
  console.log(`SANITIZER:      ACTIVE`);
  console.log(`STARTED AT:     ${new Date().toISOString()}`);
  console.log('═'.repeat(60));

  const app = await NestFactory.create(AppModule);

  // Set global API prefix
  app.setGlobalPrefix('api/v1');

  // Enable CORS for Flutter and WebSocket
  app.enableCors({
    origin: '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Bearer'],
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('OpenWA SaaS API')
    .setDescription('Multi-tenant WhatsApp API for SaaS applications')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('auth', 'Authentication endpoints')
    .addTag('users', 'User management')
    .addTag('sessions', 'WhatsApp session management')
    .addTag('admin-sessions', 'Admin session management')
    .addTag('openwa', 'OpenWA integration')
    .addTag('health', 'Health checks')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);

  logger.log(`Application running on port ${port}`);
  logger.log(`Swagger documentation: http://localhost:${port}/api/docs`);
  logger.log(`WebSocket endpoint: ws://localhost:${port}/openwa`);
}

bootstrap();
