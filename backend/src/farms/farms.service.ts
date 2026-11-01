import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateFarmDto, UpdateFarmDto } from './dto/farm.dto.js';

@Injectable()
export class FarmsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateFarmDto) {
    return this.prisma.farm.create({
      data: {
        userId,
        name: dto.name,
        boundary: dto.boundary.map((p) => ({
          latitude: p.latitude,
          longitude: p.longitude,
          accuracyMeters: p.accuracyMeters,
          timestamp: p.timestamp ? new Date(p.timestamp) : new Date(),
        })),
        center: {
          latitude: dto.center.latitude,
          longitude: dto.center.longitude,
          accuracyMeters: dto.center.accuracyMeters,
          timestamp: dto.center.timestamp ? new Date(dto.center.timestamp) : new Date(),
        },
        areaSquareMeters: dto.areaSquareMeters ?? 0.0,
        cropType: dto.cropType,
      },
    });
  }

  async findUserFarms(userId: string) {
    return this.prisma.farm.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(userId: string, id: string) {
    const farm = await this.prisma.farm.findFirst({
      where: { id, userId },
      include: { detections: true },
    });
    if (!farm) {
      throw new NotFoundException('Farm not found');
    }
    return farm;
  }

  async update(userId: string, id: string, dto: UpdateFarmDto) {
    await this.findOne(userId, id); // ownership check
    return this.prisma.farm.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.cropType !== undefined && { cropType: dto.cropType }),
        ...(dto.areaSquareMeters !== undefined && { areaSquareMeters: dto.areaSquareMeters }),
        ...(dto.boundary !== undefined && {
          boundary: dto.boundary.map((p) => ({
            latitude: p.latitude,
            longitude: p.longitude,
            accuracyMeters: p.accuracyMeters,
            timestamp: p.timestamp ? new Date(p.timestamp) : new Date(),
          })),
        }),
        ...(dto.center !== undefined && {
          center: {
            latitude: dto.center.latitude,
            longitude: dto.center.longitude,
            accuracyMeters: dto.center.accuracyMeters,
            timestamp: dto.center.timestamp ? new Date(dto.center.timestamp) : new Date(),
          },
        }),
      },
    });
  }

  async remove(userId: string, id: string) {
    await this.findOne(userId, id);
    return this.prisma.farm.delete({
      where: { id },
    });
  }
}

