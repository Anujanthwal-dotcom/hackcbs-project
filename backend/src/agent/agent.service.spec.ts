import { describe, it, expect, vi, beforeEach } from 'vitest';
import { AgentService } from './agent.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { GeminiProvider } from './providers/gemini.provider.js';
import { MekoMemoryService } from './services/meko-memory.service.js';
import { TelephonyService } from './services/telephony.service.js';

describe('AgentService', () => {
  let agentService: AgentService;
  let mockPrisma: any;
  let mockGemini: any;
  let mockMeko: any;
  let mockTelephony: any;

  beforeEach(() => {
    mockPrisma = {
      user: {
        findUnique: vi.fn().mockResolvedValue({ name: 'Ramesh', preferredLanguage: 'Hindi' }),
      },
      farm: {
        findMany: vi.fn().mockResolvedValue([
          { id: 'farm_1', name: 'Wheat Field North', cropType: 'Wheat', areaSquareMeters: 4000 },
        ]),
        findFirst: vi.fn().mockResolvedValue({ id: 'farm_1', name: 'Wheat Field North', userId: 'user_1' }),
        update: vi.fn().mockResolvedValue({ id: 'farm_1', name: 'Yash Farm', userId: 'user_1' }),
      },
      detection: {
        findMany: vi.fn().mockResolvedValue([]),
      },
      alert: {
        findMany: vi.fn().mockResolvedValue([]),
      },
    };

    mockGemini = {
      isConfigured: vi.fn().mockReturnValue(true),
      generateResponse: vi.fn().mockResolvedValue({
        text: 'नमस्ते रमेश जी! आपका खेत व्हीट फील्ड नॉर्थ सुरक्षित है।',
        toolCalls: [{ tool: 'highlight_element', parameters: { element_id: 'rename_farm' } }],
      }),
    };

    mockMeko = {
      isConfigured: vi.fn().mockReturnValue(false),
      getMemories: vi.fn().mockResolvedValue([]),
      storeMemory: vi.fn().mockResolvedValue(undefined),
    };

    mockTelephony = {
      isVapiConfigured: vi.fn().mockReturnValue(false),
      isTwilioConfigured: vi.fn().mockReturnValue(false),
      requestCallback: vi.fn().mockResolvedValue({ success: true, message: 'Preview mode' }),
    };

    agentService = new AgentService(
      mockPrisma as unknown as PrismaService,
      mockGemini as unknown as GeminiProvider,
      mockMeko as unknown as MekoMemoryService,
      mockTelephony as unknown as TelephonyService,
    );
  });

  it('should return health status indicating availability and configured flags', () => {
    const health = agentService.getHealthStatus();
    expect(health.available).toBe(true);
    expect(health.geminiConfigured).toBe(true);
    expect(health.mekoConfigured).toBe(false);
  });

  it('should handle query, inject user farms and return Gemini response with tool calls', async () => {
    const res = await agentService.handleQuery('user_1', {
      message: 'खेत का नाम कैसे बदलें?',
      context: {
        application: { currentScreen: 'Map' },
        farm: { id: 'farm_1', name: 'Wheat Field North' },
      },
    });

    expect(res.success).toBe(true);
    expect(res.reply).toContain('नमस्ते रमेश जी');
    expect(res.toolCalls).toHaveLength(1);
    expect(res.toolCalls[0].tool).toBe('highlight_element');
    expect(mockPrisma.farm.findMany).toHaveBeenCalledWith({
      where: { userId: 'user_1' },
      select: expect.any(Object),
      take: 5,
    });
  });

  it('should execute confirmed Human-In-The-Loop rename_farm action with ownership check', async () => {
    const confirmRes = await agentService.handleConfirmAction('user_1', {
      actionType: 'rename_farm',
      payload: { farmId: 'farm_1', newName: 'Yash Farm' },
    });

    expect(confirmRes.success).toBe(true);
    expect(confirmRes.message).toContain('Yash Farm');
    expect(mockPrisma.farm.update).toHaveBeenCalledWith({
      where: { id: 'farm_1' },
      data: { name: 'Yash Farm' },
    });
  });
});

