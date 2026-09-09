import { createHmac } from "node:crypto";
import type { AiProvider } from "./ai_provider.js";
import type { AiContext, AiResponse } from "./ai_models.js";
import { validateProviderResponse } from "./ai_response_validation.js";

export class AiService {
  constructor(private readonly provider: AiProvider, private readonly safetySecret: string) {
    if (safetySecret.length < 16) throw new Error("Safety secret must contain at least 16 characters");
  }

  safetyIdentifier(uid: string): string {
    return createHmac("sha256", this.safetySecret).update(uid).digest("hex");
  }

  async respond(uid: string, message: string, context: AiContext, conversationId?: string): Promise<AiResponse> {
    const response = await this.provider.respond({
      message, context, conversationId,
      safetyIdentifier: this.safetyIdentifier(uid),
    });
    return validateProviderResponse(response);
  }
}
