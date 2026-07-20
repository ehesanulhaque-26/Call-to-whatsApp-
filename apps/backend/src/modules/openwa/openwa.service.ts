import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosError } from 'axios';

export interface OpenWASession {
  id: string;
  name?: string;
  status?: string;
  created_at?: string;
}

export interface OpenWASessionStatus {
  state: string;
  qr?: string;
  qr_code?: string;
}

export interface OpenWASendMessageResult {
  messageId?: string;
  key?: {
    remoteJid?: string;
    fromMe?: boolean;
    id?: string;
  };
  status?: string;
}

@Injectable()
export class OpenWAService {
  private readonly logger = new Logger(OpenWAService.name);
  private readonly client: AxiosInstance;
  private readonly baseURL: string;

  constructor(private readonly configService: ConfigService) {
    this.baseURL = this.configService.get<string>('OPENWA_URL') || 'http://openwa.railway.internal';

    this.logger.log(`[OpenWA] Initialized with base URL: ${this.baseURL}`);

    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: 60000, // 60 second timeout for WhatsApp operations
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  private async request<T>(method: string, path: string, data?: unknown): Promise<T> {
    const fullUrl = `${this.baseURL}${path}`;

    this.logger.debug(
      `[OpenWA] ${method} ${fullUrl} - Request: ${data ? JSON.stringify(data) : 'none'}`,
    );

    const startTime = Date.now();

    try {
      const response = await this.client.request<T>({
        method,
        url: path,
        data,
      });
      const duration = Date.now() - startTime;

      this.logger.log(
        `[OpenWA] ${method} ${path} - Status: ${response.status} - Duration: ${duration}ms`,
      );
      this.logger.debug(`[OpenWA] Response: ${JSON.stringify(response.data)}`);

      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError;
      const duration = Date.now() - startTime;

      if (axiosError.code === 'ECONNREFUSED') {
        this.logger.error(`[OpenWA] ${method} ${path} - Connection refused to ${this.baseURL}`);
        this.logger.error(
          `[OpenWA] Make sure OpenWA service is running and accessible at ${this.baseURL}`,
        );
      } else if (axiosError.code === 'ETIMEDOUT' || axiosError.code === 'ECONNABORTED') {
        this.logger.error(`[OpenWA] ${method} ${path} - Timeout after ${duration}ms`);
      } else if (axiosError.response) {
        this.logger.error(
          `[OpenWA] ${method} ${path} - HTTP ${axiosError.response.status}: ${JSON.stringify(axiosError.response.data)}`,
        );
      } else {
        this.logger.error(`[OpenWA] ${method} ${path} - Error: ${axiosError.message}`);
      }

      throw new HttpException(
        `OpenWA request failed: ${axiosError.message}`,
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  // Health Check - verifies connectivity to OpenWA
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    this.logger.log(`[OpenWA] Performing health check against ${this.baseURL}/api/health`);
    return this.request<{ status: string; timestamp: string }>('GET', '/api/health');
  }

  // Session Management
  async createSession(sessionId?: string): Promise<OpenWASession> {
    const payload = sessionId ? { sessionId } : {};
    this.logger.log(`[OpenWA] Creating session${sessionId ? ` with ID: ${sessionId}` : ''}`);
    return this.request<OpenWASession>('POST', '/api/sessions', payload);
  }

  async deleteSession(sessionId: string): Promise<{ success: boolean }> {
    this.logger.log(`[OpenWA] Deleting session: ${sessionId}`);
    return this.request('DELETE', `/api/sessions/${sessionId}`);
  }

  async getSession(sessionId: string): Promise<OpenWASession> {
    this.logger.debug(`[OpenWA] Getting session: ${sessionId}`);
    return this.request<OpenWASession>('GET', `/api/sessions/${sessionId}`);
  }

  async getSessionStatus(sessionId: string): Promise<OpenWASessionStatus> {
    this.logger.debug(`[OpenWA] Getting session status: ${sessionId}`);
    return this.request<OpenWASessionStatus>('GET', `/api/sessions/${sessionId}/status`);
  }

  async getQRCode(sessionId: string): Promise<{ qr: string }> {
    this.logger.log(`[OpenWA] Getting QR code for session: ${sessionId}`);
    return this.request<{ qr: string }>('GET', `/api/sessions/${sessionId}/qr`);
  }

  async reconnectSession(sessionId: string): Promise<{ success: boolean }> {
    this.logger.log(`[OpenWA] Reconnecting session: ${sessionId}`);
    return this.request('POST', `/api/sessions/${sessionId}/reconnect`);
  }

  async logoutSession(sessionId: string): Promise<{ success: boolean }> {
    this.logger.log(`[OpenWA] Logging out session: ${sessionId}`);
    return this.request('POST', `/api/sessions/${sessionId}/logout`);
  }

  // Messaging
  async sendTextMessage(
    sessionId: string,
    to: string,
    text: string,
  ): Promise<OpenWASendMessageResult> {
    this.logger.log(`[OpenWA] Sending text message to ${to} via session: ${sessionId}`);
    return this.request<OpenWASendMessageResult>('POST', `/api/sessions/${sessionId}/send-text`, {
      to,
      text,
    });
  }

  async sendMediaMessage(
    sessionId: string,
    to: string,
    mediaUrl: string,
    caption?: string,
    mimetype?: string,
  ): Promise<OpenWASendMessageResult> {
    this.logger.log(`[OpenWA] Sending media message to ${to} via session: ${sessionId}`);
    return this.request<OpenWASendMessageResult>('POST', `/api/sessions/${sessionId}/send-media`, {
      to,
      mediaUrl,
      caption,
      mimetype,
    });
  }

  // Chats & Contacts
  async getChats(sessionId: string): Promise<{ chats: unknown[] }> {
    this.logger.debug(`[OpenWA] Getting chats for session: ${sessionId}`);
    return this.request<{ chats: unknown[] }>('GET', `/api/sessions/${sessionId}/chats`);
  }

  async getContacts(sessionId: string): Promise<{ contacts: unknown[] }> {
    this.logger.debug(`[OpenWA] Getting contacts for session: ${sessionId}`);
    return this.request<{ contacts: unknown[] }>('GET', `/api/sessions/${sessionId}/contacts`);
  }

  async getContact(sessionId: string, contactId: string): Promise<unknown> {
    this.logger.debug(`[OpenWA] Getting contact ${contactId} for session: ${sessionId}`);
    return this.request('GET', `/api/sessions/${sessionId}/contacts/${contactId}`);
  }

  // Groups
  async getGroups(sessionId: string): Promise<{ groups: unknown[] }> {
    this.logger.debug(`[OpenWA] Getting groups for session: ${sessionId}`);
    return this.request<{ groups: unknown[] }>('GET', `/api/sessions/${sessionId}/groups`);
  }

  async getGroup(sessionId: string, groupId: string): Promise<unknown> {
    this.logger.debug(`[OpenWA] Getting group ${groupId} for session: ${sessionId}`);
    return this.request('GET', `/api/sessions/${sessionId}/groups/${groupId}`);
  }

  // Templates
  async getTemplates(sessionId: string): Promise<{ templates: unknown[] }> {
    this.logger.debug(`[OpenWA] Getting templates for session: ${sessionId}`);
    return this.request<{ templates: unknown[] }>('GET', `/api/sessions/${sessionId}/templates`);
  }

  async sendTemplateMessage(
    sessionId: string,
    to: string,
    templateName: string,
    templateData?: Record<string, string>,
  ): Promise<OpenWASendMessageResult> {
    this.logger.log(`[OpenWA] Sending template ${templateName} to ${to} via session: ${sessionId}`);
    return this.request<OpenWASendMessageResult>(
      'POST',
      `/api/sessions/${sessionId}/send-template`,
      {
        to,
        templateName,
        templateData,
      },
    );
  }
}
