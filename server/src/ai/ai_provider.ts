import type { AiProviderRequest, AiProviderResponse } from "./ai_models.js";

export interface AiProvider {
  respond(request: AiProviderRequest): Promise<AiProviderResponse>;
}
