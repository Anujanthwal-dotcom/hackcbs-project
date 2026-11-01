import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { DetectionsService } from './detections.service.js';
import { AddFieldAssessmentDto, AddMessageDto, CreateDetectionDto } from './dto/create-detection.dto.js';

@Controller('detections')
export class DetectionsController {
  constructor(private readonly detectionsService: DetectionsService) {}

  /**
   * Public Heatmap data endpoint for India dashboard.
   */
  @Get('heatmap')
  async getHeatmap(
    @Query('crop') crop?: string,
    @Query('severity') severity?: string,
    @Query('state') state?: string,
    @Query('days') days?: string,
  ) {
    return this.detectionsService.getHeatmapData({
      crop,
      severity,
      state,
      days: days ? parseInt(days, 10) : undefined,
    });
  }

  /**
   * Public Analytics & chart statistics endpoint for dashboard.
   */
  @Get('analytics')
  async getAnalytics(
    @Query('state') state?: string,
    @Query('crop') crop?: string,
  ) {
    return this.detectionsService.getAnalytics({
      state,
      crop,
    });
  }

  /**
   * Endpoint to seed national surveillance outbreak data for testing.
   */
  @Post('seed-demo')
  async seedDemo() {
    return this.detectionsService.seedSurveillanceOutbreaks();
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@Request() req: any, @Body() dto: CreateDetectionDto) {
    return this.detectionsService.create(req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  async findAll(
    @Request() req: any,
    @Query('critical') critical?: string,
  ) {
    const isCritical = critical === 'true' ? true : critical === 'false' ? false : undefined;
    return this.detectionsService.findUserDetections(req.user.id, isCritical);
  }

  @UseGuards(JwtAuthGuard)
  @Get('critical-alerts')
  async getCriticalAlerts() {
    return this.detectionsService.findCriticalAlerts();
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  async findOne(@Request() req: any, @Param('id') id: string) {
    return this.detectionsService.findOne(req.user.id, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/assessments')
  async addAssessment(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: AddFieldAssessmentDto,
  ) {
    return this.detectionsService.addAssessment(req.user.id, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/messages')
  async addMessage(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: AddMessageDto,
  ) {
    return this.detectionsService.addMessage(req.user.id, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/messages')
  async getMessages(@Request() req: any, @Param('id') id: string) {
    return this.detectionsService.getMessages(req.user.id, id);
  }
}
