import OpenAI from "openai";
import { describe, expect, it, vi } from "vitest";
import { runReadonlySmoke, safeOpenAiDiagnostic, ReadonlySmokeFailure } from "../src/local/readonly_smoke.js";

const env = {
  OPENAI_API_KEY: "offline-placeholder", OPENAI_MODEL: "gpt-5.6-luna",
  OPENAI_STORE: "false", OPENAI_TIMEOUT_MS: "1000",
  FOCUSDAY_AI_SAFETY_SECRET: "offline-safety-placeholder",
};
function fixture(payload: unknown = { message: "Préparez la présentation puis rédigez le plan.", proposedActions: [] }, status = 200) {
  const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify(
    status === 200 ? {
      object: "response", id: "offline", status: "completed",
      output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(payload), annotations: [] }] }],
    } : { error: { message: "PRIVATE-ERROR", code: "private-code" } },
  ), { status, headers: { "content-type": "application/json" } }));
  return { fetch, sdk: new OpenAI({ apiKey: env.OPENAI_API_KEY, fetch, logLevel: "off" }) };
}
describe("manual readonly smoke safety (fake transport)", () => {
  it("preserves only safe 429 diagnostics through the SDK and harness", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      error: { type: "insufficient_quota", code: "insufficient_quota",
        message: "PRIVATE_MESSAGE", body: "PRIVATE_BODY", stack: "PRIVATE_STACK" },
    }), { status: 429, headers: {
      "content-type": "application/json", "x-request-id": "req_offline123", "x-private": "PRIVATE_HEADER",
    } }));
    const sdk = new OpenAI({ apiKey: env.OPENAI_API_KEY, fetch, logLevel: "off" });
    const failure = await runReadonlySmoke(env, sdk).catch(error => error);
    expect(failure).toBeInstanceOf(ReadonlySmokeFailure);
    expect(failure.diagnostic).toEqual({
      status: 429, type: "insufficient_quota", code: "insufficient_quota", request_id: "req_offline123",
    });
    expect(JSON.stringify(failure.diagnostic)).not.toMatch(/PRIVATE|message|body|headers|stack|offline-placeholder/);
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("handles missing diagnostic fields without falling back to sensitive fields", () => {
    expect(safeOpenAiDiagnostic(new OpenAI.APIError(undefined, {
      message: "PRIVATE", body: "PRIVATE", stack: "PRIVATE",
    }, "PRIVATE", undefined))).toEqual({});
    expect(safeOpenAiDiagnostic(new Error("PRIVATE"))).toEqual({});
    expect(safeOpenAiDiagnostic(new OpenAI.APIError(429, {}, undefined, undefined))).toEqual({ status: 429 });
  });
  it.each(["bad\nvalue", "sk-fake-sensitive", "x".repeat(200), { secret: "PRIVATE" }, 42])(
    "omits malformed diagnostic fields %#", value => {
      const error = new OpenAI.APIError(429, {}, "PRIVATE", undefined);
      Object.assign(error, { type: value, code: value, requestID: value });
      expect(safeOpenAiDiagnostic(error)).toEqual({ status: 429 });
    },
  );
  it("omits known secrets even if they match identifier syntax", () => {
    const error = new OpenAI.APIError(429, {
      type: "secret_value", code: "secret_value",
    }, "PRIVATE", new Headers({ "x-request-id": "req_secret_value" }));
    expect(safeOpenAiDiagnostic(error, ["secret_value"])).toEqual({ status: 429 });
  });
  it.each([200, 999, 429.5, NaN])("omits invalid error status %s", status => {
    expect(safeOpenAiDiagnostic(new OpenAI.APIError(status, {}, "PRIVATE", undefined))).toEqual({});
  });
  it.each([
    {}, { ...env, OPENAI_API_KEY: "" }, { ...env, FOCUSDAY_AI_SAFETY_SECRET: "" },
    { ...env, OPENAI_MODEL: "other" }, { ...env, OPENAI_STORE: "true" },
    { ...env, OPENAI_STORE: undefined },
  ])("rejects missing or incorrect config before any request %#", async config => {
    const { sdk, fetch } = fixture();
    await expect(runReadonlySmoke(config, sdk)).rejects.toThrow();
    expect(fetch).not.toHaveBeenCalled();
  });
  it("makes exactly one safe request and returns metadata only", async () => {
    const { sdk, fetch } = fixture();
    const result = await runReadonlySmoke(env, sdk);
    expect(result).toEqual({
      responsesHttpStatus: 200, backendValidation: "PASS", model: "gpt-5.6-luna",
      textReceived: true, proposedActionsReceived: false, actionExecuted: false,
      safetyIdentifierPresent: true, rawFirebaseUidSent: false, store: false,
    });
    expect(fetch).toHaveBeenCalledTimes(1);
    const body = JSON.parse(fetch.mock.calls[0]![1].body);
    expect(body.safety_identifier).toMatch(/^[a-f0-9]{64}$/);
    expect(body.store).toBe(false);
    expect(body.model).toBe(env.OPENAI_MODEL);
    expect(body.text.format.schema.properties.proposedActions.maxItems).toBe(0);
    expect(body).not.toHaveProperty("tools");
    const serialized = JSON.stringify(body);
    for (const value of [env.OPENAI_API_KEY, env.FOCUSDAY_AI_SAFETY_SECRET, "focusday-local-readonly-fixture"]) {
      expect(serialized).not.toContain(value);
      expect(JSON.stringify(result)).not.toContain(value);
    }
  });
  it.each([
    { message: "x", proposedActions: [{ type: "addTask", title: "Forbidden in smoke" }] },
    { message: "x" }, { message: "" }, { message: "x", extra: "private" },
  ])("rejects any non-readonly or invalid response %#", async payload => {
    await expect(runReadonlySmoke(env, fixture(payload).sdk)).rejects.toThrow("aucune action exécutée");
  });
  it.each([400, 401, 403, 404, 429, 500])("reports HTTP %s without raw error or retries", async status => {
    const { sdk, fetch } = fixture(undefined, status);
    const error = await runReadonlySmoke(env, sdk).catch(error => error);
    expect(error).toBeInstanceOf(Error);
    expect(error.message).not.toContain("PRIVATE-ERROR");
    expect(error.message).not.toContain("private-code");
    expect(fetch).toHaveBeenCalledTimes(1);
  });
});
