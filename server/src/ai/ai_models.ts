export interface AiTaskContext { title: string; completed: boolean; }
export interface AiProjectContext { name: string; tasks: AiTaskContext[]; notes?: string; }
export interface AiContext {
  language: string;
  focusRemainingSeconds: number;
  activeProject?: AiProjectContext;
}
export interface AiProviderRequest {
  message: string;
  conversationId?: string;
  context: AiContext;
  safetyIdentifier: string;
}
export const AI_ACTION_LIMITS = {
  maxActions: 10,
  maxTaskTitleLength: 120,
  maxTaskDescriptionLength: 500,
  maxTaskIdLength: 200,
  maxProjectNotesLength: 5000,
  minFocusDurationMinutes: 1,
  maxFocusDurationMinutes: 480,
} as const;

export type AiProposedAction =
  | { type: "addTask"; title: string; description?: string }
  | { type: "renameTask"; taskId: string; newTitle: string }
  | { type: "completeTask"; taskId: string }
  | { type: "reopenTask"; taskId: string }
  | { type: "updateProjectNotes"; newNotes: string }
  | { type: "setFocusDuration"; durationMinutes: number };

// Provider output is deliberately untrusted until AiService validates it.
export interface AiProviderResponse {
  text: string;
  conversationId?: string;
  proposedActions?: unknown;
}

export interface AiResponse {
  text: string;
  conversationId?: string;
  proposedActions?: AiProposedAction[];
}
export type AiErrorCode =
  | "invalid_request" | "unauthenticated" | "timeout"
  | "rate_limited" | "unavailable" | "server_error";

export class AppError extends Error {
  constructor(public readonly status: number, public readonly code: AiErrorCode) {
    super(code);
  }
}
