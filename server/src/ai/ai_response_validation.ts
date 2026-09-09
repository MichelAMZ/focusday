import {
  AI_ACTION_LIMITS,
  AppError,
  type AiProposedAction,
  type AiProviderResponse,
  type AiResponse,
} from "./ai_models.js";

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);

const hasOnlyKeys = (value: Record<string, unknown>, allowed: string[]) =>
  Object.keys(value).every((key) => allowed.includes(key));

const requiredText = (value: unknown, maxLength: number) =>
  typeof value === "string" && value.trim().length > 0 && value.length <= maxLength;

const optionalText = (value: unknown, maxLength: number) =>
  value === undefined || (typeof value === "string" && value.length <= maxLength);

const invalidProviderOutput = (): never => {
  throw new AppError(500, "server_error");
};

export function validateProviderResponse(raw: AiProviderResponse): AiResponse {
  if (!isRecord(raw) || !requiredText(raw.text, 20000)) invalidProviderOutput();
  if (raw.conversationId !== undefined &&
      !requiredText(raw.conversationId, 500)) invalidProviderOutput();

  const actions = raw.proposedActions === undefined
    ? undefined
    : validateProposedActions(raw.proposedActions);
  return {
    text: raw.text as string,
    ...(raw.conversationId === undefined
      ? {}
      : { conversationId: raw.conversationId as string }),
    ...(actions === undefined ? {} : { proposedActions: actions }),
  };
}

export function validateProposedActions(raw: unknown): AiProposedAction[] {
  if (!Array.isArray(raw) || raw.length > AI_ACTION_LIMITS.maxActions) {
    return invalidProviderOutput();
  }
  return raw.map(validateAction);
}

function validateAction(raw: unknown): AiProposedAction {
  if (!isRecord(raw) || typeof raw.type !== "string") return invalidProviderOutput();
  switch (raw.type) {
    case "addTask":
      if (!hasOnlyKeys(raw, ["type", "title", "description"]) ||
          !requiredText(raw.title, AI_ACTION_LIMITS.maxTaskTitleLength) ||
          !optionalText(raw.description, AI_ACTION_LIMITS.maxTaskDescriptionLength)) {
        return invalidProviderOutput();
      }
      return raw as AiProposedAction;
    case "renameTask":
      if (!hasOnlyKeys(raw, ["type", "taskId", "newTitle"]) ||
          !requiredText(raw.taskId, AI_ACTION_LIMITS.maxTaskIdLength) ||
          !requiredText(raw.newTitle, AI_ACTION_LIMITS.maxTaskTitleLength)) {
        return invalidProviderOutput();
      }
      return raw as AiProposedAction;
    case "completeTask":
    case "reopenTask":
      if (!hasOnlyKeys(raw, ["type", "taskId"]) ||
          !requiredText(raw.taskId, AI_ACTION_LIMITS.maxTaskIdLength)) {
        return invalidProviderOutput();
      }
      return raw as AiProposedAction;
    case "updateProjectNotes":
      if (!hasOnlyKeys(raw, ["type", "newNotes"]) ||
          typeof raw.newNotes !== "string" ||
          raw.newNotes.length > AI_ACTION_LIMITS.maxProjectNotesLength) {
        return invalidProviderOutput();
      }
      return raw as AiProposedAction;
    case "setFocusDuration":
      if (!hasOnlyKeys(raw, ["type", "durationMinutes"]) ||
          !Number.isSafeInteger(raw.durationMinutes) ||
          (raw.durationMinutes as number) < AI_ACTION_LIMITS.minFocusDurationMinutes ||
          (raw.durationMinutes as number) > AI_ACTION_LIMITS.maxFocusDurationMinutes) {
        return invalidProviderOutput();
      }
      return raw as AiProposedAction;
    default:
      return invalidProviderOutput();
  }
}
