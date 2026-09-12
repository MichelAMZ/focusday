import OpenAI from "openai";
import { AppError, type AiProviderRequest, type AiProviderResponse } from "./ai_models.js";
import type { AiProvider } from "./ai_provider.js";
import type { ResponseCreateParamsNonStreaming } from "openai/resources/responses/responses";
import { validateProviderResponse } from "./ai_response_validation.js";
import { FOCUSDAY_RESPONSE_FORMAT, FOCUSDAY_SYSTEM_PROMPT } from "./openai_response_contract.js";

export interface OpenAiResponsesClient {
  responses: {
    create(body: ResponseCreateParamsNonStreaming, options: { timeout: number; maxRetries: number }):
      PromiseLike<{ output_text: string; id: string; status?: string; output?: unknown[] }>;
  };
}

export interface OpenAiProviderConfig {
  apiKey: string;
  model: string;
  timeoutMs: number;
  store: boolean;
}

export class OpenAiResponsesProvider implements AiProvider {
  private readonly client: OpenAiResponsesClient;
  constructor(private readonly config: OpenAiProviderConfig, client?: OpenAiResponsesClient) {
    if (!config.apiKey || !config.model) throw new Error("OpenAI server configuration is incomplete");
    if (!Number.isSafeInteger(config.timeoutMs) || config.timeoutMs <= 0) {
      throw new Error("Invalid OpenAI timeout configuration");
    }
    this.client = client ?? new OpenAI({
      apiKey: config.apiKey, timeout: config.timeoutMs, maxRetries: 0,
      logLevel: "off", baseURL: "https://api.openai.com/v1",
    });
  }

  async respond(request: AiProviderRequest): Promise<AiProviderResponse> {
    try {
      // Reconstruct the allowlist at the provider boundary, even for internal callers.
      const project = request.context.activeProject;
      const context = {
        language: request.context.language,
        focusRemainingSeconds: request.context.focusRemainingSeconds,
        ...(project === undefined ? {} : { activeProject: {
          name: project.name,
          tasks: project.tasks.map((task, index) => ({ title: task.title, completed: task.completed,
            taskId: `focusday_task_${index}` })),
          ...(project.notes === undefined ? {} : { notes: project.notes }),
        } }),
      };
      const response = await this.client.responses.create({
        model: this.config.model,
        store: this.config.store,
        safety_identifier: request.safetyIdentifier,
        instructions: FOCUSDAY_SYSTEM_PROMPT,
        input: JSON.stringify({ message: request.message, context }),
        text: { format: FOCUSDAY_RESPONSE_FORMAT },
      }, { timeout: this.config.timeoutMs, maxRetries: 0 });
      if (response.status !== "completed") throw new AppError(503, "unavailable");
      if (response.output?.some(item => {
        const message = item as { type?: string; content?: { type?: string }[] };
        return message.type === "message" &&
          message.content?.some(part => part.type === "refusal");
      })) throw new AppError(503, "unavailable");
      if (!response.output_text?.trim()) throw new AppError(503, "unavailable");
      const raw: unknown = JSON.parse(response.output_text);
      if (!raw || typeof raw !== "object" || Array.isArray(raw) ||
          Object.keys(raw).some(key => !["message", "proposedActions"].includes(key))) {
        throw new AppError(500, "server_error");
      }
      const value = raw as { message: string; proposedActions?: unknown };
      return validateProviderResponse({
        text: value.message, proposedActions: value.proposedActions, conversationId: response.id,
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      if (error instanceof OpenAI.APIConnectionTimeoutError) throw new AppError(408, "timeout");
      if (error instanceof OpenAI.APIConnectionError) throw new AppError(503, "unavailable");
      if (error instanceof OpenAI.APIError && error.status === 429) throw new AppError(429, "rate_limited");
      if (error instanceof OpenAI.APIError && [401, 403, 404].includes(error.status ?? 0)) {
        throw new AppError(403, "unavailable");
      }
      throw new AppError(500, "server_error");
    }
  }
}
