import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';

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

  constructor(private readonly configService: ConfigService) {
    const baseURL = this.configService.get<string>('OPENWA_URL');
    
    if (!baseURL) {
      this.logger.warn('OPENWA_URL not configured - OpenWA service will not be available');
    }

    this.client = axios.create({
      baseURL: baseURL || 'http://localhost:8080',
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  private async request<T>(method: string, path: string, data?: unknown): Promise<T> {
    try {
      const response = await this.client.request<T>({
        method,
        url: path,
        data,
      });
      return response.data;
    } catch (error) {
      this.logger.error(`OpenWA API error: ${method} ${path}`, error);
      throw new HttpException(
        'Failed to communicate with OpenWA server',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  // Health Check
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    return this.request('GET', '/health');
  }

  // Session Management
  async createSession(sessionId?: string): Promise<OpenWASession> {
    const payload = sessionId ? { sessionId } : {};
    return this.request<OpenWASession>('POST', '/sessions', payload);
  }

  async deleteSession(sessionId: string): Promise<{ success: boolean }> {
    return this.request('DELETE', `/sessions/${sessionId}`);
  }

  async getSession(sessionId: string): Promise<OpenWASession> {
    return this.request<OpenWASession>('GET', `/sessions/${sessionId}`);
  }

  async getSessionStatus(sessionId: string): Promise<OpenWASessionStatus> {
    return this.request<OpenWASessionStatus>('GET', `/sessions/${sessionId}/status`);
  }

  async getQRCode(sessionId: string): Promise<{ qr: string }> {
    return this.request<{ qr: string }>('GET', `/sessions/${sessionId}/qr`);
  }

  async reconnectSession(sessionId: string): Promise<{ success: boolean }> {
    return this.request('POST', `/sessions/${sessionId}/reconnect`);
  }

  async logoutSession(sessionId: string): Promise<{ success: boolean }> {
    return this.request('POST', `/sessions/${sessionId}/logout`);
  }

  // Messaging
  async sendTextMessage(sessionId: string, to: string, text: string): Promise<OpenWASendMessageResult> {
    return this.request<OpenWASendMessageResult>('POST', `/sessions/${sessionId}/send-text`, {
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
    return this.request<OpenWASendMessageResult>(
      'POST',
      `/sessions/${sessionId}/send-media`,
      {
        to,
        mediaUrl,
        caption,
        mimetype,
      },
    );
  }

  // Chats & Contacts
  async getChats(sessionId: string): Promise<{ chats: unknown[] }> {
    return this.request<{ chats: unknown[] }>('GET', `/sessions/${sessionId}/chats`);
  }

  async getContacts(sessionId: string): Promise<{ contacts: unknown[] }> {
    return this.request<{ contacts: unknown[] }>('GET', `/sessions/${sessionId}/contacts`);
  }

  async getContact(sessionId: string, contactId: string): Promise<unknown> {
    return this.request('GET', `/sessions/${sessionId}/contacts/${contactId}`);
  }

  // Groups
  async getGroups(sessionId: string): Promise<{ groups: unknown[] }> {
    return this.request<{ groups: unknown[] }>('GET', `/sessions/${sessionId}/groups`);
  }

  async getGroup(sessionId: string, groupId: string): Promise<unknown> {
    return this.request('GET', `/sessions/${sessionId}/groups/${groupId}`);
  }

  // Templates
  async getTemplates(sessionId: string): Promise<{ templates: unknown[] }> {
    return this.request<{ templates: unknown[] }>('GET', `/sessions/${sessionId}/templates`);
  }

  async sendTemplateMessage(
    sessionId: string,
    to: string,
    templateName: string,
    templateData?: Record<string, string>,
  ): Promise<OpenWASendMessageResult> {
    return this.request<OpenWASendMessageResult>(
      'POST',
      `/sessions/${sessionId}/send-template`,
      {
        to,
        templateName,
        templateData,
      },
    );
  }
}
