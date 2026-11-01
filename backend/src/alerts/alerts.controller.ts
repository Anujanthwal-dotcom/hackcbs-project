import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { AlertsService } from './alerts.service.js';
import { CreateAlertDto } from './dto/alert.dto.js';

@UseGuards(JwtAuthGuard)
@Controller('alerts')
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateAlertDto) {
    return this.alertsService.create(req.user.id, dto);
  }

  @Get()
  async findAll(@Request() req: any) {
    return this.alertsService.findUserAlerts(req.user.id);
  }

  @Patch(':id/read')
  async markAsRead(@Request() req: any, @Param('id') id: string) {
    return this.alertsService.markAsRead(req.user.id, id);
  }
}

