import OpenAI from "openai";
import { AppError, type AiProviderRequest, type AiProviderResponse } from "./ai_models.js";
import type { AiProvider } from "./ai_provider.js";

export interface OpenAiProviderConfig {
  apiKey: string;
  model: string;
  timeoutMs: number;
  store: boolean;
}

export class OpenAiResponsesProvider implements AiProvider {
  private readonly client: OpenAI;
  constructor(private readonly config: OpenAiProviderConfig, client?: OpenAI) {
    if (!config.apiKey || !config.model) throw new Error("OpenAI server configuration is incomplete");
    this.client = client ?? new OpenAI({ apiKey: config.apiKey, timeout: config.timeoutMs });
  }

  async respond(request: AiProviderRequest): Promise<AiProviderResponse> {
    try {
      const response = await this.client.responses.create({
        model: this.config.model,
        store: this.config.store,
        safety_identifier: request.safetyIdentifier,
        instructions: "You are FocusDay's read-only productivity assistant. Never claim to modify user data.",
        input: JSON.stringify({ message: request.message, context: request.context }),
      });
      const text = response.output_text?.trim();
      if (!text) throw new AppError(503, "unavailable");
      return { text, conversationId: response.id };
    } catch (error) {
      if (error instanceof AppError) throw error;
      if (error instanceof OpenAI.APIConnectionTimeoutError) throw new AppError(408, "timeout");
      if (error instanceof OpenAI.APIConnectionError) throw new AppError(503, "unavailable");
      throw new AppError(500, "server_error");
    }
  }
}
