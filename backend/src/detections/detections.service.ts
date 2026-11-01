import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AddFieldAssessmentDto, AddMessageDto, CreateDetectionDto } from './dto/create-detection.dto.js';
import { randomUUID } from 'crypto';
import { INDIAN_STATES, resolveIndianState } from './indian-states.data.js';
import { SUPPORTED_CROPS } from './crops.constants.js';

@Injectable()
export class DetectionsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateDetectionDto) {
    const isCritical = dto.isCritical ?? true;

    const detection = await this.prisma.detection.create({
      data: {
        userId,
        crop: dto.crop,
        predictedClass: dto.predictedClass,
        condition: dto.condition,
        confidence: dto.confidence,
        severity: dto.severity ?? 'CRITICAL',
        isCritical,
        margin: dto.margin,
        blurScore: dto.blurScore,
        status: dto.status,
        imageUrl: dto.imageUrl,
        notes: dto.notes,
        latitude: dto.latitude,
        longitude: dto.longitude,
        accuracyMeters: dto.accuracyMeters,
        farmId: dto.farmId && dto.farmId.length === 24 ? dto.farmId : null,
      },
    });

    return {
      message: 'Detection recorded successfully',
      detection,
    };
  }

  async findUserDetections(userId: string, criticalOnly?: boolean) {
    return this.prisma.detection.findMany({
      where: {
        userId,
        ...(criticalOnly !== undefined ? { isCritical: criticalOnly } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findCriticalAlerts() {
    return this.prisma.detection.findMany({
      where: {
        isCritical: true,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async findOne(userId: string, id: string) {
    const detection = await this.prisma.detection.findFirst({
      where: { id, userId },
    });

    if (!detection) {
      throw new NotFoundException('Detection record not found');
    }

    return detection;
  }

  async addAssessment(userId: string, detectionId: string, dto: AddFieldAssessmentDto) {
    const detection = await this.findOne(userId, detectionId);

    const assessment = {
      id: randomUUID(),
      createdAt: new Date(),
      crop: dto.crop,
      condition: dto.condition,
      mlPrediction: dto.mlPrediction,
      mlConfidence: dto.mlConfidence,
      severity: dto.severity,
      progressionStatus: dto.progressionStatus,
      recommendationSummary: dto.recommendationSummary,
      actionLevel: dto.actionLevel,
      followUpDays: dto.followUpDays ?? 7,
      farmerQuestion: dto.farmerQuestion,
      weatherSnapshot: dto.weatherSnapshot,
      imagePath: dto.imagePath,
    };

    return this.prisma.detection.update({
      where: { id: detection.id },
      data: {
        latestSeverity: dto.severity,
        latestRecommendation: dto.recommendationSummary,
        lastReviewedAt: new Date(),
        reviewCount: { increment: 1 },
        assessments: {
          push: assessment,
        },
      },
    });
  }

  async addMessage(userId: string, detectionId: string, dto: AddMessageDto) {
    const detection = await this.findOne(userId, detectionId);

    const message = {
      id: randomUUID(),
      text: dto.text,
      sender: dto.sender,
      timestamp: new Date(),
    };

    return this.prisma.detection.update({
      where: { id: detection.id },
      data: {
        messages: {
          push: message,
        },
      },
    });
  }

  async getMessages(userId: string, detectionId: string) {
    const detection = await this.findOne(userId, detectionId);
    return detection.messages || [];
  }

  /**
   * Heatmap data endpoint for India dashboard.
   * Returns confirmed detections with geographic coordinates, intensity weights,
   * state associations, and summary statistics.
   */
  async getHeatmapData(filter?: {
    crop?: string;
    severity?: string;
    state?: string;
    days?: number;
  }) {
    // Confirmed detections must have coordinates and not be plain Healthy crops
    const whereClause: any = {
      latitude: { not: null },
      longitude: { not: null },
      condition: { not: 'Healthy' },
      AND: [
        {
          OR: SUPPORTED_CROPS.map((crop) => ({
            crop: { equals: crop, mode: 'insensitive' },
          })),
        },
      ],
    };

    if (filter?.crop && filter.crop !== 'ALL') {
      whereClause.AND.push({
        crop: { equals: filter.crop, mode: 'insensitive' },
      });
    }

    if (filter?.severity && filter.severity !== 'ALL') {
      whereClause.severity = filter.severity;
    }

    if (filter?.days && filter.days > 0) {
      const sinceDate = new Date();
      sinceDate.setDate(sinceDate.getDate() - filter.days);
      whereClause.createdAt = { gte: sinceDate };
    }

    const detections = await this.prisma.detection.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
    });

    const severityWeight = (sev: string): number => {
      switch (sev?.toUpperCase()) {
        case 'CRITICAL':
          return 1.0;
        case 'HIGH':
          return 0.75;
        case 'MEDIUM':
          return 0.5;
        case 'LOW':
        default:
          return 0.35;
      }
    };

    // Map detections with resolved state and district details
    let mappedPoints = detections.map((d) => {
      const stateInfo = resolveIndianState(d.latitude!, d.longitude!);
      const weight = Number((severityWeight(d.severity) * Math.min(1.0, (d.confidence || 0.9))).toFixed(2));

      return {
        id: d.id,
        latitude: d.latitude!,
        longitude: d.longitude!,
        crop: d.crop,
        condition: d.condition,
        predictedClass: d.predictedClass,
        confidence: d.confidence,
        severity: d.severity,
        isCritical: d.isCritical,
        status: d.status,
        state: stateInfo.name,
        stateCode: stateInfo.code,
        district: stateInfo.keyDistricts[Math.abs(Math.round(d.latitude! * 10)) % stateInfo.keyDistricts.length] || stateInfo.name,
        weight,
        createdAt: d.createdAt,
        latestSeverity: d.latestSeverity,
        latestRecommendation: d.latestRecommendation,
        reviewCount: d.reviewCount,
      };
    });

    // Filter by state if specified
    if (filter?.state && filter.state !== 'ALL') {
      mappedPoints = mappedPoints.filter(
        (p) =>
          p.state.toLowerCase() === filter.state!.toLowerCase() ||
          p.stateCode.toLowerCase() === filter.state!.toLowerCase(),
      );
    }

    // Summarize counts
    const criticalCount = mappedPoints.filter((p) => p.severity === 'CRITICAL').length;
    const highCount = mappedPoints.filter((p) => p.severity === 'HIGH').length;
    const mediumCount = mappedPoints.filter((p) => p.severity === 'MEDIUM').length;
    const lowCount = mappedPoints.filter((p) => p.severity === 'LOW').length;

    // Top affected crops
    const cropCounts: Record<string, number> = {};
    const diseaseCounts: Record<string, number> = {};
    const stateCounts: Record<string, number> = {};

    for (const p of mappedPoints) {
      cropCounts[p.crop] = (cropCounts[p.crop] || 0) + 1;
      diseaseCounts[p.condition] = (diseaseCounts[p.condition] || 0) + 1;
      stateCounts[p.state] = (stateCounts[p.state] || 0) + 1;
    }

    const topAffectedCrop = Object.entries(cropCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'Cotton';
    const topDisease = Object.entries(diseaseCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'Pink Bollworm';

    return {
      summary: {
        totalConfirmed: mappedPoints.length,
        criticalCount,
        highCount,
        mediumCount,
        lowCount,
        activeHotspotStates: Object.keys(stateCounts).length,
        topAffectedCrop,
        topDisease,
      },
      points: mappedPoints,
      activeFilters: {
        crop: filter?.crop || 'ALL',
        severity: filter?.severity || 'ALL',
        state: filter?.state || 'ALL',
        days: filter?.days || 30,
      },
    };
  }

  /**
   * Analytics and state-wise statistics for dashboard charts.
   */
  async getAnalytics(filter?: { state?: string; crop?: string }) {
    const heatmapRes = await this.getHeatmapData({
      state: filter?.state,
      crop: filter?.crop,
      days: 90,
    });

    const points = heatmapRes.points;

    // Build state-level stats for all major agricultural states
    const stateStats = INDIAN_STATES.map((state) => {
      const statePoints = points.filter(
        (p) => p.state.toLowerCase() === state.name.toLowerCase() || p.stateCode === state.code,
      );

      const criticalCases = statePoints.filter((p) => p.severity === 'CRITICAL').length;
      const totalCases = statePoints.length;

      let riskLevel = 'Low';
      if (criticalCases >= 5 || totalCases >= 12) riskLevel = 'Critical';
      else if (criticalCases >= 2 || totalCases >= 6) riskLevel = 'Severe';
      else if (totalCases >= 2) riskLevel = 'Elevated';
      else if (totalCases > 0) riskLevel = 'Moderate';

      const cropCounts: Record<string, number> = {};
      const diseaseCounts: Record<string, number> = {};

      for (const p of statePoints) {
        cropCounts[p.crop] = (cropCounts[p.crop] || 0) + 1;
        diseaseCounts[p.condition] = (diseaseCounts[p.condition] || 0) + 1;
      }

      const topCrops = Object.entries(cropCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 2)
        .map(([c]) => c);

      const topDiseases = Object.entries(diseaseCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 2)
        .map(([d]) => d);

      return {
        id: state.id,
        name: state.name,
        code: state.code,
        center: state.center,
        zoom: state.zoom,
        bounds: state.bounds,
        totalCases,
        criticalCases,
        riskLevel,
        topCrops: topCrops.length > 0 ? topCrops : state.primaryCrops.slice(0, 2),
        topDiseases: topDiseases.length > 0 ? topDiseases : ['Monitoring Normal'],
      };
    }).sort((a, b) => b.totalCases - a.totalCases);

    // Crop breakdown
    const cropMap: Record<string, { count: number; critical: number }> = {};
    for (const p of points) {
      if (!cropMap[p.crop]) cropMap[p.crop] = { count: 0, critical: 0 };
      cropMap[p.crop].count++;
      if (p.severity === 'CRITICAL') cropMap[p.crop].critical++;
    }

    const totalCount = points.length || 1;
    const cropBreakdown = Object.entries(cropMap)
      .map(([crop, data]) => ({
        crop,
        count: data.count,
        critical: data.critical,
        percentage: Number(((data.count / totalCount) * 100).toFixed(1)),
      }))
      .sort((a, b) => b.count - a.count);

    // Disease breakdown
    const diseaseMap: Record<string, { crop: string; count: number; severity: string }> = {};
    for (const p of points) {
      const key = `${p.condition}__${p.crop}`;
      if (!diseaseMap[key]) {
        diseaseMap[key] = { crop: p.crop, count: 0, severity: p.severity };
      }
      diseaseMap[key].count++;
      if (p.severity === 'CRITICAL') {
        diseaseMap[key].severity = 'CRITICAL';
      }
    }

    const diseaseBreakdown = Object.entries(diseaseMap)
      .map(([key, data]) => ({
        condition: key.split('__')[0],
        crop: data.crop,
        count: data.count,
        severity: data.severity,
        percentage: Number(((data.count / totalCount) * 100).toFixed(1)),
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);

    // 14-day timeline trend
    const timelineMap: Record<string, { date: string; cases: number; critical: number }> = {};
    const today = new Date();
    for (let i = 13; i >= 0; i--) {
      const d = new Date();
      d.setDate(today.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      timelineMap[dateStr] = { date: dateStr, cases: 0, critical: 0 };
    }

    for (const p of points) {
      const pDate = new Date(p.createdAt).toISOString().split('T')[0];
      if (timelineMap[pDate]) {
        timelineMap[pDate].cases++;
        if (p.severity === 'CRITICAL') timelineMap[pDate].critical++;
      }
    }

    return {
      summary: heatmapRes.summary,
      stateStats,
      cropBreakdown,
      diseaseBreakdown,
      timelineTrends: Object.values(timelineMap),
    };
  }

  /**
   * Seeds surveillance outbreak detections for Indian agricultural states
   * to provide full national coverage when demoing or testing.
   */
  async seedSurveillanceOutbreaks() {
    // Find or create default user for surveillance points
    let user = await this.prisma.user.findFirst();
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email: 'surveillance@kisaanbandhu.in',
          name: 'Surveillance Officer',
          passwordHash: 'dummy-hash',
          role: 'OFFICER',
        },
      });
    }

    const demoSurveillanceData = [
      // Maharashtra - Vidarbha / Marathwada Cotton & Soybean Belt
      { lat: 20.3888, lng: 78.1204, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.98, sev: 'CRITICAL', isCrit: true },
      { lat: 20.4012, lng: 78.1450, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.95, sev: 'CRITICAL', isCrit: true },
      { lat: 20.7002, lng: 77.0082, crop: 'Soybean', condition: 'Caterpillar', pred: 'Soybean_Caterpillar', conf: 0.94, sev: 'HIGH', isCrit: false },
      { lat: 20.6850, lng: 77.0250, crop: 'Soybean', condition: 'Bacterial Blight', pred: 'Soybean_Bacterial_Blight', conf: 0.91, sev: 'MEDIUM', isCrit: false },
      { lat: 20.9374, lng: 77.7796, crop: 'Cotton', condition: 'Bacterial Blight', pred: 'Cotton_Bacterial_Blight', conf: 0.93, sev: 'HIGH', isCrit: false },
      { lat: 21.1458, lng: 79.0882, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.97, sev: 'CRITICAL', isCrit: true },
      { lat: 19.8762, lng: 75.3433, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.92, sev: 'HIGH', isCrit: false },

      // Punjab - Cotton Belt
      { lat: 30.2110, lng: 74.9455, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.99, sev: 'CRITICAL', isCrit: true },
      { lat: 30.2250, lng: 74.9600, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.96, sev: 'CRITICAL', isCrit: true },
      { lat: 29.9880, lng: 75.3880, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.95, sev: 'CRITICAL', isCrit: true },

      // Gujarat - Cotton Belt
      { lat: 22.3039, lng: 70.8022, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.97, sev: 'CRITICAL', isCrit: true },
      { lat: 21.6032, lng: 71.2221, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.94, sev: 'HIGH', isCrit: false },
      { lat: 21.7645, lng: 72.1519, crop: 'Cotton', condition: 'Bacterial Blight', pred: 'Cotton_Bacterial_Blight', conf: 0.88, sev: 'MEDIUM', isCrit: false },

      // Karnataka - Cotton & Soybean
      { lat: 15.8497, lng: 74.4977, crop: 'Soybean', condition: 'Rust', pred: 'Soybean_Rust', conf: 0.95, sev: 'HIGH', isCrit: false },
      { lat: 16.2120, lng: 77.3439, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.98, sev: 'CRITICAL', isCrit: true },

      // Madhya Pradesh - Soybean Belt
      { lat: 22.7196, lng: 75.8577, crop: 'Soybean', condition: 'Caterpillar', pred: 'Soybean_Caterpillar', conf: 0.96, sev: 'HIGH', isCrit: false },
      { lat: 23.1765, lng: 75.7885, crop: 'Soybean', condition: 'Bacterial Blight', pred: 'Soybean_Bacterial_Blight', conf: 0.92, sev: 'MEDIUM', isCrit: false },
      { lat: 22.9676, lng: 76.0534, crop: 'Soybean', condition: 'Yellow Mosaic', pred: 'Soybean_Yellow_Mosaic', conf: 0.94, sev: 'HIGH', isCrit: false },

      // Andhra Pradesh & Telangana - Cotton
      { lat: 15.8281, lng: 78.0373, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.94, sev: 'HIGH', isCrit: false },
      { lat: 17.9689, lng: 79.5941, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.97, sev: 'CRITICAL', isCrit: true },

      // Rajasthan
      { lat: 29.9038, lng: 73.8772, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.98, sev: 'CRITICAL', isCrit: true },
      { lat: 25.2138, lng: 75.8648, crop: 'Soybean', condition: 'Caterpillar', pred: 'Soybean_Caterpillar', conf: 0.93, sev: 'HIGH', isCrit: false },

      // Haryana
      { lat: 29.1492, lng: 75.7217, crop: 'Cotton', condition: 'Pink Bollworm', pred: 'Cotton_Pink_Bollworm', conf: 0.96, sev: 'CRITICAL', isCrit: true },
    ];

    let createdCount = 0;
    for (const item of demoSurveillanceData) {
      await this.prisma.detection.create({
        data: {
          userId: user.id,
          crop: item.crop,
          condition: item.condition,
          predictedClass: item.pred,
          confidence: item.conf,
          severity: item.sev as any,
          isCritical: item.isCrit,
          status: 'validTarget',
          latitude: item.lat,
          longitude: item.lng,
          accuracyMeters: 10.0,
          margin: 0.92,
          blurScore: 4500,
          notes: 'National surveillance network automated field observation record',
        },
      });
      createdCount++;
    }

    return {
      message: `Successfully seeded ${createdCount} national surveillance outbreaks across India`,
      count: createdCount,
    };
  }
}
