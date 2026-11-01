import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface MekoMemoryItem {
  id: string;
  category: 'preference' | 'conversation' | 'farm_note';
  content: string;
  timestamp: string;
}

/// Service interface and client for Meko Persistent Conversational Memory.
///
/// Responsibilities:
/// - Stores durable farmer preferences and key conversational context.
/// - Strictly isolated per user (`kisaan_ambient_${userId}`).
/// - Kept completely separate from Crop Disease Agent field point memory!
/// - Falls back safely to in-memory/MongoDB session memory when MEKO_API_KEY is not set.
@Injectable()
export class MekoMemoryService {
  private readonly logger = new Logger(MekoMemoryService.name);
  private readonly apiKey: string;
  private readonly datapackId: string;
  private readonly mekoBaseUrl: string;

  // Safe development in-memory store when Meko credentials are placeholder
  private readonly localFallbackStore = new Map<string, MekoMemoryItem[]>();

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('MEKO_API_KEY', '').trim();
    this.datapackId = this.configService.get<string>('MEKO_DATAPACK_ID', '').trim();
    this.mekoBaseUrl = this.configService.get<string>('MEKO_BASE_URL', 'https://api.meko.ai/v1').trim();

    if (!this.isConfigured()) {
      this.logger.log('Meko Memory credentials not provided. Using safe isolated user memory fallback.');
    } else {
      this.logger.log(`Meko Memory configured with datapack: ${this.datapackId}`);
    }
  }

  isConfigured(): boolean {
    return !!this.apiKey && this.apiKey.length > 5 && !this.apiKey.includes('placeholder');
  }

  /**
   * Retrieves relevant conversational memories for the authenticated farmer.
   * Namespace is strictly isolated: `kisaan_ambient_${userId}` to ensure
   * memories are never shared between farmers or mixed with Crop Disease Agent records.
   */
  async getMemories(userId: string, query?: string): Promise<string[]> {
    if (!this.isConfigured()) {
      const items = this.localFallbackStore.get(userId) || [];
      return items.slice(-5).map((i) => i.content);
    }

    try {
      const namespace = `kisaan_ambient_${userId}`;
      const url = `${this.mekoBaseUrl}/datapacks/${this.datapackId}/query`;

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          namespace,
          query: query || 'farmer preferences and recent topics',
          limit: 5,
        }),
      });

      if (!response.ok) {
        this.logger.warn(`Meko query returned status ${response.status}`);
        return [];
      }

      const data = await response.json();
      return (data.memories || []).map((m: any) => m.text || m.content || '');
    } catch (err: any) {
      this.logger.warn(`Meko retrieval error: ${err.message}. Continuing with local fallback.`);
      const items = this.localFallbackStore.get(userId) || [];
      return items.slice(-5).map((i) => i.content);
    }
  }

  /**
   * Stores a durable memory or user preference for the authenticated farmer.
   */
  async storeMemory(userId: string, content: string, category: 'preference' | 'conversation' | 'farm_note' = 'conversation'): Promise<void> {
    const memoryItem: MekoMemoryItem = {
      id: `${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      category,
      content,
      timestamp: new Date().toISOString(),
    };

    // Always update local fallback cache
    const existing = this.localFallbackStore.get(userId) || [];
    existing.push(memoryItem);
    if (existing.length > 20) existing.shift();
    this.localFallbackStore.set(userId, existing);

    if (!this.isConfigured()) {
      return;
    }

    try {
      const namespace = `kisaan_ambient_${userId}`;
      const url = `${this.mekoBaseUrl}/datapacks/${this.datapackId}/memories`;

      await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          namespace,
          content,
          metadata: {
            category,
            userId,
            savedAt: new Date().toISOString(),
          },
        }),
      });
    } catch (err: any) {
      this.logger.warn(`Failed to store memory to Meko: ${err.message}`);
    }
  }
}

