import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { loadConfig } from "../src/config/env.js";
import { AiService } from "../src/ai/ai_service.js";
import { MemoryRateLimiter } from "../src/middleware/rate_limit.js";
import { createPersonalAiService } from "../src/ai/personal_openai_service.js";

const body = { providerMode: "personalOpenAi", message: "Help",
  context: { language: "en", focusRemainingSeconds: 10 } };
function fixture() {
  const requests: unknown[] = [];
  const factory = vi.fn((key: string) => new AiService({
    respond: async value => {
      requests.push(value);
      return { text: key === "offline-a" ? "A" : "B",
        proposedActions: [{ type: "addTask", title: "Proposal only" }] };
    },
  }, "offline-safety-secret"));
  const app = createApp({
    config: loadConfig({}), personalAi: factory,
    auth: { verifyIdToken: async token => {
      if (token === "bad") throw new Error("private-auth-error");
      return { uid: token === "first" ? "uid-a" : "uid-b" };
    } },
    rateLimiter: new MemoryRateLimiter(20, 60000),
  });
  const post = (value: unknown = body, key = "offline-a", token = "first") =>
    request(app).post("/api/ai/respond").set("Authorization", "Bearer " + token)
      .set("x-focusday-openai-key", key).send(value);
  return { app, post, factory, requests };
}
afterEach(() => vi.restoreAllMocks());
describe("personal OpenAI authenticated request boundary", () => {
  it("the real personal service forces store false and validates output without a global key", async () => {
    const create = vi.fn().mockResolvedValue({
      id: "offline", status: "completed", output_text: '{"message":"Advice","proposedActions":[]}',
    });
    const config = loadConfig({ OPENAI_MODEL: "server-model", OPENAI_STORE: "true",
      FOCUSDAY_AI_SAFETY_SECRET: "offline-safety-secret" });
    const service = createPersonalAiService("offline-personal", config, { responses: { create } });
    expect((await service.respond("private-uid", "Help", body.context)).text).toBe("Advice");
    expect(create.mock.calls[0]![0]).toMatchObject({ store: false, model: "server-model" });
    expect(create.mock.calls[0]![0].safety_identifier).toMatch(/^[a-f0-9]{64}$/);
    expect(JSON.stringify(create.mock.calls)).not.toContain("private-uid");
    create.mockResolvedValue({ id: "offline", status: "completed",
      output_text: '{"message":"Advice","proposedActions":[{"type":"deleteProject"}]}' });
    await expect(service.respond("private-uid", "Help", body.context)).rejects.toMatchObject({ code: "server_error" });
  });
  it.each(["", " ", "a,b", "x".repeat(513)])("rejects empty or invalid credential %#", async key => {
    const { post, factory } = fixture();
    expect((await post(body, key)).status).toBe(400);
    expect(factory).not.toHaveBeenCalled();
  });
  it("rate limits before allocating a per-request service", async () => {
    const factory = vi.fn();
    const app = createApp({ config: loadConfig({}),
      auth: { verifyIdToken: async () => ({ uid: "offline" }) },
      personalAi: factory, rateLimiter: { allow: () => false } });
    const result = await request(app).post("/api/ai/respond")
      .set("Authorization", "Bearer offline").set("x-focusday-openai-key", "offline-key").send(body);
    expect(result.status).toBe(429);
    expect(factory).not.toHaveBeenCalled();
  });
  it("isolates concurrent callers and pseudonymizes each identity", async () => {
    const log = vi.spyOn(console, "info").mockImplementation(() => {});
    const { post, factory, requests } = fixture();
    const [a, b] = await Promise.all([post(), post(body, "offline-b", "second")]);
    expect(a.status).toBe(200); expect(b.status).toBe(200);
    expect(a.body.text).toBe("A"); expect(b.body.text).toBe("B");
    expect(factory).toHaveBeenCalledTimes(2);
    expect(factory).toHaveBeenCalledWith("offline-a");
    expect(factory).toHaveBeenCalledWith("offline-b");
    expect(a.body.proposedActions).toEqual([{ type: "addTask", title: "Proposal only" }]);
    for (const secret of ["offline-a", "offline-b", "uid-a", "uid-b", "offline-safety-secret"]) {
      expect(JSON.stringify(requests)).not.toContain(secret);
      expect(JSON.stringify(log.mock.calls)).not.toContain(secret);
      expect(JSON.stringify([a.body,b.body])).not.toContain(secret);
    }
    expect((requests[0] as { safetyIdentifier: string }).safetyIdentifier)
      .not.toBe((requests[1] as { safetyIdentifier: string }).safetyIdentifier);
  });
  it("authenticates before constructing any personal provider", async () => {
    const { post, factory } = fixture();
    expect((await post(body, "offline-a", "bad")).status).toBe(401);
    expect(factory).not.toHaveBeenCalled();
  });
  it("requires Firebase auth even with a personal key", async () => {
    const { app, factory } = fixture();
    expect((await request(app).post("/api/ai/respond").set("x-focusday-openai-key", "offline-a").send(body)).status).toBe(401);
    expect(factory).not.toHaveBeenCalled();
  });
  it("requires a key for every request, with no shared-key fallback", async () => {
    const { post, app, factory } = fixture();
    await post();
    const result = await request(app).post("/api/ai/respond").set("Authorization", "Bearer first").send(body);
    expect(result.status).toBe(400);
    expect(factory).toHaveBeenCalledTimes(1);
  });
  it.each([
    { ...body, providerMode: "disabled" }, { ...body, providerMode: "chatgpt" },
    { ...body, providerMode: "focusDayAi" }, { ...body, providerMode: undefined },
    { ...body, apiKey: "not-allowed-in-body" },
    { ...body, context: { ...body.context, uid: "private" } },
  ])("rejects disabled/unknown mode and forbidden body fields %#", async value => {
    const { post, factory } = fixture();
    expect((await post(value)).status).toBe(400);
    expect(factory).not.toHaveBeenCalled();
  });
  it("rejects non-local plaintext transport even with forwarded headers", async () => {
    const { post, factory } = fixture();
    expect((await post().set("Host", "remote.example").set("X-Forwarded-Proto", "https")).status).toBe(400);
    expect(factory).not.toHaveBeenCalled();
  });
  it("logs only metadata for provider failures", async () => {
    const log = vi.spyOn(console, "info").mockImplementation(() => {});
    const config = loadConfig({});
    const app = createApp({
      config, auth: { verifyIdToken: async () => ({ uid: "private-uid" }) },
      rateLimiter: new MemoryRateLimiter(10, 60000),
      personalAi: () => { throw new Error("private-key-error"); },
    });
    const response = await request(app).post("/api/ai/respond")
      .set("Authorization", "Bearer token").set("x-focusday-openai-key", "offline-a").send(body);
    expect(response.status).toBe(500);
    expect(JSON.stringify(log.mock.calls)).not.toContain("private");
    expect(response.body).toEqual({ error: { code: "server_error" } });
  });
});
