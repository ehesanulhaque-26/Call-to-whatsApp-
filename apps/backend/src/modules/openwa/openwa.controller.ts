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
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiBody,
  ApiBadRequestResponse,
  ApiNotFoundResponse,
  ApiConflictResponse,
  ApiRequestTimeoutResponse,
  ApiForbiddenResponse,
  ApiServiceUnavailableResponse,
  ApiInternalServerErrorResponse,
} from '@nestjs/swagger';
import { OpenWAService } from './openwa.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { RequestPairingCodeDto } from './dto';

@ApiTags('openwa')
@ApiBearerAuth()
@Controller('openwa')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OpenWAController {
  private currentPollingAbortController: AbortController | null = null;
  private currentPollingSessionId: string | null = null;

  constructor(private readonly openWAService: OpenWAService) {}

  /**
   * Cancel any ongoing polling for a previous session
   * This ensures only one session creation flow is active at a time
   */
  private cancelOngoingPolling(): void {
    if (this.currentPollingAbortController) {
      console.log(
        `[OpenWA Controller] CANCEL POLLING - Aborting previous polling for session: ${this.currentPollingSessionId}`,
      );
      this.currentPollingAbortController.abort();
      this.currentPollingAbortController = null;
      this.currentPollingSessionId = null;
    }
  }

  @Get('health')
  @ApiOperation({ summary: 'Check OpenWA server health' })
  @ApiResponse({ status: 200, description: 'OpenWA server status' })
  async healthCheck() {
    return this.openWAService.healthCheck();
  }

  // Session endpoints
  @Post('sessions')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new WhatsApp session and start it to get QR code' })
  @ApiResponse({ status: 201, description: 'Session created and started' })
  async createSession(@Body() body: { name: string; config?: Record<string, unknown> }) {
    console.log(`[OpenWA Controller] ========== ENTERED OpenWAController.createSession ==========`);
    console.log(`[OpenWA Controller] CREATE SESSION - Received body:`, JSON.stringify(body));

    // CANCEL any ongoing polling from previous session creation
    // This prevents stale polling loops from continuing after session deletion
    this.cancelOngoingPolling();

    const sessionName = body?.name;
    console.log(`[OpenWA Controller] CREATE SESSION - Extracted name: "${sessionName}"`);

    // Generate a name if not provided or invalid
    let finalName = sessionName;
    if (!finalName || finalName === 'undefined' || finalName === 'null') {
      finalName = `wa-${Date.now()}`;
      console.log(`[OpenWA Controller] CREATE SESSION - Generated name: "${finalName}"`);
    }

    // Step 0: Check for existing sessions
    // Only delete sessions that are NOT in a ready/active state
    // We preserve QR_READY sessions because they may be in use for pairing or QR scanning
    console.log(`[OpenWA Controller] CREATE SESSION - Step 0: Checking for existing sessions...`);
    const existingSessions = await this.openWAService.getAllSessions();
    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 0: Found ${existingSessions.length} existing sessions`,
    );

    // Normalize status for comparison (OpenWA returns various formats)
    const activeStatuses = ['qr_ready', 'QR_READY', 'connecting', 'CONNECTING', 'authenticated', 'AUTHENTICATED'];
    
    if (existingSessions.length > 0) {
      for (const session of existingSessions) {
        const isActive = activeStatuses.includes(session.status) || 
                         session.status?.toLowerCase().includes('ready') ||
                         session.status?.toLowerCase().includes('connecting');
        
        if (isActive) {
          // Session is active - check if it has a QR code we can reuse
          console.log(
            `[OpenWA Controller] CREATE SESSION - Step 0:   Session ${session.id} is ACTIVE (status: ${session.status}), checking for QR...`,
          );
          
          try {
            const qrResponse = await this.openWAService.getQRCode(session.id);
            if (qrResponse?.qrCode) {
              // Reuse existing active session with QR
              console.log(
                `[OpenWA Controller] CREATE SESSION - Step 0:   REUSING active session ${session.id} with existing QR`,
              );
                
              // Return existing session with its QR code
              return {
                id: session.id,
                name: session.name,
                qr: qrResponse.qrCode,
                status: 'qr_generated',
              };
            }
          } catch (qrError) {
            // No QR available, will proceed to create new session
            console.log(
              `[OpenWA Controller] CREATE SESSION - Step 0:   Session ${session.id} has no QR, will create new`,
            );
          }
        } else {
          // Session is not active (created, disconnected, failed) - safe to delete
          console.log(
            `[OpenWA Controller] CREATE SESSION - Step 0:   Deleting INACTIVE session: ${session.id} (status: ${session.status})`,
          );
          await this.openWAService.deleteSessionFromServer(session.id);
        }
      }
    }

    // Step 1: Create the session
    console.log(`[OpenWA Controller] CREATE SESSION - Step 1: Creating session in OpenWA...`);
    const createResult = await this.openWAService.createSession(finalName, body.config);
    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 1: Session created:`,
      JSON.stringify(createResult),
    );

    // Step 2: Start the session (fire-and-forget to avoid 60s timeout)
    // This triggers QR generation in OpenWA while we poll separately
    const sessionId = createResult.id || finalName;
    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 2: Initiating session start (no-wait)...`,
    );
    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 2: POST /api/sessions/${sessionId}/start`,
    );

    // Use fire-and-forget to avoid blocking on OpenWA's slow /start endpoint
    await this.openWAService.startSessionNoWait(sessionId);
    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 2: Session start initiated (not waiting)`,
    );

    // Step 3: Poll for QR code
    console.log(`[OpenWA Controller] CREATE SESSION - Step 3: Polling for QR code...`);

    // Create a new AbortController for this polling operation
    // This allows us to cancel this polling if another session creation starts
    this.currentPollingAbortController = new AbortController();
    this.currentPollingSessionId = sessionId;
    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 3: Starting polling for session: ${sessionId}`,
    );

    let qrCode: string | null = null;
    try {
      qrCode = await this.pollForQRCode(
        sessionId,
        30,
        2000,
        this.currentPollingAbortController.signal,
      );
    } finally {
      // Clean up tracking after polling completes (success or abort)
      this.currentPollingAbortController = null;
      this.currentPollingSessionId = null;
    }

    console.log(
      `[OpenWA Controller] CREATE SESSION - Step 3: QR code received: ${qrCode ? 'YES (length: ' + qrCode.length + ')' : 'NO'}`,
    );
    console.log(`[OpenWA Controller] ========== EXITING OpenWAController.createSession ==========`);

    return {
      ...createResult,
      qr: qrCode,
      status: qrCode ? 'qr_generated' : createResult.status,
    };
  }

  /**
   * Poll for QR code until it's ready, timeout, or aborted
   * @param sessionId - The session ID to poll
   * @param maxAttempts - Maximum number of polling attempts
   * @param intervalMs - Interval between attempts in milliseconds
   * @param signal - AbortController signal to allow cancellation
   */
  private async pollForQRCode(
    sessionId: string,
    maxAttempts = 30,
    intervalMs = 2000,
    signal?: AbortSignal,
  ): Promise<string | null> {
    // Check if already aborted before starting
    if (signal?.aborted) {
      console.log(
        `[OpenWA Controller] POLL QR - Aborted before starting for session: ${sessionId}`,
      );
      return null;
    }

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      // Check for abort signal
      if (signal?.aborted) {
        console.log(
          `[OpenWA Controller] POLL QR - Aborted on attempt ${attempt} for session: ${sessionId}`,
        );
        return null;
      }

      console.log(
        `[OpenWA Controller] POLL QR - Attempt ${attempt}/${maxAttempts}: GET /api/sessions/${sessionId}/qr`,
      );

      try {
        const qrResponse = await this.openWAService.getQRCode(sessionId);
        console.log(
          `[OpenWA Controller] POLL QR - Attempt ${attempt}: Response:`,
          JSON.stringify(qrResponse),
        );

        // OpenWA returns qrCode field (not qr)
        const qrCode = qrResponse?.qrCode;
        if (qrCode) {
          console.log(`[OpenWA Controller] POLL QR - QR code received on attempt ${attempt}`);
          return qrCode;
        }

        // Check if session is already connected or QR is ready
        const statusResponse = await this.openWAService.getSession(sessionId);
        console.log(
          `[OpenWA Controller] POLL QR - Attempt ${attempt}: Session status:`,
          JSON.stringify(statusResponse),
        );

        const status = statusResponse?.status;
        if (status === 'READY' || status === 'CONNECTING') {
          console.log(
            `[OpenWA Controller] POLL QR - Session already connected/connecting on attempt ${attempt}`,
          );
          return null;
        }
        if (status === 'QR_READY') {
          console.log(`[OpenWA Controller] POLL QR - QR_READY status on attempt ${attempt}`);
        }
      } catch (error) {
        console.log(`[OpenWA Controller] POLL QR - Attempt ${attempt}: Error:`, error);
      }

      // Wait before next attempt (unless aborted)
      if (attempt < maxAttempts && !signal?.aborted) {
        await new Promise((resolve) => setTimeout(resolve, intervalMs));
      }
    }

    console.log(`[OpenWA Controller] POLL QR - Timed out after ${maxAttempts} attempts`);
    return null;
  }

  @Get('sessions')
  @ApiOperation({ summary: 'Get all sessions' })
  @ApiResponse({ status: 200, description: 'List of sessions' })
  async getSessions() {
    const sessions = await this.openWAService.getSessions();
    return { sessions };
  }

  // IMPORTANT: /status route must come BEFORE /:sessionId to avoid route conflict
  // NestJS matches routes in order, so /status would be matched as sessionId="status" otherwise
  @Get('sessions/:sessionId/status')
  @ApiOperation({ summary: 'Get session status for polling (Flutter integration)' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Session status with state, qr, and phone' })
  async getSessionStatus(@Param('sessionId') sessionId: string) {
    console.log(
      `[OpenWA Controller] GET SESSION STATUS - Received request for session: ${sessionId}`,
    );
    const status = await this.openWAService.getSessionStatus(sessionId);
    console.log(`[OpenWA Controller] GET SESSION STATUS - Returning: ${JSON.stringify(status)}`);
    return status;
  }

  @Get('sessions/:sessionId')
  @ApiOperation({ summary: 'Get session details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Session details' })
  async getSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.getSession(sessionId);
  }

  @Post('sessions/:sessionId/start')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Start session and generate QR code' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Session started' })
  async startSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.startSession(sessionId);
  }

  @Post('sessions/:sessionId/stop')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Stop/logout session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Session stopped' })
  async stopSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.stopSession(sessionId);
  }

  @Get('sessions/:sessionId/qr')
  @ApiOperation({ summary: 'Get QR code for session (call start first)' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'QR code data' })
  async getQRCode(@Param('sessionId') sessionId: string) {
    const qrResponse = await this.openWAService.getQRCode(sessionId);
    // Return in format expected by client
    return { qr: qrResponse.qrCode, status: qrResponse.status };
  }

  @Post('sessions/:sessionId/reconnect')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reconnect session (calls start)' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Reconnection initiated' })
  async reconnectSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.reconnectSession(sessionId);
  }

  @Post('sessions/:sessionId/logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout session (calls stop)' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Logout successful' })
  async logoutSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.logoutSession(sessionId);
  }

  @Post('sessions/:sessionId/pairing-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Request pairing code for phone number authentication',
    description:
      'Request a pairing code to link your WhatsApp account via phone number instead of scanning a QR code. ' +
      'The phone number must be in international format (e.g., +919876543210). ' +
      'Enter the pairing code on your WhatsApp app when prompted.',
  })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiBody({ type: RequestPairingCodeDto })
  @ApiResponse({
    status: 200,
    description: 'Pairing code generated successfully',
    schema: {
      type: 'object',
      properties: {
        pairingCode: {
          type: 'string',
          example: 'ABCD-EFGH',
          description: 'The pairing code to enter on WhatsApp',
        },
        status: {
          type: 'string',
          example: 'PAIRING',
          description: 'Current pairing status',
        },
      },
    },
  })
  @ApiBadRequestResponse({
    description: 'Invalid phone number format or missing required fields',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 400 },
        message: {
          type: 'array',
          items: { type: 'string' },
          example: ['phone number must be in international format (e.g., +919876543210)'],
        },
        error: { type: 'string', example: 'Bad Request' },
      },
    },
  })
  @ApiNotFoundResponse({
    description: 'Session not found',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 404 },
        message: { type: 'string', example: 'Session not found' },
        error: { type: 'string', example: 'Not Found' },
      },
    },
  })
  @ApiConflictResponse({
    description: 'Session is already connected',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 409 },
        message: {
          type: 'string',
          example: 'Session is already connected. Please disconnect first.',
        },
        error: { type: 'string', example: 'Conflict' },
      },
    },
  })
  @ApiRequestTimeoutResponse({
    description: 'Pairing request timed out',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 408 },
        message: { type: 'string', example: 'Pairing request timed out. Please try again.' },
        error: { type: 'string', example: 'Request Timeout' },
      },
    },
  })
  @ApiForbiddenResponse({
    description: 'Pairing request rejected by WhatsApp',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 403 },
        message: {
          type: 'string',
          example: 'Pairing request was rejected. Please try again later.',
        },
        error: { type: 'string', example: 'Forbidden' },
      },
    },
  })
  @ApiServiceUnavailableResponse({
    description: 'OpenWA server unavailable',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 503 },
        message: { type: 'string', example: 'OpenWA server is unavailable' },
        error: { type: 'string', example: 'Service Unavailable' },
      },
    },
  })
  @ApiInternalServerErrorResponse({
    description: 'Internal server error',
    schema: {
      type: 'object',
      properties: {
        statusCode: { type: 'number', example: 500 },
        message: { type: 'string', example: 'Failed to request pairing code' },
        error: { type: 'string', example: 'Internal Server Error' },
      },
    },
  })
  async requestPairingCode(
    @Param('sessionId') sessionId: string,
    @Body() body: RequestPairingCodeDto,
  ) {
    console.log(
      `[OpenWA Controller] PAIRING CODE REQUEST - Received request for session: ${sessionId}`,
    );
    console.log(`[OpenWA Controller] PAIRING CODE REQUEST - Phone number: ${body.phoneNumber}`);

    const result = await this.openWAService.requestPairingCode(sessionId, body.phoneNumber);

    console.log(
      `[OpenWA Controller] PAIRING CODE REQUEST - Returning pairing code: ${result.pairingCode}`,
    );

    return result;
  }

  @Delete('sessions/:sessionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 204, description: 'Session deleted' })
  async deleteSession(@Param('sessionId') sessionId: string) {
    await this.openWAService.deleteSession(sessionId);
  }

  // Messaging endpoints
  @Post('sessions/:sessionId/send-text')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send text message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Message sent' })
  async sendTextMessage(
    @Param('sessionId') sessionId: string,
    @Body() body: { chatId: string; text: string; mentions?: string[] },
  ) {
    return this.openWAService.sendTextMessage(sessionId, body.chatId, body.text, body.mentions);
  }

  @Post('sessions/:sessionId/send-media')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send media message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Message sent' })
  async sendMediaMessage(
    @Param('sessionId') sessionId: string,
    @Body() body: { chatId: string; mediaUrl: string; caption?: string; mimetype?: string },
  ) {
    return this.openWAService.sendMediaMessage(
      sessionId,
      body.chatId,
      body.mediaUrl,
      body.caption,
      body.mimetype,
    );
  }

  // Chat & Contact endpoints
  @Get('sessions/:sessionId/chats')
  @ApiOperation({ summary: 'Get all chats for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'List of chats' })
  async getChats(@Param('sessionId') sessionId: string) {
    return this.openWAService.getChats(sessionId);
  }

  @Get('sessions/:sessionId/contacts')
  @ApiOperation({ summary: 'Get all contacts for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'List of contacts' })
  async getContacts(@Param('sessionId') sessionId: string) {
    return this.openWAService.getContacts(sessionId);
  }

  @Get('sessions/:sessionId/contacts/:contactId')
  @ApiOperation({ summary: 'Get contact details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiParam({ name: 'contactId', description: 'Contact ID' })
  @ApiResponse({ status: 200, description: 'Contact details' })
  async getContact(@Param('sessionId') sessionId: string, @Param('contactId') contactId: string) {
    return this.openWAService.getContact(sessionId, contactId);
  }

  // Group endpoints
  @Get('sessions/:sessionId/groups')
  @ApiOperation({ summary: 'Get all groups for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'List of groups' })
  async getGroups(@Param('sessionId') sessionId: string) {
    return this.openWAService.getGroups(sessionId);
  }

  @Get('sessions/:sessionId/groups/:groupId')
  @ApiOperation({ summary: 'Get group details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiParam({ name: 'groupId', description: 'Group ID' })
  @ApiResponse({ status: 200, description: 'Group details' })
  async getGroup(@Param('sessionId') sessionId: string, @Param('groupId') groupId: string) {
    return this.openWAService.getGroup(sessionId, groupId);
  }

  // Template endpoints
  @Get('sessions/:sessionId/templates')
  @ApiOperation({ summary: 'Get all templates for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'List of templates' })
  async getTemplates(@Param('sessionId') sessionId: string) {
    return this.openWAService.getTemplates(sessionId);
  }

  @Post('sessions/:sessionId/send-template')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send template message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID (UUID)' })
  @ApiResponse({ status: 200, description: 'Template sent' })
  async sendTemplateMessage(
    @Param('sessionId') sessionId: string,
    @Body() body: { chatId: string; templateName: string; templateData?: Record<string, string> },
  ) {
    return this.openWAService.sendTemplateMessage(
      sessionId,
      body.chatId,
      body.templateName,
      body.templateData,
    );
  }
}
