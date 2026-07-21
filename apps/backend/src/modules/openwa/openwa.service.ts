import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosError } from 'axios';

/**
 * Separate axios instance for fire-and-forget requests
 * Uses a short timeout so we don't block the main thread
 */
const noWaitClient = axios.create({
  timeout: 5000, // 5 second timeout for fire-and-forget requests
  headers: { 'Content-Type': 'application/json' },
});

/**
 * OpenWA API Response Types (matching actual OpenWA server implementation)
 */

// Health check response from OpenWA
export interface OpenWAHealthResponse {
  status: 'ok';
  timestamp: string;
  version: string;
}

// Session entity response from OpenWA
export interface OpenWASession {
  id: string;
  name: string;
  status: SessionStatus;
  phone?: string | null;
  pushName?: string | null;
  connectedAt?: string | null;
  lastActive?: string | null;
  createdAt: string;
  updatedAt: string;
  lastError?: string | null;
  config?: Record<string, unknown>;
  proxyUrl?: string;
  proxyType?: string;
}

// Session status enum (from OpenWA)
export enum SessionStatus {
  CREATED = 'CREATED',
  QR_READY = 'QR_READY',
  CONNECTING = 'CONNECTING',
  READY = 'READY',
  DISCONNECTED = 'DISCONNECTED',
  FAILED = 'FAILED',
}

// QR Code response from OpenWA
export interface OpenWAQRCodeResponse {
  qrCode: string; // NOTE: Field is 'qrCode', not 'qr'
  status: SessionStatus;
}

// Create session request body (OpenWA expects 'name', not 'sessionId')
export interface CreateSessionRequest {
  name: string; // Required: alphanumeric and hyphens, 3-50 chars
  config?: Record<string, unknown>;
  proxyUrl?: string;
  proxyType?: 'http' | 'https' | 'socks4' | 'socks5';
}

// Send text message request body (OpenWA expects 'chatId', not 'to')
export interface SendTextMessageRequest {
  chatId: string; // WhatsApp chat ID (phone@c.us or groupId@g.us)
  text: string; // Message content (max 4096 chars)
  mentions?: string[]; // Optional mentions
}

// Send media message request body
export interface SendMediaMessageRequest {
  chatId: string;
  mediaUrl: string;
  caption?: string;
  mimetype?: string;
  mentions?: string[];
}

// Message send response
export interface MessageResponse {
  messageId: string;
  timestamp: number;
}

// Chat summary from OpenWA
export interface ChatSummary {
  id: string;
  name: string;
  pinned?: boolean;
  unreadCount?: number;
  lastMessage?: {
    key: { id: string; fromMe: boolean };
    message?: { conversation?: string; extendedTextMessage?: { text: string } };
    messageTimestamp?: number;
  };
}

// Group info from OpenWA
export interface GroupInfo {
  id: string;
  name: string;
  linkedParentJID?: string | null;
}

@Injectable()
export class OpenWAService {
  private readonly logger = new Logger(OpenWAService.name);
  private readonly client: AxiosInstance;
  private readonly baseURL: string;
  private readonly apiKey: string | undefined;

  constructor(private readonly configService: ConfigService) {
    this.logger.warn('========================================');
    this.logger.warn('[OpenWA] SERVICE INITIALIZATION STARTING');
    this.logger.warn('[OpenWA] Environment Configuration:');

    // Get OpenWA URL from config or environment
    const openwaUrl =
      this.configService.get<string>('OPENWA_URL') ||
      process.env.OPENWA_URL ||
      'https://openwa-production-d8f8.up.railway.app';

    // Get OpenWA API key
    this.apiKey = this.configService.get<string>('OPENWA_API_KEY') || process.env.OPENWA_API_KEY;

    this.baseURL = openwaUrl;

    this.logger.warn(`[OpenWA]   OPENWA_URL: ${openwaUrl}`);
    this.logger.warn(`[OpenWA]   OPENWA_API_KEY: ${this.apiKey ? '[SET]' : '[NOT SET]'}`);
    this.logger.warn('========================================');

    // Build headers with API key
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.apiKey) {
      headers['X-API-Key'] = this.apiKey;
    }

    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: 60000,
      headers,
    });

    // Request interceptor with detailed logging
    this.client.interceptors.request.use(
      (config) => {
        const logHeaders = { ...config.headers };
        if (logHeaders['X-API-Key']) logHeaders['X-API-Key'] = '[REDACTED]';

        this.logger.warn(`[OpenWA] >>> REQUEST
  URL: ${config.baseURL}${config.url}
  Method: ${config.method?.toUpperCase()}
  Headers: ${JSON.stringify(logHeaders)}
  Data: ${config.data ? JSON.stringify(config.data) : 'none'}`);
        return config;
      },
      (error) => {
        this.logger.error(`[OpenWA] Request interceptor error: ${error.message}`);
        return Promise.reject(error);
      },
    );

    // Response interceptor with detailed logging
    this.client.interceptors.response.use(
      (response) => {
        this.logger.warn(`[OpenWA] <<< RESPONSE
  URL: ${response.config.baseURL}${response.config.url}
  Status: ${response.status} ${response.statusText}
  Data: ${JSON.stringify(response.data)}`);
        return response;
      },
      (error: AxiosError) => {
        const response = error.response;
        this.logger.error(`[OpenWA] <<< ERROR RESPONSE
  URL: ${error.config?.baseURL}${error.config?.url}
  Method: ${error.config?.method?.toUpperCase()}
  Error Code: ${error.code}
  Status: ${response?.status || 'N/A'}
  Response Data: ${response ? JSON.stringify(response.data) : 'N/A'}
  Response Headers: ${response ? JSON.stringify(response.headers) : 'N/A'}
  Message: ${error.message}`);
        return Promise.reject(error);
      },
    );
  }

  private async request<T>(method: string, path: string, data?: unknown): Promise<T> {
    const fullUrl = `${this.baseURL}${path}`;
    this.logger.warn(`[OpenWA] ${'='.repeat(50)}`);
    this.logger.warn(`[OpenWA] REQUEST: ${method.toUpperCase()} ${fullUrl}`);
    if (data) {
      this.logger.warn(`[OpenWA] Body: ${JSON.stringify(data)}`);
    }

    const startTime = Date.now();

    try {
      const response = await this.client.request<T>({
        method,
        url: path,
        data,
      });
      const duration = Date.now() - startTime;
      this.logger.warn(`[OpenWA] SUCCESS: ${response.status} in ${duration}ms`);
      this.logger.warn(`[OpenWA] ${'='.repeat(50)}`);
      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError;
      const duration = Date.now() - startTime;
      const response = axiosError.response;

      this.logger.error(`[OpenWA] FAILED after ${duration}ms`);
      this.logger.error(
        `[OpenWA] HTTP ${response?.status || 'N/A'}: ${response?.statusText || axiosError.message}`,
      );
      if (response?.data) {
        this.logger.error(`[OpenWA] Error Response: ${JSON.stringify(response.data)}`);
      }
      this.logger.error(`[OpenWA] ${'='.repeat(50)}`);

      // Preserve OpenWA's error messages
      if (response?.data && typeof response.data === 'object') {
        const errorData = response.data as { message?: string; error?: string };
        const message = errorData.message || errorData.error || axiosError.message;
        throw new HttpException(message, response.status);
      }

      throw new HttpException(
        `OpenWA request failed: ${axiosError.message}`,
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  // =====================================================
  // HEALTH CHECK
  // =====================================================
  // OpenWA: GET /api/health
  // Response: { status: 'ok', timestamp: string, version: string }
  async healthCheck(): Promise<OpenWAHealthResponse> {
    return this.request<OpenWAHealthResponse>('GET', '/api/health');
  }

  // =====================================================
  // SESSION MANAGEMENT
  // =====================================================

  // Create a new WhatsApp session
  // OpenWA: POST /api/sessions
  // Body: { name: string, config?: object, proxyUrl?: string, proxyType?: string }
  // Response: Session object
  async createSession(name: string, config?: Record<string, unknown>): Promise<OpenWASession> {
    const payload: CreateSessionRequest = { name };
    if (config) payload.config = config;

    this.logger.warn(`[OpenWA] CREATE SESSION: name="${name}"`);
    return this.request<OpenWASession>('POST', '/api/sessions', payload);
  }

  // Get all sessions
  // OpenWA: GET /api/sessions
  // Response: Session[]
  async getSessions(): Promise<OpenWASession[]> {
    return this.request<OpenWASession[]>('GET', '/api/sessions');
  }

  // Get session by ID
  // OpenWA: GET /api/sessions/:id
  // Response: Session object
  async getSession(sessionId: string): Promise<OpenWASession> {
    return this.request<OpenWASession>('GET', `/api/sessions/${sessionId}`);
  }

  /**
   * Get all sessions from OpenWA server
   * Useful for debugging stuck sessions
   */
  async getAllSessions(): Promise<OpenWASession[]> {
    this.logger.warn(`[OpenWA Service] GET ALL SESSIONS - Fetching all sessions`);
    try {
      const sessions = await this.request<OpenWASession[]>('GET', '/api/sessions');
      this.logger.warn(
        `[OpenWA Service] GET ALL SESSIONS - Found ${sessions?.length || 0} sessions`,
      );
      if (sessions) {
        for (const session of sessions) {
          this.logger.warn(
            `[OpenWA Service]   - Session: ${session.id}, status: ${session.status}`,
          );
        }
      }
      return sessions || [];
    } catch (error) {
      this.logger.error(`[OpenWA Service] GET ALL SESSIONS - Error: ${error}`);
      return [];
    }
  }

  /**
   * Delete a session from OpenWA server
   * Useful for cleaning up stuck sessions before creating new ones
   */
  async deleteSessionFromServer(sessionId: string): Promise<boolean> {
    this.logger.warn(`[OpenWA Service] DELETE SESSION - Deleting session ${sessionId}`);
    try {
      await this.request('DELETE', `/api/sessions/${sessionId}`);
      this.logger.warn(`[OpenWA Service] DELETE SESSION - Session ${sessionId} deleted`);
      return true;
    } catch (error) {
      this.logger.warn(
        `[OpenWA Service] DELETE SESSION - Could not delete session ${sessionId}: ${error}`,
      );
      return false;
    }
  }

  /**
   * Cleanup all existing sessions before creating new ones
   * This helps prevent issues with stuck sessions
   */
  async cleanupAllSessions(): Promise<void> {
    this.logger.warn(`[OpenWA Service] CLEANUP - Starting cleanup of all sessions`);
    const sessions = await this.getAllSessions();
    if (sessions.length === 0) {
      this.logger.warn(`[OpenWA Service] CLEANUP - No sessions to clean up`);
      return;
    }
    for (const session of sessions) {
      await this.deleteSessionFromServer(session.id);
    }
    this.logger.warn(`[OpenWA Service] CLEANUP - Finished cleaning up ${sessions.length} sessions`);
  }

  // Start a session (generates QR code)
  // OpenWA: POST /api/sessions/:id/start
  // Response: Session object with status
  async startSession(sessionId: string): Promise<OpenWASession> {
    this.logger.warn(
      `[OpenWA Service] START SESSION - Sending POST /api/sessions/${sessionId}/start`,
    );
    const result = await this.request<OpenWASession>('POST', `/api/sessions/${sessionId}/start`);
    this.logger.warn(`[OpenWA Service] START SESSION - Response: ${JSON.stringify(result)}`);
    return result;
  }

  /**
   * Start session without waiting for response (fire-and-forget)
   * Uses a short timeout to avoid blocking the main thread
   * The OpenWA server will continue processing in the background
   * while we poll for the QR code separately
   */
  async startSessionNoWait(sessionId: string): Promise<void> {
    const startTime = Date.now();
    this.logger.warn(
      `[OpenWA Service] START NO-WAIT - Initiating POST /api/sessions/${sessionId}/start`,
    );
    this.logger.warn(
      `[OpenWA Service] START NO-WAIT - Request sent at: ${new Date().toISOString()}`,
    );

    try {
      // Fire and forget - don't await the response
      noWaitClient
        .post(
          `${this.baseURL}/api/sessions/${sessionId}/start`,
          {},
          {
            headers: this.apiKey ? { 'X-API-Key': this.apiKey } : {},
          },
        )
        .then((response) => {
          const elapsed = Date.now() - startTime;
          this.logger.warn(
            `[OpenWA Service] START NO-WAIT - Response received after ${elapsed}ms: ${response.status}`,
          );
        })
        .catch((error) => {
          const elapsed = Date.now() - startTime;
          const status = error.response?.status;
          this.logger.warn(
            `[OpenWA Service] START NO-WAIT - Request completed (or timed out) after ${elapsed}ms, status: ${status || 'timeout/error'}`,
          );
          // Don't throw - we want to continue polling for QR regardless
        });

      this.logger.warn(
        `[OpenWA Service] START NO-WAIT - Request initiated, not waiting for response`,
      );
    } catch (error) {
      this.logger.warn(`[OpenWA Service] START NO-WAIT - Error initiating request: ${error}`);
      // Don't throw - continue with polling
    }
  }

  // Stop a session (logout)
  // OpenWA: POST /api/sessions/:id/stop
  // Response: Session object
  async stopSession(sessionId: string): Promise<OpenWASession> {
    return this.request<OpenWASession>('POST', `/api/sessions/${sessionId}/stop`);
  }

  // Delete a session
  // OpenWA: DELETE /api/sessions/:id
  // Response: 204 No Content
  async deleteSession(sessionId: string): Promise<void> {
    await this.request('DELETE', `/api/sessions/${sessionId}`);
  }

  // Get QR code for authentication
  // OpenWA: GET /api/sessions/:id/qr
  // NOTE: Must call startSession first!
  // Response: { qrCode: string, status: SessionStatus }
  async getQRCode(sessionId: string): Promise<OpenWAQRCodeResponse> {
    return this.request<OpenWAQRCodeResponse>('GET', `/api/sessions/${sessionId}/qr`);
  }

  // Reconnect - OpenWA doesn't have /reconnect endpoint
  // Use startSession to reconnect
  async reconnectSession(sessionId: string): Promise<OpenWASession> {
    return this.startSession(sessionId);
  }

  // Logout - Use stopSession instead of /logout
  async logoutSession(sessionId: string): Promise<OpenWASession> {
    return this.stopSession(sessionId);
  }

  // =====================================================
  // MESSAGING
  // =====================================================

  // Send text message
  // OpenWA: POST /api/sessions/:sessionId/send-text
  // Body: { chatId: string, text: string, mentions?: string[] }
  // Response: { messageId: string, timestamp: number }
  async sendTextMessage(
    sessionId: string,
    chatId: string,
    text: string,
    mentions?: string[],
  ): Promise<MessageResponse> {
    return this.request<MessageResponse>('POST', `/api/sessions/${sessionId}/send-text`, {
      chatId,
      text,
      mentions,
    });
  }

  // Send media message
  // OpenWA: POST /api/sessions/:sessionId/send-image
  // Body: { chatId: string, mediaUrl: string, caption?: string, mimetype?: string }
  // Response: { messageId: string, timestamp: number }
  async sendMediaMessage(
    sessionId: string,
    chatId: string,
    mediaUrl: string,
    caption?: string,
    mimetype?: string,
  ): Promise<MessageResponse> {
    return this.request<MessageResponse>('POST', `/api/sessions/${sessionId}/send-image`, {
      chatId,
      mediaUrl,
      caption,
      mimetype,
    });
  }

  // =====================================================
  // CHATS & CONTACTS
  // =====================================================

  // Get all chats
  // OpenWA: GET /api/sessions/:sessionId/chats
  // Response: ChatSummary[]
  async getChats(sessionId: string): Promise<ChatSummary[]> {
    return this.request<ChatSummary[]>('GET', `/api/sessions/${sessionId}/chats`);
  }

  // Get all contacts
  // OpenWA: GET /api/sessions/:sessionId/contacts
  async getContacts(sessionId: string): Promise<unknown[]> {
    return this.request<unknown[]>('GET', `/api/sessions/${sessionId}/contacts`);
  }

  // Get specific contact
  // OpenWA: GET /api/sessions/:sessionId/contacts/:contactId
  async getContact(sessionId: string, contactId: string): Promise<unknown> {
    return this.request('GET', `/api/sessions/${sessionId}/contacts/${contactId}`);
  }

  // =====================================================
  // GROUPS
  // =====================================================

  // Get all groups
  // OpenWA: GET /api/sessions/:sessionId/groups
  // Response: { id: string, name: string, linkedParentJID?: string }[]
  async getGroups(sessionId: string): Promise<GroupInfo[]> {
    return this.request<GroupInfo[]>('GET', `/api/sessions/${sessionId}/groups`);
  }

  // Get specific group
  // OpenWA: GET /api/sessions/:sessionId/groups/:groupId
  async getGroup(sessionId: string, groupId: string): Promise<unknown> {
    return this.request('GET', `/api/sessions/${sessionId}/groups/${groupId}`);
  }

  // =====================================================
  // TEMPLATES (placeholder - verify with OpenWA if supported)
  // =====================================================
  async getTemplates(sessionId: string): Promise<unknown[]> {
    // Templates may not be a dedicated endpoint - placeholder
    return this.request<unknown[]>('GET', `/api/sessions/${sessionId}/templates`);
  }

  async sendTemplateMessage(
    sessionId: string,
    chatId: string,
    templateName: string,
    templateData?: Record<string, string>,
  ): Promise<MessageResponse> {
    return this.request<MessageResponse>('POST', `/api/sessions/${sessionId}/send-template`, {
      chatId,
      templateName,
      ...templateData,
    });
  }
}
