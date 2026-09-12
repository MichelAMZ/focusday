import { AiService } from "./ai_service.js";
import { OpenAiResponsesProvider, type OpenAiResponsesClient } from "./openai_responses_provider.js";
import type { AppConfig } from "../config/env.js";

// No global credential, persistence or cache. Called after auth and validation.
export function createPersonalAiService(
  apiKey: string,
  config: Pick<AppConfig, "openAiModel" | "openAiTimeoutMs" | "safetySecret">,
  client?: OpenAiResponsesClient,
): AiService {
  return new AiService(new OpenAiResponsesProvider({
    apiKey, model: config.openAiModel, timeoutMs: config.openAiTimeoutMs, store: false,
  }, client), config.safetySecret);
}
