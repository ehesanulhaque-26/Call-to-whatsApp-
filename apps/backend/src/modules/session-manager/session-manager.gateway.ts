import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { SessionManagerService, SessionEvent } from './session-manager.service';
import { SupabaseService } from '../supabase/supabase.service';
import { OnEvent } from '@nestjs/event-emitter';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  userEmail?: string;
  userRole?: string;
}

@WebSocketGateway({
  cors: {
    origin: '*',
    credentials: true,
  },
  namespace: '/openwa',
})
export class SessionManagerGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(SessionManagerGateway.name);
  private userSockets: Map<string, Set<string>> = new Map();

  @WebSocketServer()
  server: Server;

  constructor(
    private readonly sessionManager: SessionManagerService,
    private readonly supabaseService: SupabaseService,
  ) {}

  afterInit(): void {
    this.logger.log('WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket): Promise<void> {
    try {
      const token =
        client.handshake.auth?.token ||
        client.handshake.headers?.authorization?.replace('Bearer ', '');

      if (!token) {
        this.logger.warn(`Client ${client.id} connected without token`);
        client.emit('error', { message: 'Authentication required' });
        client.disconnect();
        return;
      }

      // Verify token using Supabase (same as REST API)
      const { user, error } = await this.supabaseService.verifyToken(token);

      if (error || !user) {
        this.logger.warn(`Client ${client.id} with invalid token: ${error?.message}`);
        client.emit('error', { message: 'Invalid token' });
        client.disconnect();
        return;
      }

      // Set user info from Supabase verification
      client.userId = user.id;
      client.userEmail = user.email;
      client.userRole = 'user'; // Default role, profile check happens in operations

      // Track socket
      const userSocketIds = this.userSockets.get(client.userId!) || new Set();
      userSocketIds.add(client.id);
      this.userSockets.set(client.userId!, userSocketIds);

      this.logger.log(`Client connected: ${client.id} (user: ${client.userId})`);

      // Send connected event
      client.emit('connected', {
        userId: client.userId,
        timestamp: new Date().toISOString(),
      });

      // Send user's current sessions
      const sessions = this.sessionManager.getUserSessions(client.userId!);
      client.emit('sessions_state', {
        sessions: sessions.map((s) => ({
          sessionId: s.sessionId,
          status: s.status,
          phone: s.phone,
        })),
      });
    } catch (error) {
      this.logger.error(`Connection error: ${client.id}`, error);
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket): Promise<void> {
    if (client.userId) {
      const userSocketIds = this.userSockets.get(client.userId);
      if (userSocketIds) {
        userSocketIds.delete(client.id);
        if (userSocketIds.size === 0) {
          this.userSockets.delete(client.userId);
        }
      }
    }
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('create_session')
  async handleCreateSession(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionName?: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      const session = await this.sessionManager.createSession(client.userId, data.sessionName);

      client.emit('session_created', {
        sessionId: session.sessionId,
        status: session.status,
      });
    } catch (error) {
      this.logger.error(`Create session error: ${error}`);
      client.emit('error', { message: 'Failed to create session' });
    }
  }

  @SubscribeMessage('get_qr')
  async handleGetQR(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      const qr = await this.sessionManager.getQRCode(data.sessionId, client.userId);

      if (qr) {
        client.emit('qr_generated', { sessionId: data.sessionId, qr });
      } else {
        client.emit('qr_expired', { sessionId: data.sessionId });
      }
    } catch (error) {
      this.logger.error(`Get QR error: ${error}`);
      client.emit('error', { message: 'Failed to get QR code' });
    }
  }

  @SubscribeMessage('init_session')
  async handleInitSession(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      await this.sessionManager.initializeSession(data.sessionId, client.userId);
    } catch (error) {
      this.logger.error(`Init session error: ${error}`);
      client.emit('error', { message: 'Failed to initialize session' });
    }
  }

  @SubscribeMessage('reconnect')
  async handleReconnect(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      await this.sessionManager.reconnect(data.sessionId, client.userId);
    } catch (error) {
      this.logger.error(`Reconnect error: ${error}`);
      client.emit('error', { message: 'Failed to reconnect' });
    }
  }

  @SubscribeMessage('logout')
  async handleLogout(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      await this.sessionManager.logout(data.sessionId, client.userId);
    } catch (error) {
      this.logger.error(`Logout error: ${error}`);
      client.emit('error', { message: 'Failed to logout' });
    }
  }

  @SubscribeMessage('destroy_session')
  async handleDestroySession(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      await this.sessionManager.destroySession(data.sessionId, client.userId);
    } catch (error) {
      this.logger.error(`Destroy session error: ${error}`);
      client.emit('error', { message: 'Failed to destroy session' });
    }
  }

  @SubscribeMessage('sync_contacts')
  async handleSyncContacts(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      const result = await this.sessionManager.syncContacts(data.sessionId, client.userId);
      client.emit('contacts_synced', { sessionId: data.sessionId, count: result.synced });
    } catch (error) {
      this.logger.error(`Sync contacts error: ${error}`);
      client.emit('error', { message: 'Failed to sync contacts' });
    }
  }

  @SubscribeMessage('get_sessions')
  async handleGetSessions(@ConnectedSocket() client: AuthenticatedSocket): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    const sessions = this.sessionManager.getUserSessions(client.userId);
    client.emit('sessions_list', {
      sessions: sessions.map((s) => ({
        sessionId: s.sessionId,
        status: s.status,
        phone: s.phone,
        deviceName: s.deviceName,
        messageCount: s.messageCount,
      })),
    });
  }

  @SubscribeMessage('get_status')
  async handleGetStatus(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { sessionId: string },
  ): Promise<void> {
    if (!client.userId) {
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    try {
      const status = await this.sessionManager.getSessionStatus(data.sessionId, client.userId);
      client.emit('session_status', { sessionId: data.sessionId, ...status });
    } catch (error) {
      this.logger.error(`Get status error: ${error}`);
      client.emit('error', { message: 'Failed to get status' });
    }
  }

  @OnEvent('session.event')
  handleSessionEvent(event: SessionEvent): void {
    // Only send events to the user who owns the session
    this.sendToUser(event.userId, event.event, {
      sessionId: event.sessionId,
      ...event.data,
      timestamp: event.timestamp.toISOString(),
    });
  }

  private sendToUser(userId: string, event: string, data: Record<string, unknown>): void {
    const socketIds = this.userSockets.get(userId);
    if (!socketIds) {
      return;
    }

    for (const socketId of socketIds) {
      this.server.to(socketId).emit(event, data);
    }
  }

  // Admin: Get all active sessions
  @SubscribeMessage('admin_get_stats')
  async handleAdminGetStats(@ConnectedSocket() client: AuthenticatedSocket): Promise<void> {
    if (!client.userId || client.userRole !== 'admin') {
      client.emit('error', { message: 'Admin access required' });
      return;
    }

    const allSessions = this.sessionManager.getAllSessions();
    const stats = {
      totalSessions: allSessions.length,
      connectedSessions: allSessions.filter((s) => s.status === 'connected' || s.status === 'ready')
        .length,
      disconnectedSessions: allSessions.filter((s) => s.status === 'disconnected').length,
      totalMessages: allSessions.reduce((sum, s) => sum + s.messageCount, 0),
      sessions: allSessions.map((s) => ({
        sessionId: s.sessionId,
        userId: s.userId,
        status: s.status,
        phone: s.phone,
      })),
    };

    client.emit('admin_stats', stats);
  }
}
