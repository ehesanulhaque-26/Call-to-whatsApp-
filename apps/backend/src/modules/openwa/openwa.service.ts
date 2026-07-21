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

// Session status enum (normalized to uppercase)
// NOTE: OpenWA API returns lowercase status strings (e.g., 'qr_ready')
// We normalize them to uppercase to match this enum
export enum SessionStatus {
  CREATED = 'CREATED',
  QR_READY = 'QR_READY',
  CONNECTING = 'CONNECTING',
  READY = 'READY',
  DISCONNECTED = 'DISCONNECTED',
  FAILED = 'FAILED',
}

/**
 * Normalize OpenWA status string to match SessionStatus enum
 * OpenWA returns lowercase status strings (e.g., 'qr_ready', 'created')
 * This function converts them to uppercase (e.g., 'QR_READY', 'CREATED')
 */
function normalizeSessionStatus(status: string | undefined): SessionStatus {
  if (!status) return SessionStatus.DISCONNECTED;
  const upperStatus = status.toUpperCase() as Uppercase<typeof status>;
  switch (upperStatus) {
    case 'CREATED':
      return SessionStatus.CREATED;
    case 'QR_READY':
      return SessionStatus.QR_READY;
    case 'CONNECTING':
      return SessionStatus.CONNECTING;
    case 'READY':
      return SessionStatus.READY;
    case 'DISCONNECTED':
      return SessionStatus.DISCONNECTED;
    case 'FAILED':
      return SessionStatus.FAILED;
    default:
      return SessionStatus.DISCONNECTED;
  }
}

// QR Code response from OpenWA
export interface OpenWAQRCodeResponse {
  qrCode: string; // NOTE: Field is 'qrCode', not 'qr'
  status: SessionStatus;
}

// Pairing code response from OpenWA
export interface OpenWAPairingCodeResponse {
  pairingCode: string;
  status: string;
}

// Flutter pairing code response (clean contract for Flutter)
export interface FlutterPairingCodeResponse {
  pairingCode: string;
  status: string;
}

// Flutter session status response
// Maps OpenWA session states to Flutter contract format
export interface FlutterSessionStatusResponse {
  state: string; // Maps to Flutter's WhatsAppStatus (e.g., 'DISCONNECTED', 'READY', 'CONNECTING')
  qr?: string | null; // QR code for authentication (mapped from qrCode)
  phone?: string | null; // Connected phone number
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
  // Response: Session object with normalized status
  async getSession(sessionId: string): Promise<OpenWASession> {
    const session = await this.request<OpenWASession>('GET', `/api/sessions/${sessionId}`);
    // Normalize the status from OpenWA (lowercase) to match our enum (uppercase)
    session.status = normalizeSessionStatus(session.status);
    return session;
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
          // Normalize status for each session
          session.status = normalizeSessionStatus(session.status);
          this.logger.warn(
            `[OpenWA Service]   - Session: ${session.id}, status: ${session.status}`,
          );
        }
        return sessions;
      }
      return [];
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

  // =====================================================
  // PHONE NUMBER PAIRING
  // =====================================================

  /**
   * Request a pairing code for phone number authentication
   * This allows users to link their WhatsApp account via phone number instead of QR code
   *
   * OpenWA: POST /api/sessions/:id/pairing-code
   * Body: { phoneNumber: string }
   * Response: { pairingCode: string, status: string }
   *
   * @param sessionId - The session ID
   * @param phoneNumber - Phone number in international format (e.g., +919876543210)
   * @returns Pairing code response with code and status
   */
  async requestPairingCode(
    sessionId: string,
    phoneNumber: string,
  ): Promise<FlutterPairingCodeResponse> {
    this.logger.warn(
      `[OpenWA Service] PAIRING REQUEST - Phone number pairing requested for session: ${sessionId}`,
    );
    this.logger.warn(`[OpenWA Service] PAIRING REQUEST - Phone validated: ${phoneNumber}`);

    // Validate phone number format (basic validation)
    const cleanedPhone = phoneNumber.replace(/[\s\-()]/g, '');
    if (!cleanedPhone.match(/^\+?\d{10,15}$/)) {
      this.logger.error(
        `[OpenWA Service] PAIRING REQUEST - Invalid phone number format: ${phoneNumber}`,
      );
      throw new HttpException('Invalid phone number format', HttpStatus.BAD_REQUEST);
    }

    // Normalize phone number to ensure it starts with +
    const normalizedPhone = cleanedPhone.startsWith('+') ? cleanedPhone : `+${cleanedPhone}`;

    this.logger.warn(
      `[OpenWA Service] PAIRING REQUEST - Calling OpenWA pairing endpoint for phone: ${normalizedPhone}`,
    );

    try {
      // Call OpenWA pairing endpoint
      const response = await this.request<OpenWAPairingCodeResponse>(
        'POST',
        `/api/sessions/${sessionId}/pairing-code`,
        { phoneNumber: normalizedPhone },
      );

      this.logger.warn(
        `[OpenWA Service] PAIRING REQUEST - Pairing code received: ${response.pairingCode}`,
      );
      this.logger.warn(`[OpenWA Service] PAIRING REQUEST - Status: ${response.status}`);

      // Return clean Flutter contract
      return {
        pairingCode: response.pairingCode,
        status: response.status,
      };
    } catch (error) {
      const axiosError = error as AxiosError;
      const response = axiosError.response;

      // Handle specific error cases from OpenWA
      if (response?.status) {
        switch (response.status) {
          case 400:
            this.logger.error(
              `[OpenWA Service] PAIRING REQUEST - Bad request (invalid phone or session)`,
            );
            throw new HttpException(
              'Invalid phone number or session state',
              HttpStatus.BAD_REQUEST,
            );
          case 404:
            this.logger.error(`[OpenWA Service] PAIRING REQUEST - Session not found: ${sessionId}`);
            throw new HttpException('Session not found', HttpStatus.NOT_FOUND);
          case 409:
            this.logger.error(
              `[OpenWA Service] PAIRING REQUEST - Session already connected: ${sessionId}`,
            );
            throw new HttpException(
              'Session is already connected. Please disconnect first.',
              HttpStatus.CONFLICT,
            );
          case 408:
            this.logger.error(
              `[OpenWA Service] PAIRING REQUEST - Pairing request timeout: ${sessionId}`,
            );
            throw new HttpException(
              'Pairing request timed out. Please try again.',
              HttpStatus.REQUEST_TIMEOUT,
            );
          case 403:
            this.logger.error(
              `[OpenWA Service] PAIRING REQUEST - Pairing rejected by WhatsApp: ${sessionId}`,
            );
            throw new HttpException(
              'Pairing request was rejected. Please try again later.',
              HttpStatus.FORBIDDEN,
            );
          default:
            this.logger.error(
              `[OpenWA Service] PAIRING REQUEST - OpenWA error: ${response.status} - ${JSON.stringify(response.data)}`,
            );
        }
      }

      // If it's a timeout error
      if (axiosError.code === 'ECONNABORTED' || axiosError.code === 'ETIMEDOUT') {
        this.logger.error(`[OpenWA Service] PAIRING REQUEST - Request timeout`);
        throw new HttpException(
          'OpenWA request timed out. Please try again.',
          HttpStatus.GATEWAY_TIMEOUT,
        );
      }

      // If it's a connection error
      if (axiosError.code === 'ECONNREFUSED' || !axiosError.response) {
        this.logger.error(`[OpenWA Service] PAIRING REQUEST - OpenWA server unavailable`);
        throw new HttpException('OpenWA server is unavailable', HttpStatus.SERVICE_UNAVAILABLE);
      }

      // Re-throw HttpExceptions as-is
      if (error instanceof HttpException) {
        throw error;
      }

      // Generic error
      this.logger.error(`[OpenWA Service] PAIRING REQUEST - Unexpected error: ${error}`);
      throw new HttpException('Failed to request pairing code', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  // =====================================================
  // SESSION STATUS (for Flutter polling)
  // =====================================================

  /**
   * Get session status in Flutter contract format
   * This endpoint is polled by the Flutter app to check session state
   *
   * OpenWA: GET /api/sessions/:id (for session data)
   *         GET /api/sessions/:id/qr (for QR code, if available)
   *
   * Flutter expects: { state: string, qr?: string, phone?: string }
   * State values: 'DISCONNECTED', 'CONNECTING', 'READY', 'QR_READY', etc.
   */
  async getSessionStatus(sessionId: string): Promise<FlutterSessionStatusResponse> {
    this.logger.warn(
      `[OpenWA Service] GET SESSION STATUS - Fetching status for session: ${sessionId}`,
    );

    try {
      // Get session details from OpenWA
      const session = await this.getSession(sessionId);

      // Normalize the status from OpenWA (lowercase) to match our enum (uppercase)
      // This is critical - OpenWA returns "qr_ready" but we expect "QR_READY"
      const normalizedStatus = normalizeSessionStatus(session.status);

      this.logger.warn(
        `[OpenWA Service] GET SESSION STATUS - Session data: ${JSON.stringify({
          id: session.id,
          rawStatus: session.status,
          normalizedStatus: normalizedStatus,
          phone: session.phone,
        })}`,
      );

      // Map OpenWA status to Flutter format
      // OpenWA statuses: CREATED, QR_READY, CONNECTING, READY, DISCONNECTED, FAILED
      let qr: string | null = null;

      // Try to get QR code if session is in QR state
      // Using normalized status for comparison
      if (
        normalizedStatus === SessionStatus.QR_READY ||
        normalizedStatus === SessionStatus.CREATED
      ) {
        try {
          this.logger.warn(
            `[OpenWA Service] GET SESSION STATUS - Session in QR state, fetching QR code...`,
          );
          const qrResponse = await this.getQRCode(sessionId);

          // Also normalize QR response status
          const qrNormalizedStatus = normalizeSessionStatus(qrResponse?.status);

          this.logger.warn(
            `[OpenWA Service] GET SESSION STATUS - QR response: ${JSON.stringify({
              hasQrCode: !!qrResponse?.qrCode,
              qrCodeLength: qrResponse?.qrCode?.length || 0,
              rawStatus: qrResponse?.status,
              normalizedStatus: qrNormalizedStatus,
            })}`,
          );

          if (qrResponse?.qrCode) {
            qr = qrResponse.qrCode;
            this.logger.warn(
              `[OpenWA Service] GET SESSION STATUS - QR code retrieved (length: ${qr.length})`,
            );
          } else {
            this.logger.warn(
              `[OpenWA Service] GET SESSION STATUS - QR response received but qrCode is empty`,
            );
          }
        } catch (qrError) {
          // QR might not be available yet, that's ok
          this.logger.warn(
            `[OpenWA Service] GET SESSION STATUS - QR not available yet: ${qrError}`,
          );
        }
      } else {
        this.logger.warn(
          `[OpenWA Service] GET SESSION STATUS - Session not in QR state (normalized: ${normalizedStatus}), skipping QR fetch`,
        );
      }

      // Return the NORMALIZED status so Flutter gets consistent casing
      const result: FlutterSessionStatusResponse = {
        state: normalizedStatus,
        qr: qr,
        phone: session.phone || null,
      };

      this.logger.warn(
        `[OpenWA Service] GET SESSION STATUS - Returning: ${JSON.stringify(result)}`,
      );

      return result;
    } catch (error) {
      this.logger.error(`[OpenWA Service] GET SESSION STATUS - Error: ${error}`);

      // Return disconnected state if session not found or error
      return {
        state: 'DISCONNECTED',
        qr: null,
        phone: null,
      };
    }
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
