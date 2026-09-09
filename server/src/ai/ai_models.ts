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
export interface AiProviderResponse { text: string; conversationId?: string; }
export type AiErrorCode =
  | "invalid_request" | "unauthenticated" | "timeout"
  | "rate_limited" | "unavailable" | "server_error";

export class AppError extends Error {
  constructor(public readonly status: number, public readonly code: AiErrorCode) {
    super(code);
  }
}
