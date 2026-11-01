export interface LlmToolCall {
  tool: string;
  parameters: Record<string, any>;
}

export interface LlmResponse {
  text: string;
  toolCalls?: LlmToolCall[];
}

export interface LlmToolDefinition {
  name: string;
  description: string;
  parameters: {
    type: string;
    properties: Record<string, any>;
    required?: string[];
  };
}

export interface ILlmProvider {
  generateResponse(
    systemPrompt: string,
    conversationHistory: Array<{ role: string; text: string }>,
    userMessage: string,
    availableTools?: LlmToolDefinition[],
  ): Promise<LlmResponse>;
  isConfigured(): boolean;
}

