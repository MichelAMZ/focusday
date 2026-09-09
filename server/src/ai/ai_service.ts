import { createHmac } from "node:crypto";
import type { AiProvider } from "./ai_provider.js";
import type { AiContext, AiProviderResponse } from "./ai_models.js";

export class AiService {
  constructor(private readonly provider: AiProvider, private readonly safetySecret: string) {
    if (safetySecret.length < 16) throw new Error("Safety secret must contain at least 16 characters");
  }

  safetyIdentifier(uid: string): string {
    return createHmac("sha256", this.safetySecret).update(uid).digest("hex");
  }

  respond(uid: string, message: string, context: AiContext, conversationId?: string): Promise<AiProviderResponse> {
    return this.provider.respond({
      message, context, conversationId,
      safetyIdentifier: this.safetyIdentifier(uid),
    });
  }
}
