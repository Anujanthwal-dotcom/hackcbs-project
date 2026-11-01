import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ILlmProvider, LlmResponse, LlmToolCall, LlmToolDefinition } from './llm-provider.interface.js';

@Injectable()
export class GeminiProvider implements ILlmProvider {
  private readonly logger = new Logger(GeminiProvider.name);
  private readonly apiKey: string;
  private readonly modelName: string = 'gemini-3.5-flash';
  private readonly fallbackModel: string = 'gemini-3.5-flash-lite';

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('GEMINI_API_KEY', '').trim();
    if (!this.apiKey) {
      this.logger.warn('GEMINI_API_KEY is not configured in backend environment. Agent will indicate offline fallback.');
    }
  }

  isConfigured(): boolean {
    return !!this.apiKey && this.apiKey.length > 5;
  }

  async generateResponse(
    systemPrompt: string,
    conversationHistory: Array<{ role: string; text: string }>,
    userMessage: string,
    availableTools?: LlmToolDefinition[],
  ): Promise<LlmResponse> {
    if (!this.isConfigured()) {
      return {
        text: 'The online Gemini agent is not configured with an API key. Please set GEMINI_API_KEY in the backend .env or use the offline assistant.',
      };
    }

    try {
      return await this._callGemini(this.modelName, systemPrompt, conversationHistory, userMessage, availableTools);
    } catch (err: any) {
      this.logger.warn(`Model ${this.modelName} failed (${err.message}). Retrying with ${this.fallbackModel}...`);
      try {
        return await this._callGemini(this.fallbackModel, systemPrompt, conversationHistory, userMessage, availableTools);
      } catch (fallbackErr: any) {
        this.logger.error(`Gemini call failed: ${fallbackErr.message}`);
        throw fallbackErr;
      }
    }
  }

  private async _callGemini(
    model: string,
    systemPrompt: string,
    conversationHistory: Array<{ role: string; text: string }>,
    userMessage: string,
    availableTools?: LlmToolDefinition[],
  ): Promise<LlmResponse> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${this.apiKey}`;

    // Format conversation history for Gemini contents
    const contents: Array<{ role: string; parts: Array<{ text: string }> }> = [];

    for (const item of conversationHistory.slice(-8)) {
      contents.push({
        role: item.role === 'model' ? 'model' : 'user',
        parts: [{ text: item.text }],
      });
    }

    // Append current user message
    contents.push({
      role: 'user',
      parts: [{ text: userMessage }],
    });

    const payload: Record<string, any> = {
      system_instruction: {
        parts: [{ text: systemPrompt }],
      },
      contents,
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 1024,
      },
    };

    // Attach tool declarations if present
    if (availableTools && availableTools.length > 0) {
      payload.tools = [
        {
          function_declarations: availableTools.map((t) => ({
            name: t.name,
            description: t.description,
            parameters: t.parameters,
          })),
        },
      ];
    }

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Gemini API error [${response.status}]: ${errBody}`);
    }

    const data = await response.json();
    const candidate = data.candidates?.[0];

    if (!candidate || !candidate.content) {
      return { text: 'I received an empty response from Gemini. Please try again.' };
    }

    let text = '';
    const toolCalls: LlmToolCall[] = [];

    const parts = candidate.content.parts || [];
    for (const part of parts) {
      if (part.text) {
        text += (text ? '\n' : '') + part.text;
      }
      if (part.functionCall) {
        toolCalls.push({
          tool: part.functionCall.name,
          parameters: part.functionCall.args || {},
        });
      }
    }

    return {
      text: text.trim(),
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
    };
  }
}

