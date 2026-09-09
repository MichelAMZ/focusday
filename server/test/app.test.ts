import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AiService } from "../src/ai/ai_service.js";
import {
  AI_ACTION_LIMITS,
  AppError,
  type AiProviderRequest,
  type AiProviderResponse,
} from "../src/ai/ai_models.js";
import type { AiProvider } from "../src/ai/ai_provider.js";
import { createApp } from "../src/app.js";
import type { FirebaseAuthVerifier } from "../src/auth/firebase_auth_verifier.js";
import type { AppConfig } from "../src/config/env.js";
import { MemoryRateLimiter } from "../src/middleware/rate_limit.js";

const config: AppConfig = {
  port: 8080,
  allowedOrigins: ["http://localhost:3000"],
  maxMessageChars: 20,
  maxConversationIdChars: 20,
  maxContextBytes: 1000,
  rateLimitRequests: 2,
  rateLimitWindowMs: 60000,
  openAiApiKey: "",
  openAiModel: "",
  openAiTimeoutMs: 1000,
  openAiStore: false,
  safetySecret: "test-secret-with-enough-length",
};
const validContext = {
  language: "fr",
  focusRemainingSeconds: 60,
  activeProject: {
    name: "Projet",
    tasks: [{ title: "Tâche", completed: false }],
    notes: "Note",
  },
};

class FakeAuth implements FirebaseAuthVerifier {
  token = "";
  uid = "firebase-uid";
  async verifyIdToken(token: string) {
    this.token = token;
    if (token === "bad") throw new Error("bad token");
    return { uid: this.uid };
  }
}

class FakeProvider implements AiProvider {
  requests: AiProviderRequest[] = [];
  error?: unknown;
  response: AiProviderResponse = { text: "Conseil", conversationId: "response-1" };
  async respond(value: AiProviderRequest) {
    this.requests.push(value);
    if (this.error) throw this.error;
    return this.response;
  }
}

function fixture(options?: { limit?: number }) {
  const auth = new FakeAuth();
  const provider = new FakeProvider();
  const service = new AiService(provider, config.safetySecret);
  const app = createApp({
    config,
    auth,
    ai: service,
    rateLimiter: new MemoryRateLimiter(options?.limit ?? 20, 60000),
  });
  return { app, auth, provider, service };
}

const post = (app: ReturnType<typeof createApp>, body: unknown = {
  message: "Aide-moi",
  context: validContext,
}) => request(app).post("/api/ai/respond").set("Authorization", "Bearer good").send(body);

describe("FocusDay AI gateway", () => {
  beforeEach(() => vi.spyOn(console, "info").mockImplementation(() => undefined));

  it("GET /health returns 200 without sensitive details", async () => {
    const response = await request(fixture().app).get("/health");
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ok" });
  });

  it("rejects missing Authorization", async () => {
    const response = await request(fixture().app).post("/api/ai/respond").send({});
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("unauthenticated");
  });

  it("rejects invalid bearer token", async () => {
    const response = await request(fixture().app).post("/api/ai/respond")
      .set("Authorization", "Bearer bad").send({ message: "Aide", context: validContext });
    expect(response.status).toBe(401);
  });

  it("uses identity exclusively from verifier", async () => {
    const { app, auth, provider } = fixture();
    await post(app);
    expect(auth.token).toBe("good");
    expect(provider.requests).toHaveLength(1);
  });

  it("rejects uid injected in body", async () => {
    const response = await post(fixture().app, {
      message: "Aide", context: validContext, uid: "attacker",
    });
    expect(response.status).toBe(400);
  });

  it("rejects an empty message", async () => {
    expect((await post(fixture().app, { message: " ", context: validContext })).status).toBe(400);
  });

  it("rejects an oversized message", async () => {
    expect((await post(fixture().app, { message: "x".repeat(21), context: validContext })).status).toBe(400);
  });

  it("rejects forbidden context fields", async () => {
    const response = await post(fixture().app, {
      message: "Aide", context: { ...validContext, email: "private@example.test" },
    });
    expect(response.status).toBe(400);
  });

  it("calls provider for valid context", async () => {
    const { app, provider } = fixture();
    expect((await post(app)).status).toBe(200);
    expect(provider.requests[0]?.context).toEqual(validContext);
  });

  it("never sends raw UID as safety identifier", async () => {
    const { app, provider } = fixture();
    await post(app);
    expect(provider.requests[0]?.safetyIdentifier).not.toBe("firebase-uid");
  });

  it("creates a stable safety identifier", () => {
    const { service } = fixture();
    expect(service.safetyIdentifier("same")).toBe(service.safetyIdentifier("same"));
    expect(service.safetyIdentifier("same")).toHaveLength(64);
  });

  it("returns 429 when rate limit is exceeded", async () => {
    const { app } = fixture({ limit: 1 });
    await post(app);
    const response = await post(app);
    expect(response.status).toBe(429);
    expect(response.body.error.code).toBe("rate_limited");
  });

  it("maps provider timeout", async () => {
    const { app, provider } = fixture();
    provider.error = new AppError(408, "timeout");
    expect((await post(app)).status).toBe(408);
  });

  it("maps provider unavailability", async () => {
    const { app, provider } = fixture();
    provider.error = new AppError(503, "unavailable");
    expect((await post(app)).status).toBe(503);
  });

  it("does not expose provider errors or secrets", async () => {
    const { app, provider } = fixture();
    provider.error = new Error("secret-provider-payload");
    const response = await post(app);
    expect(response.status).toBe(500);
    expect(JSON.stringify(response.body)).not.toContain("secret-provider-payload");
  });

  it("returns a valid response with request metadata", async () => {
    const response = await post(fixture().app);
    expect(response.status).toBe(200);
    expect(response.body.text).toBe("Conseil");
    expect(response.body.conversationId).toBe("response-1");
    expect(response.body.metadata.requestId).toEqual(expect.any(String));
  });

  it("uses only the injected fake provider in tests", async () => {
    const { app, provider } = fixture();
    await post(app);
    expect(provider.requests).toHaveLength(1);
  });

  it("accepts a provider response without proposed actions", async () => {
    const { app } = fixture();
    const response = await post(app);
    expect(response.status).toBe(200);
    expect(response.body).not.toHaveProperty("proposedActions");
  });

  it.each([
    { type: "addTask", title: "Nouvelle tâche" },
    { type: "addTask", title: "Nouvelle tâche", description: "Détails" },
    { type: "renameTask", taskId: "task-1", newTitle: "Nouveau titre" },
    { type: "completeTask", taskId: "task-1" },
    { type: "reopenTask", taskId: "task-1" },
    { type: "updateProjectNotes", newNotes: "Nouvelles notes" },
    { type: "setFocusDuration", durationMinutes: 25 },
  ])("transports valid proposed action $type", async (proposedAction) => {
    const { app, provider } = fixture();
    provider.response = { text: "Proposition", proposedActions: [proposedAction] };
    const response = await post(app);
    expect(response.status).toBe(200);
    expect(response.body.proposedActions).toEqual([proposedAction]);
  });

  it("preserves a valid multi-action batch without executing it", async () => {
    const { app, provider } = fixture();
    const proposedActions = [
      { type: "addTask", title: "Étape 1" },
      { type: "addTask", title: "Étape 2", description: "Détails" },
      { type: "setFocusDuration", durationMinutes: 25 },
    ];
    provider.response = {
      text: "Je vous propose trois étapes.",
      proposedActions,
    };
    const response = await post(app);
    expect(response.status).toBe(200);
    expect(response.body.proposedActions).toEqual(proposedActions);
    expect(provider.requests).toHaveLength(1);
  });

  it.each([
    [{ type: "unknown" }],
    [{ type: "deleteTask", taskId: "task-1" }],
    [{ type: "deleteProject", projectId: "project-1" }],
    [{ type: "addTask", title: "Task", unexpected: true }],
    [{ type: "addTask", title: "" }],
    [{ type: "addTask", title: "x".repeat(AI_ACTION_LIMITS.maxTaskTitleLength + 1) }],
    [{ type: "addTask", title: "Task", description: "x".repeat(AI_ACTION_LIMITS.maxTaskDescriptionLength + 1) }],
    [{ type: "completeTask", taskId: "" }],
    [{ type: "renameTask", taskId: "task-1", newTitle: "" }],
    [{ type: "updateProjectNotes", newNotes: "x".repeat(AI_ACTION_LIMITS.maxProjectNotesLength + 1) }],
    [{ type: "setFocusDuration", durationMinutes: 0 }],
    [{ type: "setFocusDuration", durationMinutes: 481 }],
    [{ type: "setFocusDuration", durationMinutes: 1.5 }],
    [{ type: "setFocusDuration", durationMinutes: "25" }],
    Array.from({ length: AI_ACTION_LIMITS.maxActions + 1 }, () => ({ type: "addTask", title: "Task" })),
    [{ type: "addTask", title: "Task", uid: "firebase-uid" }],
    [{ type: "addTask", title: "Task", email: "private@example.test" }],
    [{ type: "addTask", title: "Task", apiKey: "secret" }],
    [{ type: "addTask", title: "Task", payload: { uid: "firebase-uid" } }],
  ])("rejects unsafe provider proposedActions %#", async (proposedActions) => {
    const { app, provider } = fixture();
    provider.response = { text: "Unsafe", proposedActions };
    const response = await post(app);
    expect(response.status).toBe(500);
    expect(response.body).toEqual({ error: { code: "server_error" } });
    expect(JSON.stringify(response.body)).not.toContain("firebase-uid");
    expect(JSON.stringify(response.body)).not.toContain("secret");
  });

  it("never includes verified Firebase identity in a valid response", async () => {
    const { app, provider } = fixture();
    provider.response = {
      text: "Safe",
      proposedActions: [{ type: "completeTask", taskId: "task-1" }],
    };
    const response = await post(app);
    expect(response.status).toBe(200);
    expect(JSON.stringify(response.body)).not.toContain("firebase-uid");
  });
});
