import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateAlertDto } from './dto/alert.dto.js';

@Injectable()
export class AlertsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateAlertDto) {
    return this.prisma.alert.create({
      data: {
        userId,
        type: dto.type,
        title: dto.title,
        message: dto.message,
        severity: dto.severity,
        farmId: dto.farmId,
        weatherContext: dto.weatherContext,
        relatedDetectionId: dto.relatedDetectionId,
        read: dto.read ?? false,
      },
    });
  }

  async findUserAlerts(userId: string) {
    return this.prisma.alert.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markAsRead(userId: string, id: string) {
    return this.prisma.alert.updateMany({
      where: { id, userId },
      data: { read: true },
    });
  }
}

