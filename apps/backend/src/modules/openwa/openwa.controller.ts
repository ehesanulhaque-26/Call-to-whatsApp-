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
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags, ApiOperation, ApiResponse, ApiParam } from '@nestjs/swagger';
import { OpenWAService } from './openwa.service';
import { RolesGuard } from '../../common/guards/roles.guard';

@ApiTags('openwa')
@ApiBearerAuth()
@Controller('openwa')
@UseGuards(AuthGuard('jwt'), RolesGuard)
export class OpenWAController {
  constructor(private readonly openWAService: OpenWAService) {}

  @Get('health')
  @ApiOperation({ summary: 'Check OpenWA server health' })
  @ApiResponse({ status: 200, description: 'OpenWA server status' })
  async healthCheck() {
    return this.openWAService.healthCheck();
  }

  // Session endpoints
  @Post('sessions')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new session' })
  @ApiResponse({ status: 201, description: 'Session created' })
  async createSession(@Body('sessionId') sessionId?: string) {
    return this.openWAService.createSession(sessionId);
  }

  @Get('sessions')
  @ApiOperation({ summary: 'Get all sessions' })
  @ApiResponse({ status: 200, description: 'List of sessions' })
  async getSessions() {
    // Returns list of all sessions (placeholder)
    return { sessions: [] };
  }

  @Get('sessions/:sessionId')
  @ApiOperation({ summary: 'Get session details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Session details' })
  async getSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.getSession(sessionId);
  }

  @Get('sessions/:sessionId/status')
  @ApiOperation({ summary: 'Get session status' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Session status' })
  async getSessionStatus(@Param('sessionId') sessionId: string) {
    return this.openWAService.getSessionStatus(sessionId);
  }

  @Get('sessions/:sessionId/qr')
  @ApiOperation({ summary: 'Get QR code for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'QR code data' })
  async getQRCode(@Param('sessionId') sessionId: string) {
    return this.openWAService.getQRCode(sessionId);
  }

  @Post('sessions/:sessionId/reconnect')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reconnect session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Reconnection initiated' })
  async reconnectSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.reconnectSession(sessionId);
  }

  @Post('sessions/:sessionId/logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Logout successful' })
  async logoutSession(@Param('sessionId') sessionId: string) {
    return this.openWAService.logoutSession(sessionId);
  }

  @Delete('sessions/:sessionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 204, description: 'Session deleted' })
  async deleteSession(@Param('sessionId') sessionId: string) {
    await this.openWAService.deleteSession(sessionId);
  }

  // Messaging endpoints
  @Post('sessions/:sessionId/send-text')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send text message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Message sent' })
  async sendTextMessage(
    @Param('sessionId') sessionId: string,
    @Body() body: { to: string; text: string },
  ) {
    return this.openWAService.sendTextMessage(sessionId, body.to, body.text);
  }

  @Post('sessions/:sessionId/send-media')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send media message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Message sent' })
  async sendMediaMessage(
    @Param('sessionId') sessionId: string,
    @Body() body: { to: string; mediaUrl: string; caption?: string; mimetype?: string },
  ) {
    return this.openWAService.sendMediaMessage(
      sessionId,
      body.to,
      body.mediaUrl,
      body.caption,
      body.mimetype,
    );
  }

  // Chat & Contact endpoints
  @Get('sessions/:sessionId/chats')
  @ApiOperation({ summary: 'Get all chats for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'List of chats' })
  async getChats(@Param('sessionId') sessionId: string) {
    return this.openWAService.getChats(sessionId);
  }

  @Get('sessions/:sessionId/contacts')
  @ApiOperation({ summary: 'Get all contacts for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'List of contacts' })
  async getContacts(@Param('sessionId') sessionId: string) {
    return this.openWAService.getContacts(sessionId);
  }

  @Get('sessions/:sessionId/contacts/:contactId')
  @ApiOperation({ summary: 'Get contact details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiParam({ name: 'contactId', description: 'Contact ID' })
  @ApiResponse({ status: 200, description: 'Contact details' })
  async getContact(@Param('sessionId') sessionId: string, @Param('contactId') contactId: string) {
    return this.openWAService.getContact(sessionId, contactId);
  }

  // Group endpoints
  @Get('sessions/:sessionId/groups')
  @ApiOperation({ summary: 'Get all groups for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'List of groups' })
  async getGroups(@Param('sessionId') sessionId: string) {
    return this.openWAService.getGroups(sessionId);
  }

  @Get('sessions/:sessionId/groups/:groupId')
  @ApiOperation({ summary: 'Get group details' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiParam({ name: 'groupId', description: 'Group ID' })
  @ApiResponse({ status: 200, description: 'Group details' })
  async getGroup(@Param('sessionId') sessionId: string, @Param('groupId') groupId: string) {
    return this.openWAService.getGroup(sessionId, groupId);
  }

  // Template endpoints
  @Get('sessions/:sessionId/templates')
  @ApiOperation({ summary: 'Get all templates for session' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'List of templates' })
  async getTemplates(@Param('sessionId') sessionId: string) {
    return this.openWAService.getTemplates(sessionId);
  }

  @Post('sessions/:sessionId/send-template')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send template message' })
  @ApiParam({ name: 'sessionId', description: 'Session ID' })
  @ApiResponse({ status: 200, description: 'Template sent' })
  async sendTemplateMessage(
    @Param('sessionId') sessionId: string,
    @Body() body: { to: string; templateName: string; templateData?: Record<string, string> },
  ) {
    return this.openWAService.sendTemplateMessage(
      sessionId,
      body.to,
      body.templateName,
      body.templateData,
    );
  }
}
