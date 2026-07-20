import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import axios, { AxiosInstance } from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';

export interface OpenWAClient {
  sessionId: string;
  userId: string;
  status: SessionStatus;
  phone?: string;
  deviceName?: string;
  qrCode?: string;
  lastActivity?: Date;
  messageCount: number;
  client: AxiosInstance;
}

export enum SessionStatus {
  CREATED = 'created',
  LOADING = 'loading',
  QR_GENERATED = 'qr_generated',
  QR_UPDATED = 'qr_updated',
  QR_EXPIRED = 'qr_expired',
  AUTHENTICATED = 'authenticated',
  CONNECTED = 'connected',
  READY = 'ready',
  DISCONNECTED = 'disconnected',
  RECONNECTING = 'reconnecting',
  DESTROYED = 'destroyed',
  ERROR = 'error',
}

export interface SessionEvent {
  sessionId: string;
  userId: string;
  event: SessionStatus;
  data?: Record<string, unknown>;
  timestamp: Date;
}

@Injectable()
export class SessionManagerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SessionManagerService.name);
  private readonly clients: Map<string, OpenWAClient> = new Map();
  private readonly userSessions: Map<string, string[]> = new Map();
  private readonly baseURL: string;
  private readonly sessionStoragePath: string;
  private readonly qrRefreshInterval = 20000;
  private qrTimers: Map<string, NodeJS.Timeout> = new Map();
  private reconnectTimers: Map<string, NodeJS.Timeout> = new Map();
  private cleanupInterval: NodeJS.Timeout | null = null;

  constructor(
    private readonly configService: ConfigService,
    private readonly eventEmitter: EventEmitter2,
  ) {
    this.baseURL = this.configService.get<string>('OPENWA_URL') || 'http://localhost:8080';
    this.sessionStoragePath = this.configService.get<string>('OPENWA_SESSION_PATH') || './sessions';
    this.ensureStorageDirectory();
  }

  private ensureStorageDirectory(): void {
    try {
      if (!fs.existsSync(this.sessionStoragePath)) {
        fs.mkdirSync(this.sessionStoragePath, { recursive: true });
        this.logger.log(`Created session storage directory: ${this.sessionStoragePath}`);
      }
    } catch (error) {
      this.logger.error('Failed to create session storage directory', error);
    }
  }

  async onModuleInit(): Promise<void> {
    this.logger.log('Session Manager initializing...');
    await this.restoreExistingSessions();
    this.startCleanupInterval();
    this.logger.log(`Session Manager ready. Active clients: ${this.clients.size}`);
  }

  async onModuleDestroy(): Promise<void> {
    this.logger.log('Session Manager shutting down...');
    this.stopCleanupInterval();
    this.stopAllQrTimers();
    this.stopAllReconnectTimers();
    for (const [sessionId] of this.clients.entries()) {
      await this.saveSessionState(sessionId);
    }
    this.clients.clear();
    this.userSessions.clear();
    this.logger.log('Session Manager shutdown complete');
  }

  private startCleanupInterval(): void {
    this.cleanupInterval = setInterval(() => {
      this.cleanupStaleSessions();
    }, 60000);
  }

  private stopCleanupInterval(): void {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
  }

  private stopAllQrTimers(): void {
    for (const timer of this.qrTimers.values()) {
      clearInterval(timer);
    }
    this.qrTimers.clear();
  }

  private stopAllReconnectTimers(): void {
    for (const timer of this.reconnectTimers.values()) {
      clearTimeout(timer);
    }
    this.reconnectTimers.clear();
  }

  private cleanupStaleSessions(): void {
    const now = Date.now();
    const staleThreshold = 30 * 60 * 1000;
    for (const [sessionId, client] of this.clients.entries()) {
      if (client.status === SessionStatus.DISCONNECTED) {
        const lastActivity = client.lastActivity?.getTime() || 0;
        if (now - lastActivity > staleThreshold) {
          this.logger.log(`Cleaning up stale session: ${sessionId}`);
          this.emitEvent(sessionId, client.userId, SessionStatus.DESTROYED);
        }
      }
    }
  }

  private createClient(sessionId: string): AxiosInstance {
    return axios.create({
      baseURL: this.baseURL,
      timeout: 30000,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  private emitEvent(sessionId: string, userId: string, event: SessionStatus, data?: Record<string, unknown>): void {
    const sessionEvent: SessionEvent = { sessionId, userId, event, data, timestamp: new Date() };
    this.eventEmitter.emit('session.event', sessionEvent);
    this.logger.debug(`Session event: ${sessionId} -> ${event}`);
  }

  private async request<T>(client: AxiosInstance, method: string, reqPath: string, data?: unknown): Promise<T> {
    try {
      const response = await client.request<T>({ method, url: reqPath, data });
      return response.data;
    } catch (error) {
      this.logger.error(`OpenWA API error: ${method} ${reqPath}`, error);
      throw error;
    }
  }

  async createSession(userId: string, sessionName?: string): Promise<OpenWAClient> {
    const sessionId = sessionName || `${userId}-${uuidv4().substring(0, 8)}`;
    const existingClient = this.getClientBySessionId(sessionId);
    if (existingClient) {
      this.logger.log(`Session ${sessionId} already exists`);
      return existingClient;
    }
    this.logger.log(`Creating session: ${sessionId} for user: ${userId}`);
    const client = this.createClient(sessionId);
    const openWAClient: OpenWAClient = { sessionId, userId, status: SessionStatus.CREATED, messageCount: 0, client };
    this.clients.set(sessionId, openWAClient);
    const userSessionIds = this.userSessions.get(userId) || [];
    userSessionIds.push(sessionId);
    this.userSessions.set(userId, userSessionIds);
    this.emitEvent(sessionId, userId, SessionStatus.CREATED);
    this.emitEvent(sessionId, userId, SessionStatus.LOADING);
    try {
      await this.request<{ sessionId: string }>(client, 'POST', '/sessions', { sessionId });
      this.logger.log(`Session ${sessionId} created in OpenWA`);
    } catch (error) {
      this.logger.error(`Failed to create session in OpenWA: ${sessionId}`, error);
      this.emitEvent(sessionId, userId, SessionStatus.ERROR, { error: 'Failed to create session' });
    }
    return openWAClient;
  }

  async initializeSession(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.emitEvent(sessionId, userId, SessionStatus.LOADING);
    try {
      const status = await this.request<{ state: string; qr?: string }>(openWAClient.client, 'GET', `/sessions/${sessionId}/status`);
      switch (status.state) {
        case 'CONNECTED':
        case 'READY':
          openWAClient.status = SessionStatus.CONNECTED;
          openWAClient.phone = status.state;
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED);
          break;
        case 'QRCODE':
          if (status.qr) {
            openWAClient.status = SessionStatus.QR_GENERATED;
            openWAClient.qrCode = status.qr;
            this.emitEvent(sessionId, userId, SessionStatus.QR_GENERATED, { qr: status.qr });
            this.startQrRefreshTimer(sessionId, userId);
          }
          break;
        default:
          this.emitEvent(sessionId, userId, SessionStatus.DISCONNECTED);
      }
    } catch (error) {
      this.logger.error(`Failed to initialize session: ${sessionId}`, error);
      this.emitEvent(sessionId, userId, SessionStatus.ERROR, { error: 'Failed to initialize session' });
    }
  }

  private startQrRefreshTimer(sessionId: string, userId: string): void {
    const existingTimer = this.qrTimers.get(sessionId);
    if (existingTimer) clearInterval(existingTimer);
    const timer = setInterval(async () => {
      const openWAClient = this.getClientBySessionId(sessionId);
      if (!openWAClient || openWAClient.status !== SessionStatus.QR_GENERATED) {
        clearInterval(timer);
        this.qrTimers.delete(sessionId);
        return;
      }
      try {
        const status = await this.request<{ state: string; qr?: string }>(openWAClient.client, 'GET', `/sessions/${sessionId}/status`);
        if (status.state === 'QRCODE' && status.qr) {
          openWAClient.qrCode = status.qr;
          this.emitEvent(sessionId, userId, SessionStatus.QR_UPDATED, { qr: status.qr });
        } else if (status.state === 'CONNECTED' || status.state === 'READY') {
          openWAClient.status = SessionStatus.CONNECTED;
          openWAClient.phone = status.state;
          clearInterval(timer);
          this.qrTimers.delete(sessionId);
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED);
          this.emitEvent(sessionId, userId, SessionStatus.READY);
        }
      } catch (error) {
        this.logger.error(`QR refresh error for ${sessionId}`, error);
      }
    }, this.qrRefreshInterval);
    this.qrTimers.set(sessionId, timer);
  }

  async getQRCode(sessionId: string, userId: string): Promise<string | null> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    try {
      const qrResponse = await this.request<{ qr: string }>(openWAClient.client, 'GET', `/sessions/${sessionId}/qr`);
      if (qrResponse.qr) {
        openWAClient.status = SessionStatus.QR_GENERATED;
        openWAClient.qrCode = qrResponse.qr;
        this.emitEvent(sessionId, userId, SessionStatus.QR_GENERATED, { qr: qrResponse.qr });
        this.startQrRefreshTimer(sessionId, userId);
        return qrResponse.qr;
      }
    } catch (error) {
      this.logger.error(`Failed to get QR code: ${sessionId}`, error);
      this.emitEvent(sessionId, userId, SessionStatus.ERROR, { error: 'Failed to get QR code' });
    }
    return null;
  }

  async getSessionStatus(sessionId: string, userId: string): Promise<{ state: string; qr?: string; phone?: string }> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    try {
      const status = await this.request<{ state: string; qr?: string }>(openWAClient.client, 'GET', `/sessions/${sessionId}/status`);
      return { state: status.state, qr: status.qr, phone: openWAClient.phone };
    } catch (error) {
      this.logger.error(`Failed to get session status: ${sessionId}`, error);
      return { state: 'ERROR' };
    }
  }

  async reconnect(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.logger.log(`Reconnecting session: ${sessionId}`);
    this.emitEvent(sessionId, userId, SessionStatus.RECONNECTING);
    try {
      await this.request<{ success: boolean }>(openWAClient.client, 'POST', `/sessions/${sessionId}/reconnect`);
      this.scheduleReconnectCheck(sessionId, userId);
    } catch (error) {
      this.logger.error(`Failed to reconnect session: ${sessionId}`, error);
      this.emitEvent(sessionId, userId, SessionStatus.ERROR, { error: 'Failed to reconnect' });
      this.scheduleReconnectRetry(sessionId, userId);
    }
  }

  private scheduleReconnectCheck(sessionId: string, userId: string): void {
    setTimeout(async () => {
      const openWAClient = this.getClientBySessionId(sessionId);
      if (!openWAClient) return;
      try {
        const status = await this.request<{ state: string }>(openWAClient.client, 'GET', `/sessions/${sessionId}/status`);
        if (status.state === 'CONNECTED' || status.state === 'READY') {
          openWAClient.status = SessionStatus.CONNECTED;
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED);
        } else if (status.state === 'DISCONNECTED') {
          this.emitEvent(sessionId, userId, SessionStatus.DISCONNECTED);
        }
      } catch (error) {
        this.logger.error(`Reconnect check failed: ${sessionId}`, error);
      }
    }, 5000);
  }

  private scheduleReconnectRetry(sessionId: string, userId: string): void {
    const existingTimer = this.reconnectTimers.get(sessionId);
    if (existingTimer) clearTimeout(existingTimer);
    const timer = setTimeout(() => { this.reconnect(sessionId, userId); }, 30000);
    this.reconnectTimers.set(sessionId, timer);
  }

  async logout(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.logger.log(`Logging out session: ${sessionId}`);
    try {
      await this.request<{ success: boolean }>(openWAClient.client, 'POST', `/sessions/${sessionId}/logout`);
      openWAClient.status = SessionStatus.DISCONNECTED;
      openWAClient.qrCode = undefined;
      openWAClient.phone = undefined;
      this.emitEvent(sessionId, userId, SessionStatus.DISCONNECTED);
    } catch (error) {
      this.logger.error(`Failed to logout session: ${sessionId}`, error);
    }
  }

  async destroySession(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.logger.log(`Destroying session: ${sessionId}`);
    const qrTimer = this.qrTimers.get(sessionId);
    if (qrTimer) { clearInterval(qrTimer); this.qrTimers.delete(sessionId); }
    const reconnectTimer = this.reconnectTimers.get(sessionId);
    if (reconnectTimer) { clearTimeout(reconnectTimer); this.reconnectTimers.delete(sessionId); }
    try {
      await this.request<{ success: boolean }>(openWAClient.client, 'DELETE', `/sessions/${sessionId}`);
    } catch (error) {
      this.logger.warn(`Failed to delete session from OpenWA: ${sessionId}`, error);
    }
    this.clients.delete(sessionId);
    const userSessionIds = this.userSessions.get(userId) || [];
    const index = userSessionIds.indexOf(sessionId);
    if (index !== -1) { userSessionIds.splice(index, 1); this.userSessions.set(userId, userSessionIds); }
    this.deleteSessionFiles(sessionId);
    this.emitEvent(sessionId, userId, SessionStatus.DESTROYED);
  }

  private deleteSessionFiles(sessionId: string): void {
    try {
      const sessionPath = path.join(this.sessionStoragePath, sessionId);
      if (fs.existsSync(sessionPath)) { fs.rmSync(sessionPath, { recursive: true }); this.logger.log(`Deleted session files: ${sessionPath}`); }
    } catch (error) {
      this.logger.error(`Failed to delete session files: ${sessionId}`, error);
    }
  }

  private async saveSessionState(sessionId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient) return;
    try {
      const statePath = path.join(this.sessionStoragePath, `${sessionId}.state.json`);
      const state = { sessionId: openWAClient.sessionId, userId: openWAClient.userId, status: openWAClient.status, phone: openWAClient.phone, deviceName: openWAClient.deviceName, messageCount: openWAClient.messageCount, lastActivity: openWAClient.lastActivity?.toISOString() };
      fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
    } catch (error) {
      this.logger.error(`Failed to save session state: ${sessionId}`, error);
    }
  }

  private async restoreExistingSessions(): Promise<void> {
    try {
      if (!fs.existsSync(this.sessionStoragePath)) return;
      const files = fs.readdirSync(this.sessionStoragePath);
      const stateFiles = files.filter((f) => f.endsWith('.state.json'));
      this.logger.log(`Found ${stateFiles.length} session states to restore`);
      for (const stateFile of stateFiles) {
        try {
          const statePath = path.join(this.sessionStoragePath, stateFile);
          const stateContent = fs.readFileSync(statePath, 'utf-8');
          const state = JSON.parse(stateContent);
          const client = this.createClient(state.sessionId);
          const openWAClient: OpenWAClient = { sessionId: state.sessionId, userId: state.userId, status: SessionStatus.DISCONNECTED, phone: state.phone, deviceName: state.deviceName, messageCount: state.messageCount || 0, lastActivity: state.lastActivity ? new Date(state.lastActivity) : undefined, client };
          this.clients.set(state.sessionId, openWAClient);
          const userSessionIds = this.userSessions.get(state.userId) || [];
          userSessionIds.push(state.sessionId);
          this.userSessions.set(state.userId, userSessionIds);
          this.logger.log(`Attempting to restore session: ${state.sessionId}`);
          this.emitEvent(state.sessionId, state.userId, SessionStatus.RECONNECTING);
          setTimeout(() => { this.reconnect(state.sessionId, state.userId); }, 5000);
        } catch (error) {
          this.logger.error(`Failed to restore session from ${stateFile}`, error);
        }
      }
    } catch (error) {
      this.logger.error('Failed to restore existing sessions', error);
    }
  }

  async sendTextMessage(sessionId: string, userId: string, to: string, text: string): Promise<Record<string, unknown>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) throw new Error('Session not found or access denied');
    if (openWAClient.status !== SessionStatus.CONNECTED && openWAClient.status !== SessionStatus.READY) throw new Error('Session not connected');
    try {
      const result = await this.request<Record<string, unknown>>(openWAClient.client, 'POST', `/sessions/${sessionId}/send-text`, { to, text });
      openWAClient.messageCount++;
      openWAClient.lastActivity = new Date();
      this.emitEvent(sessionId, userId, SessionStatus.READY, { type: 'outgoing_message', to, messageId: (result as any).key?.id });
      return result;
    } catch (error) {
      this.logger.error(`Failed to send message: ${sessionId}`, error);
      throw error;
    }
  }

  async sendMediaMessage(sessionId: string, userId: string, to: string, mediaUrl: string, caption?: string, mimetype?: string): Promise<Record<string, unknown>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) throw new Error('Session not found or access denied');
    if (openWAClient.status !== SessionStatus.CONNECTED && openWAClient.status !== SessionStatus.READY) throw new Error('Session not connected');
    try {
      const result = await this.request<Record<string, unknown>>(openWAClient.client, 'POST', `/sessions/${sessionId}/send-media`, { to, mediaUrl, caption, mimetype });
      openWAClient.messageCount++;
      openWAClient.lastActivity = new Date();
      this.emitEvent(sessionId, userId, SessionStatus.READY, { type: 'outgoing_message', to, media: true });
      return result;
    } catch (error) {
      this.logger.error(`Failed to send media: ${sessionId}`, error);
      throw error;
    }
  }

  getClientBySessionId(sessionId: string): OpenWAClient | undefined { return this.clients.get(sessionId); }
  getClientByUserId(userId: string): OpenWAClient | undefined {
    const sessionIds = this.userSessions.get(userId) || [];
    if (sessionIds.length === 0) return undefined;
    return this.clients.get(sessionIds[0]);
  }
  getUserSessions(userId: string): OpenWAClient[] {
    const sessionIds = this.userSessions.get(userId) || [];
    return sessionIds.map((id) => this.clients.get(id)).filter(Boolean) as OpenWAClient[];
  }
  getAllSessions(): OpenWAClient[] { return Array.from(this.clients.values()); }
  getActiveSessionsCount(): number {
    return Array.from(this.clients.values()).filter((c) => c.status === SessionStatus.CONNECTED || c.status === SessionStatus.READY).length;
  }
  getTotalSessionsCount(): number { return this.clients.size; }

  async syncContacts(sessionId: string, userId: string): Promise<{ synced: number }> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) throw new Error('Session not found or access denied');
    this.logger.log(`Syncing contacts for session: ${sessionId}`);
    this.emitEvent(sessionId, userId, SessionStatus.READY, { type: 'contact_sync_progress', progress: 0 });
    try {
      const response = await this.request<{ contacts: Array<Record<string, unknown>> }>(openWAClient.client, 'GET', `/sessions/${sessionId}/contacts`);
      this.emitEvent(sessionId, userId, SessionStatus.READY, { type: 'contact_sync_complete', count: response.contacts?.length || 0 });
      return { synced: response.contacts?.length || 0 };
    } catch (error) {
      this.logger.error(`Failed to sync contacts: ${sessionId}`, error);
      throw error;
    }
  }

  async getChats(sessionId: string, userId: string): Promise<Array<Record<string, unknown>>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) throw new Error('Session not found or access denied');
    try {
      const response = await this.request<{ chats: Array<Record<string, unknown>> }>(openWAClient.client, 'GET', `/sessions/${sessionId}/chats`);
      return response.chats || [];
    } catch (error) {
      this.logger.error(`Failed to get chats: ${sessionId}`, error);
      throw error;
    }
  }

  async getContacts(sessionId: string, userId: string): Promise<Array<Record<string, unknown>>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) throw new Error('Session not found or access denied');
    try {
      const response = await this.request<{ contacts: Array<Record<string, unknown>> }>(openWAClient.client, 'GET', `/sessions/${sessionId}/contacts`);
      return response.contacts || [];
    } catch (error) {
      this.logger.error(`Failed to get contacts: ${sessionId}`, error);
      throw error;
    }
  }
}
