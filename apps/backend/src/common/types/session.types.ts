/**
 * Unified Session Status Enum
 * This is the SINGLE AUTHORITATIVE source for session states across the entire application.
 * 
 * State Machine:
 * NOT_CREATED -> CREATING -> INITIALIZING -> QR_READY/PAIRING_READY -> 
 * CONNECTING -> CONNECTED -> DISCONNECTED -> LOGGED_OUT -> FAILED -> DELETED
 */
export enum SessionStatus {
  NOT_CREATED = 'NOT_CREATED',
  CREATING = 'CREATING',
  INITIALIZING = 'INITIALIZING',
  QR_READY = 'QR_READY',
  PAIRING_READY = 'PAIRING_READY',
  CONNECTING = 'CONNECTING',
  RECONNECTING = 'RECONNECTING',
  CONNECTED = 'CONNECTED',
  READY = 'READY',
  DISCONNECTED = 'DISCONNECTED',
  LOGGED_OUT = 'LOGGED_OUT',
  FAILED = 'FAILED',
  DELETED = 'DELETED',
}

/**
 * Map OpenWA API status strings to our unified SessionStatus
 * OpenWA returns lowercase status strings like 'qr_ready', 'created', etc.
 */
export function normalizeOpenWAStatus(status: string | undefined | null): SessionStatus {
  if (!status) return SessionStatus.DISCONNECTED;
  
  const upperStatus = status.toUpperCase().replace('-', '_') as Uppercase<typeof status>;
  
  switch (upperStatus) {
    case 'NOT_CREATED':
      return SessionStatus.NOT_CREATED;
    case 'CREATING':
      return SessionStatus.CREATING;
    case 'CREATED':
      return SessionStatus.CREATING;
    case 'INITIALIZING':
      return SessionStatus.INITIALIZING;
    case 'LOADING':
      return SessionStatus.INITIALIZING;
    case 'QR_READY':
      return SessionStatus.QR_READY;
    case 'QR_GENERATED':
      return SessionStatus.QR_READY;
    case 'QR_UPDATED':
      return SessionStatus.QR_READY;
    case 'PAIRING_READY':
      return SessionStatus.PAIRING_READY;
    case 'CONNECTING':
      return SessionStatus.CONNECTING;
    case 'RECONNECTING':
      return SessionStatus.RECONNECTING;
    case 'AUTHENTICATED':
      return SessionStatus.CONNECTING;
    case 'CONNECTED':
      return SessionStatus.CONNECTED;
    case 'READY':
      return SessionStatus.CONNECTED;
    case 'DISCONNECTED':
      return SessionStatus.DISCONNECTED;
    case 'LOGGED_OUT':
      return SessionStatus.LOGGED_OUT;
    case 'FAILED':
      return SessionStatus.FAILED;
    case 'ERROR':
      return SessionStatus.FAILED;
    case 'DELETED':
      return SessionStatus.DELETED;
    case 'DESTROYED':
      return SessionStatus.DELETED;
    default:
      return SessionStatus.DISCONNECTED;
  }
}

/**
 * Convert SessionStatus to OpenWA-compatible string
 */
export function toOpenWAStatus(status: SessionStatus): string {
  return status.toLowerCase().replace('_', '-');
}

/**
 * Session entity interface for database storage
 */
export interface SessionEntity {
  id: string;
  userId: string;
  name?: string;
  status: SessionStatus;
  phone?: string | null;
  deviceName?: string | null;
  qrCode?: string | null;
  connectionType?: 'qr' | 'pairing';
  lastScannedAt?: Date | null;
  lastMessageAt?: Date | null;
  messageCount: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Session event for WebSocket/EventEmitter
 */
export interface SessionEvent {
  sessionId: string;
  userId: string;
  status: SessionStatus;
  phone?: string | null;
  qrCode?: string | null;
  error?: string | null;
  timestamp: Date;
}
