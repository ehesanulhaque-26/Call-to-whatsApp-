import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import axios, { AxiosInstance, AxiosError } from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { SessionStatus, normalizeOpenWAStatus, SessionEvent as UnifiedSessionEvent } from '../../common/types/session.types';
import { SupabaseService } from '../supabase/supabase.service';

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
  private statusPollingIntervals: Map<string, NodeJS.Timeout> = new Map();

  constructor(
    private readonly configService: ConfigService,
    private readonly eventEmitter: EventEmitter2,
    private readonly supabaseService: SupabaseService,
  ) {
    // Get OpenWA URL from config or environment
    // Use public Railway URL as fallback (same as OpenWAService)
    this.baseURL =
      this.configService.get<string>('OPENWA_URL') ||
      process.env.OPENWA_URL ||
      'https://openwa-production-d8f8.up.railway.app';
    this.sessionStoragePath = this.configService.get<string>('OPENWA_SESSION_PATH') || './sessions';

    this.logger.log(`[SessionManager] Initialized with OpenWA base URL: ${this.baseURL}`);
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
    this.stopAllStatusPolling();
    for (const [sessionId] of this.clients.entries()) {
      await this.saveSessionState(sessionId);
    }
    this.clients.clear();
    this.userSessions.clear();
    this.logger.log('Session Manager shutdown complete');
  }
  
  private stopAllStatusPolling(): void {
    for (const timer of this.statusPollingIntervals.values()) {
      clearInterval(timer);
    }
    this.statusPollingIntervals.clear();
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
      if (client.status === SessionStatus.DISCONNECTED || client.status === SessionStatus.FAILED) {
        const lastActivity = client.lastActivity?.getTime() || 0;
        if (now - lastActivity > staleThreshold) {
          this.logger.log(`Cleaning up stale session: ${sessionId}`);
          this.destroySession(sessionId, client.userId).catch(err => {
            this.logger.error(`Failed to cleanup stale session: ${err}`);
          });
        }
      }
    }
  }

  private createClient(): AxiosInstance {
    return axios.create({
      baseURL: this.baseURL,
      timeout: 60000, // 60 second timeout for WhatsApp operations
      headers: { 'Content-Type': 'application/json' },
    });
  }

  private emitEvent(
    sessionId: string,
    userId: string,
    event: SessionStatus,
    data?: Record<string, unknown>,
  ): void {
    const sessionEvent: UnifiedSessionEvent = { 
      sessionId, 
      userId, 
      status: event, 
      phone: data?.['phone'] as string | undefined,
      qrCode: data?.['qr'] as string | undefined,
      error: data?.['error'] as string | undefined,
      timestamp: new Date() 
    };
    this.eventEmitter.emit('session.event', sessionEvent);
    this.logger.debug(`Session event: ${sessionId} -> ${event}`);
  }

  private async request<T>(
    client: AxiosInstance,
    method: string,
    reqPath: string,
    data?: unknown,
  ): Promise<T> {
    const fullUrl = `${this.baseURL}${reqPath}`;
    this.logger.debug(
      `[OpenWA] ${method} ${fullUrl} - Request: ${data ? JSON.stringify(data) : 'none'}`,
    );

    try {
      const startTime = Date.now();
      const response = await client.request<T>({ method, url: reqPath, data });
      const duration = Date.now() - startTime;

      this.logger.log(
        `[OpenWA] ${method} ${reqPath} - Status: ${response.status} - Duration: ${duration}ms`,
      );
      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError;

      if (axiosError.code === 'ECONNREFUSED') {
        this.logger.error(`[OpenWA] ${method} ${reqPath} - Connection refused to ${this.baseURL}`);
      } else if (axiosError.code === 'ETIMEDOUT' || axiosError.code === 'ECONNABORTED') {
        this.logger.error(`[OpenWA] ${method} ${reqPath} - Timeout`);
      } else if (axiosError.response) {
        this.logger.error(
          `[OpenWA] ${method} ${reqPath} - HTTP ${axiosError.response.status}: ${JSON.stringify(axiosError.response.data)}`,
        );
      } else {
        this.logger.error(`[OpenWA] ${method} ${reqPath} - Error: ${axiosError.message}`);
      }

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
    this.logger.log(`[SessionManager] Creating session: ${sessionId} for user: ${userId}`);
    const client = this.createClient();
    const openWAClient: OpenWAClient = {
      sessionId,
      userId,
      status: SessionStatus.CREATING,
      messageCount: 0,
      client,
    };
    this.clients.set(sessionId, openWAClient);
    const userSessionIds = this.userSessions.get(userId) || [];
    userSessionIds.push(sessionId);
    this.userSessions.set(userId, userSessionIds);
    
    // Emit event
    this.emitEvent(sessionId, userId, SessionStatus.CREATING);
    
    // Persist to Supabase
    await this.persistSessionToDb(sessionId, userId);
    
    return openWAClient;
  }

  async initializeSession(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    
    openWAClient.status = SessionStatus.INITIALIZING;
    this.emitEvent(sessionId, userId, SessionStatus.INITIALIZING);
    
    try {
      const status = await this.request<{ state: string; qr?: string }>(
        openWAClient.client,
        'GET',
        `/api/sessions/${sessionId}/status`,
      );
      
      const normalizedStatus = normalizeOpenWAStatus(status.state);
      
      switch (normalizedStatus) {
        case SessionStatus.CONNECTED:
          openWAClient.status = SessionStatus.CONNECTED;
          openWAClient.phone = status.state;
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED);
          await this.persistSessionToDb(sessionId, userId);
          break;
        case SessionStatus.QR_READY:
          if (status.qr) {
            openWAClient.status = SessionStatus.QR_READY;
            openWAClient.qrCode = status.qr;
            this.emitEvent(sessionId, userId, SessionStatus.QR_READY, { qr: status.qr });
            await this.persistSessionToDb(sessionId, userId);
            this.startQrRefreshTimer(sessionId, userId);
          }
          break;
        default:
          this.emitEvent(sessionId, userId, SessionStatus.DISCONNECTED);
          await this.persistSessionToDb(sessionId, userId);
      }
    } catch (error) {
      this.logger.error(`Failed to initialize session: ${sessionId}`, error);
      openWAClient.status = SessionStatus.FAILED;
      this.emitEvent(sessionId, userId, SessionStatus.FAILED, {
        error: 'Failed to initialize session',
      });
      await this.persistSessionToDb(sessionId, userId);
    }
  }

  private startQrRefreshTimer(sessionId: string, userId: string): void {
    const existingTimer = this.qrTimers.get(sessionId);
    if (existingTimer) clearInterval(existingTimer);
    const timer = setInterval(async () => {
      const openWAClient = this.getClientBySessionId(sessionId);
      if (!openWAClient || openWAClient.status !== SessionStatus.QR_READY) {
        clearInterval(timer);
        this.qrTimers.delete(sessionId);
        return;
      }
      try {
        // Use correct API path with /api prefix
        const status = await this.request<{ state: string; qr?: string; phone?: string }>(
          openWAClient.client,
          'GET',
          `/api/sessions/${sessionId}/status`,
        );
        
        this.logger.log(`[SessionManager] QR REFRESH - Session ${sessionId} status: ${status.state}, phone: ${status.phone || 'none'}`);
        
        const normalizedStatus = normalizeOpenWAStatus(status.state);
        
        if (normalizedStatus === SessionStatus.QR_READY && status.qr) {
          openWAClient.qrCode = status.qr;
          this.emitEvent(sessionId, userId, SessionStatus.QR_READY, { qr: status.qr });
          await this.persistSessionToDb(sessionId, userId);
        } else if (normalizedStatus === SessionStatus.CONNECTED || normalizedStatus === SessionStatus.READY) {
          openWAClient.status = SessionStatus.CONNECTED;
          // Capture the phone number from the status response
          openWAClient.phone = status.phone || openWAClient.phone;
          clearInterval(timer);
          this.qrTimers.delete(sessionId);
          this.stopStatusPolling(sessionId);
          this.logger.log(`[SessionManager] QR REFRESH - Session ${sessionId} CONNECTED with phone: ${openWAClient.phone}`);
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED, { phone: openWAClient.phone });
          await this.persistSessionToDb(sessionId, userId);
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
      const qrResponse = await this.request<{ qr?: string; qrCode?: string }>(
        openWAClient.client,
        'GET',
        `/api/sessions/${sessionId}/qr`,
      );
      const qrCode = qrResponse.qr || qrResponse.qrCode;
      if (qrCode) {
        openWAClient.status = SessionStatus.QR_READY;
        openWAClient.qrCode = qrCode;
        this.emitEvent(sessionId, userId, SessionStatus.QR_READY, { qr: qrCode });
        await this.persistSessionToDb(sessionId, userId);
        this.startQrRefreshTimer(sessionId, userId);
        this.startStatusPolling(sessionId, userId);
        return qrCode;
      }
    } catch (error) {
      this.logger.error(`Failed to get QR code: ${sessionId}`, error);
      this.emitEvent(sessionId, userId, SessionStatus.FAILED, { error: 'Failed to get QR code' });
    }
    return null;
  }

  /**
   * Start a session - calls POST /api/sessions/{id}/start
   * This triggers the OpenWA server to initialize the session and generate a QR code
   */
  async startSession(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }

    this.logger.log(`[SessionManager] START SESSION - Starting session ${sessionId}`);
    openWAClient.status = SessionStatus.INITIALIZING;
    this.emitEvent(sessionId, userId, SessionStatus.INITIALIZING);

    try {
      const fullUrl = `${this.baseURL}/api/sessions/${sessionId}/start`;
      this.logger.warn(`[SessionManager] START SESSION - Sending POST to: ${fullUrl}`);

      const response = await openWAClient.client.request({
        method: 'POST',
        url: `/api/sessions/${sessionId}/start`,
      });

      this.logger.warn(`[SessionManager] START SESSION - Response status: ${response.status}`);
      this.logger.warn(
        `[SessionManager] START SESSION - Response data: ${JSON.stringify(response.data)}`,
      );

      if (response.status === 200 || response.status === 201) {
        this.logger.log(`[SessionManager] START SESSION - Session started successfully`);
        openWAClient.status = SessionStatus.QR_READY;
        this.emitEvent(sessionId, userId, SessionStatus.QR_READY);
        await this.persistSessionToDb(sessionId, userId);
      }
    } catch (error) {
      const axiosError = error as AxiosError;
      this.logger.error(`[SessionManager] START SESSION - Failed: ${axiosError.message}`);
      this.logger.error(`[SessionManager] START SESSION - Status: ${axiosError.response?.status}`);
      this.logger.error(
        `[SessionManager] START SESSION - Response: ${JSON.stringify(axiosError.response?.data)}`,
      );
      openWAClient.status = SessionStatus.FAILED;
      this.emitEvent(sessionId, userId, SessionStatus.FAILED, { error: 'Failed to start session' });
      await this.persistSessionToDb(sessionId, userId);
      throw new Error(`Failed to start session: ${axiosError.message}`);
    }
  }

  /**
   * Poll for QR code until it's ready or timeout
   * This checks the session status and retrieves the QR code when available
   */
  async pollForQRCode(
    sessionId: string,
    userId: string,
    maxAttempts = 30,
    intervalMs = 2000,
  ): Promise<string | null> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }

    this.logger.log(
      `[SessionManager] POLL QR - Starting poll for session ${sessionId}, maxAttempts: ${maxAttempts}`,
    );

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const fullUrl = `${this.baseURL}/api/sessions/${sessionId}/qr`;
        this.logger.warn(
          `[SessionManager] POLL QR - Attempt ${attempt}/${maxAttempts}: GET ${fullUrl}`,
        );

        const qrResponse = await openWAClient.client.request<{ qr?: string; qrCode?: string }>({
          method: 'GET',
          url: `/api/sessions/${sessionId}/qr`,
        });

        this.logger.warn(
          `[SessionManager] POLL QR - Attempt ${attempt}: Response status: ${qrResponse.status}`,
        );
        this.logger.warn(
          `[SessionManager] POLL QR - Attempt ${attempt}: Response data: ${JSON.stringify(qrResponse.data)}`,
        );

        const qrCode = qrResponse.data?.qr || qrResponse.data?.qrCode;
        if (qrCode) {
          openWAClient.status = SessionStatus.QR_READY;
          openWAClient.qrCode = qrCode;
          this.emitEvent(sessionId, userId, SessionStatus.QR_READY, { qr: qrCode });
          await this.persistSessionToDb(sessionId, userId);
          this.startQrRefreshTimer(sessionId, userId);
          this.startStatusPolling(sessionId, userId);
          this.logger.log(`[SessionManager] POLL QR - QR code received on attempt ${attempt}`);
          return qrCode;
        }

        // Check if session is already connected
        const statusResponse = await openWAClient.client.request<{ state?: string }>({
          method: 'GET',
          url: `/api/sessions/${sessionId}/status`,
        });

        const state = statusResponse.data?.state;
        this.logger.warn(`[SessionManager] POLL QR - Attempt ${attempt}: Session state: ${state}`);

        if (state === 'CONNECTED' || state === 'READY') {
          this.logger.log(
            `[SessionManager] POLL QR - Session already connected on attempt ${attempt}`,
          );
          openWAClient.status = SessionStatus.CONNECTED;
          await this.persistSessionToDb(sessionId, userId);
          return null;
        }
      } catch (error) {
        const axiosError = error as AxiosError;
        this.logger.warn(
          `[SessionManager] POLL QR - Attempt ${attempt}: Error: ${axiosError.message}`,
        );
        this.logger.warn(
          `[SessionManager] POLL QR - Attempt ${attempt}: Status: ${axiosError.response?.status}`,
        );
      }

      // Wait before next attempt
      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, intervalMs));
      }
    }

    this.logger.warn(`[SessionManager] POLL QR - Timed out after ${maxAttempts} attempts`);
    return null;
  }

  async getSessionStatus(
    sessionId: string,
    userId: string,
  ): Promise<{ state: string; qr?: string; phone?: string }> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    try {
      const status = await this.request<{ state: string; qr?: string }>(
        openWAClient.client,
        'GET',
        `/api/sessions/${sessionId}/status`,
      );
      return { state: status.state, qr: status.qr, phone: openWAClient.phone };
    } catch (error) {
      this.logger.error(`Failed to get session status: ${sessionId}`, error);
      return { state: 'ERROR' };
    }
  }

  async updateSessionName(sessionId: string, userId: string, name: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }

    this.logger.log(`Updating session name: ${sessionId} to "${name}"`);

    // Update in database
    try {
      await this.supabaseService.update('sessions', sessionId, {
        name: name,
        updated_at: new Date().toISOString(),
      });
      this.logger.log(`Session name updated in database: ${sessionId}`);
    } catch (error) {
      this.logger.error(`Failed to update session name in database: ${sessionId}`, error);
      throw new Error('Failed to update session name');
    }
  }

  async reconnect(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.logger.log(`Reconnecting session: ${sessionId}`);
    openWAClient.status = SessionStatus.CONNECTING;
    this.emitEvent(sessionId, userId, SessionStatus.CONNECTING);
    await this.persistSessionToDb(sessionId, userId);
    
    try {
      await this.request<{ success: boolean }>(
        openWAClient.client,
        'POST',
        `/api/sessions/${sessionId}/start`,
      );
      this.scheduleReconnectCheck(sessionId, userId);
    } catch (error) {
      this.logger.error(`Failed to reconnect session: ${sessionId}`, error);
      openWAClient.status = SessionStatus.FAILED;
      this.emitEvent(sessionId, userId, SessionStatus.FAILED, { error: 'Failed to reconnect' });
      await this.persistSessionToDb(sessionId, userId);
      this.scheduleReconnectRetry(sessionId, userId);
    }
  }

  private scheduleReconnectCheck(sessionId: string, userId: string): void {
    setTimeout(async () => {
      const openWAClient = this.getClientBySessionId(sessionId);
      if (!openWAClient) return;
      try {
        const status = await this.request<{ state: string }>(
          openWAClient.client,
          'GET',
          `/api/sessions/${sessionId}/status`,
        );
        const normalizedStatus = normalizeOpenWAStatus(status.state);
        if (normalizedStatus === SessionStatus.CONNECTED) {
          openWAClient.status = SessionStatus.CONNECTED;
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED);
          await this.persistSessionToDb(sessionId, userId);
        } else if (normalizedStatus === SessionStatus.DISCONNECTED) {
          openWAClient.status = SessionStatus.DISCONNECTED;
          this.emitEvent(sessionId, userId, SessionStatus.DISCONNECTED);
          await this.persistSessionToDb(sessionId, userId);
        }
      } catch (error) {
        this.logger.error(`Reconnect check failed: ${sessionId}`, error);
      }
    }, 5000);
  }

  private scheduleReconnectRetry(sessionId: string, userId: string): void {
    const existingTimer = this.reconnectTimers.get(sessionId);
    if (existingTimer) clearTimeout(existingTimer);
    const timer = setTimeout(() => {
      this.reconnect(sessionId, userId);
    }, 30000);
    this.reconnectTimers.set(sessionId, timer);
  }

  async logout(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.logger.log(`Logging out session: ${sessionId}`);
    
    // Stop any pending timers
    this.stopQrRefreshTimer(sessionId);
    this.stopStatusPolling(sessionId);
    
    try {
      await this.request<{ success: boolean }>(
        openWAClient.client,
        'POST',
        `/api/sessions/${sessionId}/logout`,
      );
    } catch (error) {
      this.logger.warn(`Logout API call failed for session: ${sessionId}`, error);
    }
    
    openWAClient.status = SessionStatus.LOGGED_OUT;
    openWAClient.qrCode = undefined;
    openWAClient.phone = undefined;
    this.emitEvent(sessionId, userId, SessionStatus.LOGGED_OUT);
    await this.persistSessionToDb(sessionId, userId);
  }

  async destroySession(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId) {
      throw new Error('Session not found or access denied');
    }
    this.logger.log(`Destroying session: ${sessionId}`);
    
    // Stop all timers
    this.stopQrRefreshTimer(sessionId);
    this.stopStatusPolling(sessionId);
    
    try {
      await this.request<{ success: boolean }>(
        openWAClient.client,
        'DELETE',
        `/api/sessions/${sessionId}`,
      );
    } catch (error) {
      this.logger.warn(`Failed to delete session from OpenWA: ${sessionId}`, error);
    }
    
    // Remove from memory
    this.clients.delete(sessionId);
    const userSessionIds = this.userSessions.get(userId) || [];
    const index = userSessionIds.indexOf(sessionId);
    if (index !== -1) {
      userSessionIds.splice(index, 1);
      this.userSessions.set(userId, userSessionIds);
    }
    
    this.deleteSessionFiles(sessionId);
    
    // Delete from Supabase
    await this.deleteSessionFromDb(sessionId);
    
    this.emitEvent(sessionId, userId, SessionStatus.DELETED);
  }
  
  private stopQrRefreshTimer(sessionId: string): void {
    const qrTimer = this.qrTimers.get(sessionId);
    if (qrTimer) {
      clearInterval(qrTimer);
      this.qrTimers.delete(sessionId);
    }
  }
  
  private stopStatusPolling(sessionId: string): void {
    const pollingTimer = this.statusPollingIntervals.get(sessionId);
    if (pollingTimer) {
      clearInterval(pollingTimer);
      this.statusPollingIntervals.delete(sessionId);
    }
  }

  private deleteSessionFiles(sessionId: string): void {
    try {
      const sessionPath = path.join(this.sessionStoragePath, sessionId);
      if (fs.existsSync(sessionPath)) {
        fs.rmSync(sessionPath, { recursive: true });
        this.logger.log(`Deleted session files: ${sessionPath}`);
      }
    } catch (error) {
      this.logger.error(`Failed to delete session files: ${sessionId}`, error);
    }
  }

  private async saveSessionState(sessionId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient) return;
    try {
      const statePath = path.join(this.sessionStoragePath, `${sessionId}.state.json`);
      const state = {
        sessionId: openWAClient.sessionId,
        userId: openWAClient.userId,
        status: openWAClient.status,
        phone: openWAClient.phone,
        deviceName: openWAClient.deviceName,
        messageCount: openWAClient.messageCount,
        lastActivity: openWAClient.lastActivity?.toISOString(),
      };
      fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
    } catch (error) {
      this.logger.error(`Failed to save session state: ${sessionId}`, error);
    }
  }

  /**
   * Persist session state to Supabase database
   */
  private async persistSessionToDb(sessionId: string, userId: string): Promise<void> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient) return;
    
    try {
      // Map our status to the database status format
      const dbStatus = this.mapStatusToDb(openWAClient.status);
      
      const sessionData = {
        user_id: userId,
        name: sessionId,
        status: dbStatus,
        phone: openWAClient.phone || null,
        device_name: openWAClient.deviceName || null,
        qr_code: openWAClient.qrCode || null,
        is_active: openWAClient.status === SessionStatus.CONNECTED,
        updated_at: new Date().toISOString(),
      };
      
      // Check if session exists in DB
      const { data: existing } = await this.supabaseService.query('sessions', {
        select: 'id',
        eq: { id: sessionId },
      });
      
      if (existing && existing.length > 0) {
        // Update existing session
        await this.supabaseService.update('sessions', sessionId, sessionData);
        this.logger.log(`[SessionManager] Updated session in DB: ${sessionId}`);
      } else {
        // Insert new session
        const insertData = {
          id: sessionId,
          ...sessionData,
          message_count: openWAClient.messageCount,
          created_at: new Date().toISOString(),
        };
        await this.supabaseService.insert('sessions', insertData);
        this.logger.log(`[SessionManager] Created session in DB: ${sessionId}`);
      }
    } catch (error) {
      this.logger.error(`[SessionManager] Failed to persist session to DB: ${sessionId}`, error);
    }
  }
  
  /**
   * Delete session from Supabase database
   */
  private async deleteSessionFromDb(sessionId: string): Promise<void> {
    try {
      await this.supabaseService.delete('sessions', sessionId);
      this.logger.log(`[SessionManager] Deleted session from DB: ${sessionId}`);
    } catch (error) {
      this.logger.error(`[SessionManager] Failed to delete session from DB: ${sessionId}`, error);
    }
  }
  
  /**
   * Map our unified SessionStatus to database session_status enum
   * Database values: 'pending', 'connected', 'disconnected', 'error'
   */
  private mapStatusToDb(status: SessionStatus): string {
    switch (status) {
      case SessionStatus.CREATING:
      case SessionStatus.INITIALIZING:
        return 'pending';
      case SessionStatus.QR_READY:
      case SessionStatus.PAIRING_READY:
      case SessionStatus.CONNECTING:
      case SessionStatus.CONNECTED:
      case SessionStatus.READY:
        return 'connected';
      case SessionStatus.DISCONNECTED:
      case SessionStatus.LOGGED_OUT:
        return 'disconnected';
      case SessionStatus.FAILED:
      case SessionStatus.DELETED:
      default:
        return 'error';
    }
  }

  /**
   * Start polling for status changes - this detects when the session becomes connected
   */
  private startStatusPolling(sessionId: string, userId: string): void {
    const existingTimer = this.statusPollingIntervals.get(sessionId);
    if (existingTimer) clearInterval(existingTimer);
    
    const timer = setInterval(async () => {
      const openWAClient = this.getClientBySessionId(sessionId);
      if (!openWAClient) {
        clearInterval(timer);
        this.statusPollingIntervals.delete(sessionId);
        return;
      }
      
      // Only poll if session is not already connected
      if (openWAClient.status === SessionStatus.CONNECTED || 
          openWAClient.status === SessionStatus.READY) {
        clearInterval(timer);
        this.statusPollingIntervals.delete(sessionId);
        return;
      }
      
      try {
        const status = await this.request<{ state: string; phone?: string }>(
          openWAClient.client,
          'GET',
          `/api/sessions/${sessionId}/status`,
        );
        
        const normalizedStatus = normalizeOpenWAStatus(status.state);
        
        if (normalizedStatus === SessionStatus.CONNECTED || normalizedStatus === SessionStatus.READY) {
          openWAClient.status = SessionStatus.CONNECTED;
          if (status.phone) {
            openWAClient.phone = status.phone;
          }
          this.logger.log(`[SessionManager] STATUS POLL - Session ${sessionId} CONNECTED with phone: ${openWAClient.phone}`);
          this.emitEvent(sessionId, userId, SessionStatus.CONNECTED, { phone: openWAClient.phone });
          await this.persistSessionToDb(sessionId, userId);
          
          // Stop polling
          clearInterval(timer);
          this.statusPollingIntervals.delete(sessionId);
          
          // Also stop QR refresh timer
          this.stopQrRefreshTimer(sessionId);
        }
      } catch (error) {
        this.logger.warn(`[SessionManager] STATUS POLL - Error for ${sessionId}: ${error}`);
      }
    }, 3000); // Poll every 3 seconds
    
    this.statusPollingIntervals.set(sessionId, timer);
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
          const client = this.createClient();
          const openWAClient: OpenWAClient = {
            sessionId: state.sessionId,
            userId: state.userId,
            status: SessionStatus.DISCONNECTED,
            phone: state.phone,
            deviceName: state.deviceName,
            messageCount: state.messageCount || 0,
            lastActivity: state.lastActivity ? new Date(state.lastActivity) : undefined,
            client,
          };
          this.clients.set(state.sessionId, openWAClient);
          const userSessionIds = this.userSessions.get(state.userId) || [];
          userSessionIds.push(state.sessionId);
          this.userSessions.set(state.userId, userSessionIds);
          this.logger.log(`Attempting to restore session: ${state.sessionId}`);
          this.emitEvent(state.sessionId, state.userId, SessionStatus.RECONNECTING);
          setTimeout(() => {
            this.reconnect(state.sessionId, state.userId);
          }, 5000);
        } catch (error) {
          this.logger.error(`Failed to restore session from ${stateFile}`, error);
        }
      }
    } catch (error) {
      this.logger.error('Failed to restore existing sessions', error);
    }
  }

  /**
   * Load sessions from Supabase database for a specific user
   * Called when user logs in to restore their sessions
   */
  async loadSessionsFromDb(userId: string): Promise<OpenWAClient[]> {
    this.logger.log(`[SessionManager] Loading sessions from DB for user: ${userId}`);
    
    try {
      const { data: sessions, error } = await this.supabaseService.query<Record<string, unknown>>('sessions', {
        select: '*',
        eq: { user_id: userId },
        order: [{ column: 'created_at', ascending: false }],
      });

      if (error || !sessions) {
        this.logger.error(`[SessionManager] Failed to load sessions from DB: ${error?.message}`);
        return [];
      }

      const loadedClients: OpenWAClient[] = [];
      
      for (const dbSession of sessions) {
        try {
          const client = this.createClient();
          const sessionId = (dbSession.id as string) || (dbSession.name as string);
          const openWAClient: OpenWAClient = {
            sessionId: sessionId,
            userId: dbSession.user_id as string,
            status: this.mapDbStatusToSession(dbSession.status as string),
            phone: dbSession.phone as string | undefined,
            deviceName: dbSession.device_name as string | undefined,
            messageCount: (dbSession.message_count as number) || 0,
            lastActivity: dbSession.last_message_at ? new Date(dbSession.last_message_at as string) : undefined,
            client,
          };
          
          this.clients.set(openWAClient.sessionId, openWAClient);
          
          const userSessionIds = this.userSessions.get(userId) || [];
          if (!userSessionIds.includes(openWAClient.sessionId)) {
            userSessionIds.push(openWAClient.sessionId);
            this.userSessions.set(userId, userSessionIds);
          }
          
          loadedClients.push(openWAClient);
          this.logger.log(`[SessionManager] Loaded session from DB: ${openWAClient.sessionId}`);
        } catch (error) {
          this.logger.error(`[SessionManager] Failed to load session ${dbSession.id}`, error);
        }
      }

      this.logger.log(`[SessionManager] Loaded ${loadedClients.length} sessions from DB for user ${userId}`);
      return loadedClients;
    } catch (error) {
      this.logger.error(`[SessionManager] Error loading sessions from DB:`, error);
      return [];
    }
  }

  /**
   * Map database status to SessionStatus enum
   */
  private mapDbStatusToSession(dbStatus: string): SessionStatus {
    switch (dbStatus) {
      case 'connected':
        return SessionStatus.CONNECTED;
      case 'pending':
        return SessionStatus.CREATING;
      case 'error':
        return SessionStatus.FAILED;
      case 'disconnected':
      default:
        return SessionStatus.DISCONNECTED;
    }
  }

  /**
   * Persist contacts to Supabase database
   * Performs incremental sync - inserts new contacts, updates existing ones
   */
  async persistContacts(
    sessionId: string,
    userId: string,
    contacts: Array<Record<string, unknown>>,
  ): Promise<{ synced: number }> {
    this.logger.log(`[SessionManager] Persisting ${contacts.length} contacts for session ${sessionId}`);
    
    try {
      let syncedCount = 0;
      
      for (const contact of contacts) {
        try {
          const phone = (contact.phone || contact.id || '') as string;
          if (!phone) continue;
          
          // Check if contact exists
          const { data: existing } = await this.supabaseService.query<{ id: string }>('contacts', {
            select: 'id',
            eq: { user_id: userId, phone: phone },
          });

          if (existing && existing.length > 0) {
            // Update existing contact
            await this.supabaseService.update('contacts', existing[0].id, {
              name: (contact.name as string) || null,
              push_name: (contact.pushName as string) || (contact.push_name as string) || null,
              profile_picture_url: (contact.profilePictureUrl as string) || (contact.profile_picture_url as string) || null,
              is_business: (contact.isBusiness as boolean) || (contact.is_business as boolean) || false,
              updated_at: new Date().toISOString(),
            });
          } else {
            // Insert new contact
            await this.supabaseService.insert('contacts', {
              user_id: userId,
              session_id: sessionId,
              phone: phone,
              name: (contact.name as string) || null,
              push_name: (contact.pushName as string) || (contact.push_name as string) || null,
              profile_picture_url: (contact.profilePictureUrl as string) || (contact.profile_picture_url as string) || null,
              is_business: (contact.isBusiness as boolean) || (contact.is_business as boolean) || false,
            });
          }
          syncedCount++;
        } catch (contactError) {
          this.logger.warn(`[SessionManager] Failed to persist contact: ${contactError}`);
        }
      }

      this.logger.log(`[SessionManager] Persisted ${syncedCount} contacts for session ${sessionId}`);
      return { synced: syncedCount };
    } catch (error) {
      this.logger.error(`[SessionManager] Failed to persist contacts:`, error);
      return { synced: 0 };
    }
  }

  async sendTextMessage(
    sessionId: string,
    userId: string,
    to: string,
    text: string,
  ): Promise<Record<string, unknown>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId)
      throw new Error('Session not found or access denied');
    if (
      openWAClient.status !== SessionStatus.CONNECTED &&
      openWAClient.status !== SessionStatus.READY
    )
      throw new Error('Session not connected');
    try {
      const result = await this.request<Record<string, unknown>>(
        openWAClient.client,
        'POST',
        `/api/sessions/${sessionId}/send-text`,
        { to, text },
      );
      openWAClient.messageCount++;
      openWAClient.lastActivity = new Date();
      this.emitEvent(sessionId, userId, SessionStatus.READY, {
        type: 'outgoing_message',
        to,
        messageId: (result as any).key?.id,
      });
      return result;
    } catch (error) {
      this.logger.error(`Failed to send message: ${sessionId}`, error);
      throw error;
    }
  }

  async sendMediaMessage(
    sessionId: string,
    userId: string,
    to: string,
    mediaUrl: string,
    caption?: string,
    mimetype?: string,
  ): Promise<Record<string, unknown>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId)
      throw new Error('Session not found or access denied');
    if (
      openWAClient.status !== SessionStatus.CONNECTED &&
      openWAClient.status !== SessionStatus.READY
    )
      throw new Error('Session not connected');
    try {
      const result = await this.request<Record<string, unknown>>(
        openWAClient.client,
        'POST',
        `/api/sessions/${sessionId}/send-media`,
        { to, mediaUrl, caption, mimetype },
      );
      openWAClient.messageCount++;
      openWAClient.lastActivity = new Date();
      this.emitEvent(sessionId, userId, SessionStatus.READY, {
        type: 'outgoing_message',
        to,
        media: true,
      });
      return result;
    } catch (error) {
      this.logger.error(`Failed to send media: ${sessionId}`, error);
      throw error;
    }
  }

  getClientBySessionId(sessionId: string): OpenWAClient | undefined {
    return this.clients.get(sessionId);
  }
  getClientByUserId(userId: string): OpenWAClient | undefined {
    const sessionIds = this.userSessions.get(userId) || [];
    if (sessionIds.length === 0) return undefined;
    return this.clients.get(sessionIds[0]);
  }
  getUserSessions(userId: string): OpenWAClient[] {
    const sessionIds = this.userSessions.get(userId) || [];
    return sessionIds.map((id) => this.clients.get(id)).filter(Boolean) as OpenWAClient[];
  }
  getAllSessions(): OpenWAClient[] {
    return Array.from(this.clients.values());
  }
  getActiveSessionsCount(): number {
    return Array.from(this.clients.values()).filter(
      (c) => c.status === SessionStatus.CONNECTED || c.status === SessionStatus.READY,
    ).length;
  }
  getTotalSessionsCount(): number {
    return this.clients.size;
  }

  async syncContacts(sessionId: string, userId: string): Promise<{ synced: number }> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId)
      throw new Error('Session not found or access denied');
    this.logger.log(`[SessionManager] Syncing contacts for session: ${sessionId}`);
    this.emitEvent(sessionId, userId, SessionStatus.READY, {
      type: 'contact_sync_progress',
      progress: 0,
    });
    try {
      const response = await this.request<{ contacts: Array<Record<string, unknown>> }>(
        openWAClient.client,
        'GET',
        `/api/sessions/${sessionId}/contacts`,
      );
      
      const contacts = response.contacts || [];
      
      // Persist contacts to database
      if (contacts.length > 0) {
        const persistResult = await this.persistContacts(sessionId, userId, contacts);
        this.logger.log(`[SessionManager] Persisted ${persistResult.synced} contacts to DB`);
      }
      
      this.emitEvent(sessionId, userId, SessionStatus.READY, {
        type: 'contact_sync_complete',
        count: contacts.length,
      });
      return { synced: contacts.length };
    } catch (error) {
      this.logger.error(`Failed to sync contacts: ${sessionId}`, error);
      throw error;
    }
  }

  async getChats(sessionId: string, userId: string): Promise<Array<Record<string, unknown>>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId)
      throw new Error('Session not found or access denied');
    try {
      const response = await this.request<{ chats: Array<Record<string, unknown>> }>(
        openWAClient.client,
        'GET',
        `/api/sessions/${sessionId}/chats`,
      );
      return response.chats || [];
    } catch (error) {
      this.logger.error(`Failed to get chats: ${sessionId}`, error);
      throw error;
    }
  }

  async getContacts(sessionId: string, userId: string): Promise<Array<Record<string, unknown>>> {
    const openWAClient = this.getClientBySessionId(sessionId);
    if (!openWAClient || openWAClient.userId !== userId)
      throw new Error('Session not found or access denied');
    try {
      const response = await this.request<{ contacts: Array<Record<string, unknown>> }>(
        openWAClient.client,
        'GET',
        `/api/sessions/${sessionId}/contacts`,
      );
      return response.contacts || [];
    } catch (error) {
      this.logger.error(`Failed to get contacts: ${sessionId}`, error);
      throw error;
    }
  }
}
