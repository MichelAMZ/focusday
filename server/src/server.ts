import { initializeApp } from "firebase-admin/app";
import { AiService } from "./ai/ai_service.js";
import { OpenAiResponsesProvider } from "./ai/openai_responses_provider.js";
import { createApp } from "./app.js";
import { FirebaseAdminAuthVerifier } from "./auth/firebase_auth_verifier.js";
import { loadConfig } from "./config/env.js";
import { MemoryRateLimiter } from "./middleware/rate_limit.js";

const config = loadConfig();
initializeApp();
const provider = new OpenAiResponsesProvider({
  apiKey: config.openAiApiKey,
  model: config.openAiModel,
  timeoutMs: config.openAiTimeoutMs,
  store: config.openAiStore,
});
const app = createApp({
  config,
  auth: new FirebaseAdminAuthVerifier(),
  ai: new AiService(provider, config.safetySecret),
  rateLimiter: new MemoryRateLimiter(
    config.rateLimitRequests,
    config.rateLimitWindowMs,
  ),
});
app.listen(config.port, () =>
  console.info(JSON.stringify({ event: "server_started", port: config.port })),
);
