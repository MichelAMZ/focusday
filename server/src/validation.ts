import { AppError, type AiContext } from "./ai/ai_models.js";
import type { AppConfig } from "./config/env.js";

const keysAre = (value: Record<string, unknown>, allowed: string[]) =>
  Object.keys(value).every((key) => allowed.includes(key));

export function validateBody(body: unknown, config: AppConfig): {
  message: string; conversationId?: string; context: AiContext; providerMode?: "personalOpenAi";
} {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new AppError(400, "invalid_request");
  const value = body as Record<string, unknown>;
  if (!keysAre(value, ["message", "conversationId", "context", "providerMode"]) ||
      (value.providerMode !== undefined && value.providerMode !== "personalOpenAi")) throw new AppError(400, "invalid_request");
  if (typeof value.message !== "string" || !value.message.trim() ||
      value.message.length > config.maxMessageChars) throw new AppError(400, "invalid_request");
  if (value.conversationId !== undefined &&
      (typeof value.conversationId !== "string" ||
       value.conversationId.length > config.maxConversationIdChars)) throw new AppError(400, "invalid_request");
  if (!value.context || typeof value.context !== "object" || Array.isArray(value.context) ||
      Buffer.byteLength(JSON.stringify(value.context), "utf8") > config.maxContextBytes) {
    throw new AppError(400, "invalid_request");
  }
  const context = value.context as Record<string, unknown>;
  if (!keysAre(context, ["language", "focusRemainingSeconds", "activeProject"]) ||
      typeof context.language !== "string" ||
      typeof context.focusRemainingSeconds !== "number" ||
      !Number.isSafeInteger(context.focusRemainingSeconds) ||
      context.focusRemainingSeconds < 0) throw new AppError(400, "invalid_request");
  if (context.activeProject !== undefined) validateProject(context.activeProject);
  return {
    message: value.message,
    ...(value.providerMode === undefined ? {} : { providerMode: "personalOpenAi" as const }),
    ...(value.conversationId === undefined ? {} : { conversationId: value.conversationId as string }),
    context: context as unknown as AiContext,
  };
}

function validateProject(raw: unknown): void {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new AppError(400, "invalid_request");
  const project = raw as Record<string, unknown>;
  if (!keysAre(project, ["name", "tasks", "notes"]) || typeof project.name !== "string" ||
      !Array.isArray(project.tasks) ||
      (project.notes !== undefined && typeof project.notes !== "string")) {
    throw new AppError(400, "invalid_request");
  }
  for (const rawTask of project.tasks) {
    if (!rawTask || typeof rawTask !== "object" || Array.isArray(rawTask)) throw new AppError(400, "invalid_request");
    const task = rawTask as Record<string, unknown>;
    if (!keysAre(task, ["title", "completed"]) || typeof task.title !== "string" ||
        typeof task.completed !== "boolean") throw new AppError(400, "invalid_request");
  }
}
