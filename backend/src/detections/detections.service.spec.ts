import { beforeEach, describe, expect, it, vi } from 'vitest';
import { validate } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateDetectionDto } from './dto/create-detection.dto.js';
import { DetectionsService } from './detections.service.js';
import { SUPPORTED_CROPS } from './crops.constants.js';

describe('DetectionsService crop scope', () => {
  let prisma: {
    detection: {
      create: ReturnType<typeof vi.fn>;
      findMany: ReturnType<typeof vi.fn>;
    };
    user: {
      findFirst: ReturnType<typeof vi.fn>;
    };
  };
  let service: DetectionsService;

  beforeEach(() => {
    prisma = {
      detection: {
        create: vi.fn().mockResolvedValue({}),
        findMany: vi.fn().mockResolvedValue([]),
      },
      user: {
        findFirst: vi.fn().mockResolvedValue({ id: 'user-id' }),
      },
    };
    service = new DetectionsService(prisma as unknown as PrismaService);
  });

  it('only queries dashboard detections for cotton and soybean', async () => {
    await service.getHeatmapData();

    const where = prisma.detection.findMany.mock.calls[0][0].where;
    expect(where.AND[0].OR).toEqual(
      SUPPORTED_CROPS.map((crop) => ({
        crop: { equals: crop, mode: 'insensitive' },
      })),
    );
  });

  it('adds a crop selection without removing the supported-crop restriction', async () => {
    await service.getHeatmapData({ crop: 'Rice' });

    const where = prisma.detection.findMany.mock.calls[0][0].where;
    expect(where.AND).toHaveLength(2);
    expect(where.AND[1]).toEqual({
      crop: { equals: 'Rice', mode: 'insensitive' },
    });
  });

  it('seeds only crops supported by the mobile detector', async () => {
    await service.seedSurveillanceOutbreaks();

    const seededCrops = prisma.detection.create.mock.calls.map(
      ([{ data }]) => data.crop,
    );
    expect(seededCrops.length).toBeGreaterThan(0);
    expect(seededCrops.every((crop) => SUPPORTED_CROPS.includes(crop))).toBe(true);
  });

  it('rejects detections for crops unsupported by the mobile detector', async () => {
    const dto = Object.assign(new CreateDetectionDto(), {
      crop: 'Rice',
      predictedClass: 'Rice_Blast',
      condition: 'Blast',
      confidence: 0.9,
    });

    const errors = await validate(dto);

    expect(errors.some((error) => error.property === 'crop')).toBe(true);
  });

  it('accepts both crop labels emitted by the mobile detector', async () => {
    for (const crop of SUPPORTED_CROPS) {
      const dto = Object.assign(new CreateDetectionDto(), {
        crop,
        predictedClass: `${crop}_Healthy`,
        condition: 'Healthy',
        confidence: 0.9,
      });

      expect(await validate(dto)).toHaveLength(0);
    }
  });
});
