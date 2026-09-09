export interface AppConfig {
  port: number;
  allowedOrigins: string[];
  maxMessageChars: number;
  maxConversationIdChars: number;
  maxContextBytes: number;
  rateLimitRequests: number;
  rateLimitWindowMs: number;
  openAiApiKey: string;
  openAiModel: string;
  openAiTimeoutMs: number;
  openAiStore: boolean;
  safetySecret: string;
}

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number(value ?? fallback);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) throw new Error("Invalid numeric configuration");
  return parsed;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    port: positiveInt(env.PORT, 8080),
    allowedOrigins: (env.ALLOWED_ORIGINS ?? "http://localhost:3000,http://localhost:5000")
      .split(",").map((value) => value.trim()).filter(Boolean),
    maxMessageChars: positiveInt(env.AI_MAX_MESSAGE_CHARS, 4000),
    maxConversationIdChars: positiveInt(env.AI_MAX_CONVERSATION_ID_CHARS, 200),
    maxContextBytes: positiveInt(env.AI_MAX_CONTEXT_BYTES, 16000),
    rateLimitRequests: positiveInt(env.AI_RATE_LIMIT_REQUESTS, 20),
    rateLimitWindowMs: positiveInt(env.AI_RATE_LIMIT_WINDOW_MS, 60000),
    openAiApiKey: env.OPENAI_API_KEY ?? "",
    openAiModel: env.OPENAI_MODEL ?? "",
    openAiTimeoutMs: positiveInt(env.OPENAI_TIMEOUT_MS, 20000),
    openAiStore: (env.OPENAI_STORE ?? "false").toLowerCase() === "true",
    safetySecret: env.FOCUSDAY_AI_SAFETY_SECRET ?? "",
  };
}
