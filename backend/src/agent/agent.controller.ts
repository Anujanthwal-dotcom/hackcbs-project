import { Body, Controller, Get, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { AgentService } from './agent.service.js';
import { AgentQueryDto, ConfirmActionDto } from './dto/agent-query.dto.js';

@Controller('agent')
export class AgentController {
  constructor(private readonly agentService: AgentService) {}

  @Get('health')
  getHealth() {
    return this.agentService.getHealthStatus();
  }

  @UseGuards(JwtAuthGuard)
  @Post('chat')
  async chat(@Request() req: any, @Body() dto: AgentQueryDto) {
    return this.agentService.handleQuery(req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('action/confirm')
  async confirmAction(@Request() req: any, @Body() dto: ConfirmActionDto) {
    return this.agentService.handleConfirmAction(req.user.id, dto);
  }
}

