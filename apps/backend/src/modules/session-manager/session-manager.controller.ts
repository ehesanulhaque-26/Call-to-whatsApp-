import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation, ApiResponse, ApiParam } from '@nestjs/swagger';
import { Request } from 'express';
import { SessionManagerService } from './session-manager.service';
import { SupabaseService } from '../supabase/supabase.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ActivityLogService } from './activity-log.service';

interface AuthenticatedRequest extends Request {
  user: {
    userId: string;
    email: string;
    role: string;
  };
}

@ApiTags('sessions')
@ApiBearerAuth()
@Controller('sessions')
@UseGuards(JwtAuthGuard)
export class SessionManagerController {
  constructor(
    private readonly sessionManager: SessionManagerService,
    private readonly supabaseService: SupabaseService,
    private readonly activityLogService: ActivityLogService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Get all sessions for current user' })
  @ApiResponse({ status: 200, description: 'User sessions' })
  async getSessions(@Req() req: AuthenticatedRequest) {
    const sessions = this.sessionManager.getUserSessions(req.user.userId);
    return {
      sessions: sessions.map((s) => ({
        sessionId: s.sessionId,
        status: s.status,
        phone: s.phone,
        deviceName: s.deviceName,
        messageCount: s.messageCount,
        lastActivity: s.lastActivity,
      })),
    };
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new session and start it to get QR code' })
  @ApiResponse({ status: 201, description: 'Session created and started' })
  async createSession(@Req() req: AuthenticatedRequest, @Body('sessionName') sessionName?: string) {
    console.log(
      `[SessionManager] CREATE SESSION - Starting flow for user ${req.user.userId}, name: ${sessionName}`,
    );

    // Step 1: Create the session
    console.log(`[SessionManager] CREATE SESSION - Step 1: Creating session...`);
    const session = await this.sessionManager.createSession(req.user.userId, sessionName);
    console.log(`[SessionManager] CREATE SESSION - Step 1: Session created: ${session.sessionId}`);

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'session_created',
      details: `Session ${session.sessionId} created`,
      ipAddress: req.ip,
    });

    // Step 2: Start the session (this triggers QR generation)
    console.log(
      `[SessionManager] CREATE SESSION - Step 2: Starting session ${session.sessionId}...`,
    );
    await this.sessionManager.startSession(session.sessionId, req.user.userId);
    console.log(`[SessionManager] CREATE SESSION - Step 2: Session start initiated`);

    // Step 3: Poll for QR status until QR_READY or timeout
    console.log(`[SessionManager] CREATE SESSION - Step 3: Polling for QR status...`);
    const qrCode = await this.sessionManager.pollForQRCode(session.sessionId, req.user.userId);
    console.log(
      `[SessionManager] CREATE SESSION - Step 3: QR code received: ${qrCode ? 'YES (length: ' + qrCode.length + ')' : 'NO'}`,
    );

    return {
      sessionId: session.sessionId,
      status: 'qr_generated',
      qr: qrCode,
    };
  }

  @Get(':sessionId')
  @ApiOperation({ summary: 'Get session details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Session details' })
  async getSession(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    const session = this.sessionManager.getClientBySessionId(sessionId);

    if (!session || session.userId !== req.user.userId) {
      throw new Error('Session not found or access denied');
    }

    return {
      sessionId: session.sessionId,
      status: session.status,
      phone: session.phone,
      deviceName: session.deviceName,
      messageCount: session.messageCount,
      lastActivity: session.lastActivity,
    };
  }

  @Get(':sessionId/status')
  @ApiOperation({ summary: 'Get session status' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Session status' })
  async getSessionStatus(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    const status = await this.sessionManager.getSessionStatus(sessionId, req.user.userId);
    return status;
  }

  @Get(':sessionId/qr')
  @ApiOperation({ summary: 'Get QR code' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'QR code data' })
  async getQRCode(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    const qr = await this.sessionManager.getQRCode(sessionId, req.user.userId);

    if (!qr) {
      throw new Error('Failed to get QR code');
    }

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'qr_generated',
      details: `QR generated for session ${sessionId}`,
      ipAddress: req.ip,
    });

    return { qr };
  }

  @Post(':sessionId/init')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Initialize session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Session initialized' })
  async initializeSession(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    await this.sessionManager.initializeSession(sessionId, req.user.userId);
    return { success: true };
  }

  @Post(':sessionId/reconnect')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reconnect session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Reconnection started' })
  async reconnectSession(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    await this.sessionManager.reconnect(sessionId, req.user.userId);

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'session_reconnecting',
      details: `Session ${sessionId} reconnecting`,
      ipAddress: req.ip,
    });

    return { success: true };
  }

  @Post(':sessionId/logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Logout successful' })
  async logoutSession(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    await this.sessionManager.logout(sessionId, req.user.userId);

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'session_logout',
      details: `Session ${sessionId} logged out`,
      ipAddress: req.ip,
    });

    return { success: true };
  }

  @Delete(':sessionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 204, description: 'Session deleted' })
  async deleteSession(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    await this.sessionManager.destroySession(sessionId, req.user.userId);

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'session_deleted',
      details: `Session ${sessionId} deleted`,
      ipAddress: req.ip,
    });
  }

  // Messaging endpoints
  @Post(':sessionId/send-text')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send text message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Message sent' })
  async sendTextMessage(
    @Req() req: AuthenticatedRequest,
    @Param('sessionId') sessionId: string,
    @Body() body: { to: string; text: string },
  ) {
    const result = await this.sessionManager.sendTextMessage(
      sessionId,
      req.user.userId,
      body.to,
      body.text,
    );

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'message_sent',
      details: `Text message sent to ${body.to}`,
      ipAddress: req.ip,
    });

    return result;
  }

  @Post(':sessionId/send-media')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send media message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Media sent' })
  async sendMediaMessage(
    @Req() req: AuthenticatedRequest,
    @Param('sessionId') sessionId: string,
    @Body() body: { to: string; mediaUrl: string; caption?: string; mimetype?: string },
  ) {
    const result = await this.sessionManager.sendMediaMessage(
      sessionId,
      req.user.userId,
      body.to,
      body.mediaUrl,
      body.caption,
      body.mimetype,
    );

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'media_sent',
      details: `Media sent to ${body.to}`,
      ipAddress: req.ip,
    });

    return result;
  }

  // Contact endpoints
  @Get(':sessionId/contacts')
  @ApiOperation({ summary: 'Get contacts' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Contacts list' })
  async getContacts(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    const contacts = await this.sessionManager.getContacts(sessionId, req.user.userId);
    return { contacts };
  }

  @Post(':sessionId/sync-contacts')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sync contacts' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Contacts synced' })
  async syncContacts(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    const result = await this.sessionManager.syncContacts(sessionId, req.user.userId);

    await this.activityLogService.log({
      userId: req.user.userId,
      action: 'contacts_synced',
      details: `${result.synced} contacts synced`,
      ipAddress: req.ip,
    });

    return result;
  }

  // Chat endpoints
  @Get(':sessionId/chats')
  @ApiOperation({ summary: 'Get chats' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Chats list' })
  async getChats(@Req() req: AuthenticatedRequest, @Param('sessionId') sessionId: string) {
    const chats = await this.sessionManager.getChats(sessionId, req.user.userId);
    return { chats };
  }
}

// Admin controller for stats and management
@ApiTags('admin-sessions')
@ApiBearerAuth()
@Controller('admin/sessions')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminSessionController {
  constructor(
    private readonly sessionManager: SessionManagerService,
    private readonly supabaseService: SupabaseService,
  ) {}

  @Get('stats')
  @ApiOperation({ summary: 'Get session statistics' })
  @ApiResponse({ status: 200, description: 'Session statistics' })
  async getStats() {
    const allSessions = this.sessionManager.getAllSessions();

    // Get additional stats from database
    const { data: dbSessions } = await this.supabaseService.query('sessions', {
      select: 'count',
    });

    const { data: dbContacts } = await this.supabaseService.query('contacts', {
      select: 'count',
    });

    return {
      totalSessions: allSessions.length,
      connectedSessions: allSessions.filter((s) => s.status === 'connected' || s.status === 'ready')
        .length,
      disconnectedSessions: allSessions.filter(
        (s) => s.status === 'disconnected' || s.status === 'destroyed',
      ).length,
      totalMessages: allSessions.reduce((sum, s) => sum + s.messageCount, 0),
      dbSessionCount: dbSessions?.length || 0,
      dbContactCount: dbContacts?.length || 0,
      sessions: allSessions.map((s) => ({
        sessionId: s.sessionId,
        userId: s.userId,
        status: s.status,
        phone: s.phone,
        deviceName: s.deviceName,
      })),
    };
  }

  @Get(':sessionId')
  @ApiOperation({ summary: 'Get session details (admin)' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Session details' })
  async getAdminSession(@Param('sessionId') sessionId: string) {
    const session = this.sessionManager.getClientBySessionId(sessionId);

    if (!session) {
      throw new Error('Session not found');
    }

    return {
      sessionId: session.sessionId,
      userId: session.userId,
      status: session.status,
      phone: session.phone,
      deviceName: session.deviceName,
      messageCount: session.messageCount,
      lastActivity: session.lastActivity,
    };
  }

  @Delete(':sessionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete session (admin)' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 204, description: 'Session deleted' })
  async adminDeleteSession(@Param('sessionId') sessionId: string) {
    const session = this.sessionManager.getClientBySessionId(sessionId);

    if (!session) {
      throw new Error('Session not found');
    }

    await this.sessionManager.destroySession(sessionId, session.userId);
  }
}
