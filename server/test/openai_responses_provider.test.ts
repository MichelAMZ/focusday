import OpenAI from "openai";
import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { OpenAiResponsesProvider } from "../src/ai/openai_responses_provider.js";
import { AiService } from "../src/ai/ai_service.js";
import { validateProviderResponse } from "../src/ai/ai_response_validation.js";
import { loadConfig } from "../src/config/env.js";
import { createApp } from "../src/app.js";
import { MemoryRateLimiter } from "../src/middleware/rate_limit.js";

const config = { apiKey: "offline-placeholder", model: "server-configured-model", timeoutMs: 1234, store: false };
const context = {
  language: "fr", focusRemainingSeconds: 60,
  activeProject: { name: "Projet", tasks: [{ title: "Lire", completed: false }], notes: "Notes" },
};
const input = { message: "Aide-moi", context, safetyIdentifier: "pseudonymous-identifier" };
const valid = [
  { type: "addTask", title: "Écrire", description: "Un résumé" },
  { type: "renameTask", taskId: "task-1", newTitle: "Lire un chapitre" },
  { type: "completeTask", taskId: "task-1" },
  { type: "reopenTask", taskId: "task-2" },
  { type: "updateProjectNotes", newNotes: "Nouvelles notes" },
  { type: "setFocusDuration", durationMinutes: 25 },
];
function fixture(payload: unknown = { message: "Conseil", proposedActions: [] }) {
  const create = vi.fn().mockResolvedValue({
    id: "response-offline", status: "completed", output: [], output_text: JSON.stringify(payload),
  });
  const provider = new OpenAiResponsesProvider(config, { responses: { create } });
  return { create, provider };
}

afterEach(() => vi.restoreAllMocks());

describe("OpenAI Responses adapter (offline)", () => {
  it.each(["startTimer", "pauseTimer"])("supports confirmed-only timer proposal %s", async type => {
    const { provider, create } = fixture({ message: "Proposal", proposedActions: [{ type }] });
    expect((await provider.respond(input)).proposedActions).toEqual([{ type }]);
    const body = create.mock.calls[0]![0];
    expect(body).not.toHaveProperty("tools");
    expect(JSON.parse(body.input).context.activeProject.tasks[0].taskId).toBe("focusday_task_0");
  });
  it("rejects incompatible timer batches and unexpected timer parameters", async () => {
    for (const proposedActions of [
      [{ type: "startTimer" }, { type: "pauseTimer" }],
      [{ type: "startTimer" }, { type: "setFocusDuration", durationMinutes: 25 }],
      [{ type: "pauseTimer", secret: "not-allowed" }],
    ]) {
      await expect(fixture({ message: "Proposal", proposedActions }).provider.respond(input))
        .rejects.toMatchObject({ status: 500 });
    }
  });
  it("accepts a valid message and empty action array", async () => {
    await expect(fixture().provider.respond(input)).resolves.toEqual({
      text: "Conseil", proposedActions: [], conversationId: "response-offline",
    });
  });
  it("accepts a message without actions", async () => {
    expect(await fixture({ message: "Conseil" }).provider.respond(input)).toEqual({
      text: "Conseil", conversationId: "response-offline",
    });
  });
  it("validates all six action types without mutating project context", async () => {
    const before = structuredClone(context);
    const { provider, create } = fixture({ message: "Propositions", proposedActions: valid });
    expect((await provider.respond(input)).proposedActions).toEqual(valid);
    expect(context).toEqual(before);
    expect(create).toHaveBeenCalledTimes(1);
    expect(create.mock.calls[0]![0]).not.toHaveProperty("tools");
  });
  it.each([
    null, [], "text", {}, { message: "" }, { message: 12 },
    { message: "x", extra: "secret" },
    { message: "x", proposedActions: null },
    { message: "x", proposedActions: [{ type: "shell", command: "anything" }] },
    { message: "x", proposedActions: [{ type: "addTask", title: "x", email: "private" }] },
    { message: "x", proposedActions: Array.from({ length: 11 }, (_, i) => ({ type: "addTask", title: String(i) })) },
    { message: "x", proposedActions: [{ type: "setFocusDuration", durationMinutes: 481 }] },
    { message: "x", proposedActions: [{ type: "completeTask", taskId: "t" }, { type: "reopenTask", taskId: "t" }] },
    { message: "x", proposedActions: [{ type: "renameTask", taskId: "t", newTitle: "A" }, { type: "renameTask", taskId: "t", newTitle: "B" }] },
    { message: "x", proposedActions: [{ type: "setFocusDuration", durationMinutes: 20 }, { type: "setFocusDuration", durationMinutes: 30 }] },
    { message: "x", proposedActions: [{ type: "updateProjectNotes", newNotes: "A" }, { type: "updateProjectNotes", newNotes: "B" }] },
    { message: "x", proposedActions: [{ type: "addTask", title: "Same" }, { type: "addTask", title: " same " }] },
  ])("rejects malformed or unsafe payload %#", async payload => {
    await expect(fixture(payload).provider.respond(input)).rejects.toMatchObject({ status: 500, code: "server_error" });
  });
  it("rejects invalid JSON", async () => {
    const { create, provider } = fixture();
    create.mockResolvedValue({ status: "completed", output_text: "{broken" });
    await expect(provider.respond(input)).rejects.toMatchObject({ code: "server_error" });
  });
  it.each(["incomplete", "failed", "in_progress"])("rejects %s responses even with valid JSON", async status => {
    const { create, provider } = fixture();
    create.mockResolvedValue({ status, output_text: '{"message":"partial"}' });
    await expect(provider.respond(input)).rejects.toMatchObject({ status: 503, code: "unavailable" });
  });
  it("rejects refusals even with accompanying text", async () => {
    const { create, provider } = fixture();
    create.mockResolvedValue({
      status: "completed", output_text: '{"message":"text"}',
      output: [{ type: "message", content: [{ type: "refusal", refusal: "no" }] }],
    });
    await expect(provider.respond(input)).rejects.toMatchObject({ code: "unavailable" });
  });
  it("rejects empty output", async () => {
    const { create, provider } = fixture();
    create.mockResolvedValue({ status: "completed", output_text: "" });
    await expect(provider.respond(input)).rejects.toMatchObject({ code: "unavailable" });
  });
  it("sends server model, store, safety identifier, strict schema and bounded timeout", async () => {
    const { create, provider } = fixture();
    await provider.respond(input);
    expect(create).toHaveBeenCalledWith(expect.objectContaining({
      model: config.model, store: false, safety_identifier: input.safetyIdentifier,
      text: { format: expect.objectContaining({ type: "json_schema", strict: true }) },
    }), { timeout: config.timeoutMs, maxRetries: 0 });
  });
  it("projects only allowed fields, including nested task fields", async () => {
    const { create, provider } = fixture();
    await provider.respond({
      ...input, conversationId: "untrusted-history",
      context: Object.assign({}, context, {
        email: "hidden-email", uid: "raw-uid", otherProjects: ["hidden-project"],
        activeProject: {
          ...context.activeProject, apiKey: "hidden-key",
          tasks: [{ ...context.activeProject.tasks[0]!, firebaseToken: "hidden-token" }],
        },
      }),
    });
    expect(JSON.parse(create.mock.calls[0]![0].input)).toEqual({ message: input.message, context: { ...context, activeProject: {
      ...context.activeProject, tasks: [{ ...context.activeProject.tasks[0], taskId: "focusday_task_0" }],
    } } });
    expect(create.mock.calls[0]![0]).not.toHaveProperty("previous_response_id");
  });
  it("works without an active project", async () => {
    const { create, provider } = fixture();
    await provider.respond({ ...input, context: { language: "en", focusRemainingSeconds: 0 } });
    expect(JSON.parse(create.mock.calls[0]![0].input).context).toEqual({ language: "en", focusRemainingSeconds: 0 });
  });
  it.each([
    [new OpenAI.APIConnectionTimeoutError(), 408, "timeout"],
    [new OpenAI.APIConnectionError({ message: "private-error" }), 503, "unavailable"],
    [new OpenAI.APIError(429, { message: "private-error" }, "private-error", new Headers()), 429, "rate_limited"],
    [new Error("private-error"), 500, "server_error"],
  ])("maps SDK error %# without leaking its message", async (error, status, code) => {
    const { create, provider } = fixture();
    create.mockRejectedValue(error);
    await expect(provider.respond(input)).rejects.toMatchObject({ status, code, message: code });
  });
  it.each([0, -1, 1.5, NaN])("rejects invalid timeout %s", timeoutMs => {
    expect(() => new OpenAiResponsesProvider({ ...config, timeoutMs })).toThrow("timeout");
  });
  it("rejects missing model or key without reading environment secrets", () => {
    expect(() => new OpenAiResponsesProvider({ ...config, model: "" })).toThrow();
    expect(() => new OpenAiResponsesProvider({ ...config, apiKey: "" })).toThrow();
  });
  it("uses the installed official SDK with a fake transport only", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      object: "response", id: "response-offline", status: "completed",
      output: [{ type: "message", role: "assistant", status: "completed",
        content: [{ type: "output_text", text: '{"message":"SDK offline","proposedActions":[]}', annotations: [] }] }],
    }), { status: 200, headers: { "content-type": "application/json" } }));
    const sdk = new OpenAI({ apiKey: config.apiKey, fetch, maxRetries: 0 });
    const provider = new OpenAiResponsesProvider(config, sdk);
    expect((await provider.respond(input)).text).toBe("SDK offline");
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("keeps service validation authoritative for other providers", () => {
    expect(() => validateProviderResponse({ text: "x", extra: true } as never)).toThrow("server_error");
  });
  it("the SDK aborts a stalled fake transport at the configured timeout without retries", async () => {
    const fetch = vi.fn((_url: unknown, options?: RequestInit) => new Promise<Response>((_resolve, reject) => {
      options!.signal!.addEventListener("abort", () =>
        reject(new DOMException("Aborted", "AbortError")), { once: true });
    }));
    const sdk = new OpenAI({ apiKey: config.apiKey, fetch });
    const provider = new OpenAiResponsesProvider({ ...config, timeoutMs: 20 }, sdk);
    await expect(provider.respond(input)).rejects.toMatchObject({ status: 408, code: "timeout" });
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("passes only a pseudonym through the full route and logs no private values", async () => {
    const logs = vi.spyOn(console, "info").mockImplementation(() => {});
    const { create, provider } = fixture({ message: "Conseil", proposedActions: valid });
    const service = new AiService(provider, "offline-safety-placeholder");
    const app = createApp({
      config: loadConfig({}), auth: { verifyIdToken: async () => ({ uid: "raw-firebase-uid" }) },
      ai: service, rateLimiter: new MemoryRateLimiter(20, 60000),
    });
    const response = await request(app).post("/api/ai/respond")
      .set("Authorization", "Bearer offline-firebase-token").send({ message: input.message, context });
    expect(response.status).toBe(200);
    expect(response.body.proposedActions).toEqual(valid);
    expect(create.mock.calls[0]![0].safety_identifier).toBe(service.safetyIdentifier("raw-firebase-uid"));
    const outbound = JSON.stringify(create.mock.calls);
    for (const secret of ["raw-firebase-uid", "offline-firebase-token", config.apiKey, "offline-safety-placeholder"]) {
      expect(outbound).not.toContain(secret);
      expect(JSON.stringify(logs.mock.calls)).not.toContain(secret);
    }
    create.mockRejectedValue(new Error("private-provider-payload"));
    const failed = await request(app).post("/api/ai/respond")
      .set("Authorization", "Bearer offline-firebase-token").send({ message: input.message, context });
    expect(failed.status).toBe(500);
    expect(JSON.stringify(failed.body)).not.toContain("private-provider-payload");
    expect(JSON.stringify(logs.mock.calls)).not.toContain("private-provider-payload");
  });
  it("blocks a contradictory SDK response at the HTTP boundary", async () => {
    const { provider } = fixture({ message: "x", proposedActions: [
      { type: "completeTask", taskId: "t" }, { type: "reopenTask", taskId: "t" },
    ] });
    vi.spyOn(console, "info").mockImplementation(() => {});
    const app = createApp({
      config: loadConfig({}), auth: { verifyIdToken: async () => ({ uid: "offline" }) },
      ai: new AiService(provider, "offline-safety-placeholder"), rateLimiter: new MemoryRateLimiter(20, 60000),
    });
    const response = await request(app).post("/api/ai/respond")
      .set("Authorization", "Bearer offline").send({ message: input.message, context });
    expect(response.status).toBe(500);
    expect(response.body).toEqual({ error: { code: "server_error" } });
  });
  it("reads model and timeout from server configuration with store false by default", () => {
    const loaded = loadConfig({ OPENAI_MODEL: "chosen-on-server", OPENAI_TIMEOUT_MS: "3210" });
    expect(loaded.openAiModel).toBe("chosen-on-server");
    expect(loaded.openAiTimeoutMs).toBe(3210);
    expect(loaded.openAiStore).toBe(false);
    expect(loadConfig({ OPENAI_STORE: "false" }).openAiStore).toBe(false);
  });
});
