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
    // Debug: Log all environment variables at startup
    this.logger.warn('========================================');
    this.logger.warn('[OpenWA] SERVICE INITIALIZATION STARTING');
    this.logger.warn('[OpenWA] All env vars containing OPENWA:');
    Object.keys(process.env).forEach(key => {
      if (key.toUpperCase().includes('OPENWA')) {
        this.logger.warn(`[OpenWA]   ${key} = ${process.env[key]}`);
      }
    });
    this.logger.warn('[OpenWA] All env vars containing RAILWAY:');
    Object.keys(process.env).forEach(key => {
      if (key.toUpperCase().includes('RAILWAY')) {
        this.logger.warn(`[OpenWA]   ${key} = ${process.env[key]}`);
      }
    });
    this.logger.warn('========================================');
    
    // Try multiple environment variable names
    const openwaUrl = this.configService.get<string>('OPENWA_URL') || 
                       process.env.OPENWA_URL ||
                       'http://openwa.railway.internal';
    
    this.baseURL = openwaUrl;

    this.logger.warn(`[OpenWA] ConfigService.get('OPENWA_URL') = ${this.configService.get<string>('OPENWA_URL') || 'UNDEFINED'}`);
    this.logger.warn(`[OpenWA] Using baseURL: ${this.baseURL}`);
    this.logger.warn('========================================');

    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: 60000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor for detailed logging
    this.client.interceptors.request.use(
      (config) => {
        this.logger.warn(`[OpenWA] >>> REQUEST
  URL: ${config.baseURL}${config.url}
  Method: ${config.method?.toUpperCase()}
  Headers: ${JSON.stringify(config.headers, null, 2)}
  Data: ${config.data ? JSON.stringify(config.data) : 'none'}`);
        return config;
      },
      (error) => {
        this.logger.error(`[OpenWA] Request interceptor error: ${error.message}`);
        return Promise.reject(error);
      }
    );

    // Response interceptor for detailed logging
    this.client.interceptors.response.use(
      (response) => {
        this.logger.warn(`[OpenWA] <<< RESPONSE
  URL: ${response.config.baseURL}${response.config.url}
  Status: ${response.status} ${response.statusText}
  Headers: ${JSON.stringify(response.headers, null, 2)}
  Data: ${JSON.stringify(response.data)}`);
        return response;
      },
      (error: AxiosError) => {
        this.logger.error(`[OpenWA] <<< ERROR RESPONSE
  URL: ${error.config?.baseURL}${error.config?.url}
  Method: ${error.config?.method?.toUpperCase()}
  Error Code: ${error.code}
  Status: ${error.response?.status || 'N/A'}
  Response Headers: ${error.response ? JSON.stringify(error.response.headers) : 'N/A'}
  Response Data: ${error.response ? JSON.stringify(error.response.data) : 'N/A'}
  Message: ${error.message}
  Stack: ${error.stack}`);
        return Promise.reject(error);
      }
    );
  }

  private async request<T>(method: string, path: string, data?: unknown): Promise<T> {
    const fullUrl = `${this.baseURL}${path}`;
    
    this.logger.warn(`[OpenWA] ${'='.repeat(50)}`);
    this.logger.warn(`[OpenWA] MAKING REQUEST: ${method.toUpperCase()} ${fullUrl}`);
    if (data) {
      this.logger.warn(`[OpenWA] Request data: ${JSON.stringify(data)}`);
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
      this.logger.warn(`[OpenWA] Response: ${JSON.stringify(response.data)}`);
      this.logger.warn(`[OpenWA] ${'='.repeat(50)}`);
      
      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError;
      const duration = Date.now() - startTime;
      
      this.logger.error(`[OpenWA] FAILED after ${duration}ms`);
      this.logger.error(`[OpenWA] Error code: ${axiosError.code}`);
      this.logger.error(`[OpenWA] Error message: ${axiosError.message}`);
      
      if (axiosError.code === 'ECONNREFUSED') {
        this.logger.error(`[OpenWA] CONNECTION REFUSED - Cannot reach ${this.baseURL}`);
        this.logger.error(`[OpenWA] This means OpenWA service is not accessible at this URL`);
        this.logger.error(`[OpenWA] Check: 1) OpenWA is deployed, 2) Network connectivity, 3) URL is correct`);
      } else if (axiosError.code === 'ETIMEDOUT') {
        this.logger.error(`[OpenWA] TIMEOUT - Request exceeded 60 seconds`);
      } else if (axiosError.code === 'ENOTFOUND') {
        this.logger.error(`[OpenWA] DNS LOOKUP FAILED for ${this.baseURL}`);
        this.logger.error(`[OpenWA] Check if hostname is correct`);
      } else if (axiosError.response) {
        this.logger.error(`[OpenWA] HTTP ERROR ${axiosError.response.status}`);
        this.logger.error(`[OpenWA] Response body: ${JSON.stringify(axiosError.response.data)}`);
      }
      
      this.logger.error(`[OpenWA] ${'='.repeat(50)}`);
      
      throw new HttpException(
        `OpenWA request failed: ${axiosError.message}`,
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  // Health Check - verifies connectivity to OpenWA
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    this.logger.warn(`[OpenWA] HEALTH CHECK: Calling ${this.baseURL}/api/health`);
    return this.request<{ status: string; timestamp: string }>('GET', '/api/health');
  }

  // Session Management
  async createSession(sessionId?: string): Promise<OpenWASession> {
    const payload = sessionId ? { sessionId } : {};
    this.logger.warn(`[OpenWA] CREATE SESSION: ${sessionId || 'auto-generated'}`);
    return this.request<OpenWASession>('POST', '/api/sessions', payload);
  }

  async deleteSession(sessionId: string): Promise<{ success: boolean }> {
    this.logger.warn(`[OpenWA] DELETE SESSION: ${sessionId}`);
    return this.request('DELETE', `/api/sessions/${sessionId}`);
  }

  async getSession(sessionId: string): Promise<OpenWASession> {
    this.logger.warn(`[OpenWA] GET SESSION: ${sessionId}`);
    return this.request<OpenWASession>('GET', `/api/sessions/${sessionId}`);
  }

  async getSessionStatus(sessionId: string): Promise<OpenWASessionStatus> {
    this.logger.warn(`[OpenWA] GET SESSION STATUS: ${sessionId}`);
    return this.request<OpenWASessionStatus>('GET', `/api/sessions/${sessionId}/status`);
  }

  async getQRCode(sessionId: string): Promise<{ qr: string }> {
    this.logger.warn(`[OpenWA] GET QR CODE: ${sessionId}`);
    return this.request<{ qr: string }>('GET', `/api/sessions/${sessionId}/qr`);
  }

  async reconnectSession(sessionId: string): Promise<{ success: boolean }> {
    this.logger.warn(`[OpenWA] RECONNECT SESSION: ${sessionId}`);
    return this.request('POST', `/api/sessions/${sessionId}/reconnect`);
  }

  async logoutSession(sessionId: string): Promise<{ success: boolean }> {
    this.logger.warn(`[OpenWA] LOGOUT SESSION: ${sessionId}`);
    return this.request('POST', `/api/sessions/${sessionId}/logout`);
  }

  // Messaging
  async sendTextMessage(
    sessionId: string,
    to: string,
    text: string,
  ): Promise<OpenWASendMessageResult> {
    this.logger.warn(`[OpenWA] SEND TEXT to ${to} via session ${sessionId}`);
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
    this.logger.warn(`[OpenWA] SEND MEDIA to ${to} via session ${sessionId}`);
    return this.request<OpenWASendMessageResult>('POST', `/api/sessions/${sessionId}/send-media`, {
      to,
      mediaUrl,
      caption,
      mimetype,
    });
  }

  // Chats & Contacts
  async getChats(sessionId: string): Promise<{ chats: unknown[] }> {
    this.logger.warn(`[OpenWA] GET CHATS: ${sessionId}`);
    return this.request<{ chats: unknown[] }>('GET', `/api/sessions/${sessionId}/chats`);
  }

  async getContacts(sessionId: string): Promise<{ contacts: unknown[] }> {
    this.logger.warn(`[OpenWA] GET CONTACTS: ${sessionId}`);
    return this.request<{ contacts: unknown[] }>('GET', `/api/sessions/${sessionId}/contacts`);
  }

  async getContact(sessionId: string, contactId: string): Promise<unknown> {
    this.logger.warn(`[OpenWA] GET CONTACT ${contactId}: ${sessionId}`);
    return this.request('GET', `/api/sessions/${sessionId}/contacts/${contactId}`);
  }

  // Groups
  async getGroups(sessionId: string): Promise<{ groups: unknown[] }> {
    this.logger.warn(`[OpenWA] GET GROUPS: ${sessionId}`);
    return this.request<{ groups: unknown[] }>('GET', `/api/sessions/${sessionId}/groups`);
  }

  async getGroup(sessionId: string, groupId: string): Promise<unknown> {
    this.logger.warn(`[OpenWA] GET GROUP ${groupId}: ${sessionId}`);
    return this.request('GET', `/api/sessions/${sessionId}/groups/${groupId}`);
  }

  // Templates
  async getTemplates(sessionId: string): Promise<{ templates: unknown[] }> {
    this.logger.warn(`[OpenWA] GET TEMPLATES: ${sessionId}`);
    return this.request<{ templates: unknown[] }>('GET', `/api/sessions/${sessionId}/templates`);
  }

  async sendTemplateMessage(
    sessionId: string,
    to: string,
    templateName: string,
    templateData?: Record<string, string>,
  ): Promise<OpenWASendMessageResult> {
    this.logger.warn(`[OpenWA] SEND TEMPLATE ${templateName} to ${to}`);
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
